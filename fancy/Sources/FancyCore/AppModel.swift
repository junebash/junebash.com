import Observation

@Observable
public final class AppModel {
  public struct Effects {
    public var setLocation: (_ path: SitePath, _ push: Bool) -> Void
    public var play: (SoundEffect) -> Void
    public var leave: (SitePath) -> Void
    public var saveSound: (Bool) -> Void
    public var pause: (_ milliseconds: Int) async -> Void
    /// Milliseconds since some fixed moment.
    public var now: () -> Double

    public init(
      setLocation: @escaping (SitePath, Bool) -> Void,
      play: @escaping (SoundEffect) -> Void,
      leave: @escaping (SitePath) -> Void,
      saveSound: @escaping (Bool) -> Void,
      pause: @escaping (Int) async -> Void,
      now: @escaping () -> Double
    ) {
      self.setLocation = setLocation
      self.play = play
      self.leave = leave
      self.saveSound = saveSound
      self.pause = pause
      self.now = now
    }
  }

  public static let commands: [CommandInfo] = [
    CommandInfo(name: "help", usage: "help", summary: "show this list"),
    CommandInfo(name: "ls", usage: "ls [-r] [place]", summary: "list what's here (-r flips the order)"),
    CommandInfo(name: "head", usage: "head [-n] [place]", summary: "just the first n (or: ls | head -n)"),
    CommandInfo(name: "tail", usage: "tail [-n] [place]", summary: "just the last n"),
    CommandInfo(name: "cd", usage: "cd <place>", summary: "go somewhere"),
    CommandInfo(name: "open", usage: "open <name>", summary: "read something (or: less)"),
    CommandInfo(name: "cat", usage: "cat <name>", summary: "read something, the unix way"),
    CommandInfo(name: "menu", usage: "menu", summary: "show a clickable menu"),
    CommandInfo(name: "clear", usage: "clear", summary: "wipe the screen"),
    CommandInfo(name: "sound", usage: "sound [on|off]", summary: "toggle the noises"),
    CommandInfo(name: "simple", usage: "simple", summary: "leave for the simple site"),
  ]

  public static let scrollbackLimit = 400
  public static let catPatience = 5.0 * 60 * 1000

  /// What the keyboard is for right now.
  public enum Mode: Equatable, Sendable {
    case shell
    /// A command is hanging; only ^C gets you out.
    case waiting
    case sitting
    case playing(Piano)
  }

  public let site: Site
  public private(set) var cwd: SitePath = .root
  public private(set) var output: [OutputEntry] = []
  public private(set) var input = ""
  public private(set) var pager: Page?
  public private(set) var popup: Popup?
  public private(set) var isMenuOpen = false
  public private(set) var isSoundOn: Bool
  public private(set) var isTyping = false
  public private(set) var completionMenu: CompletionMenu?
  public private(set) var mode = Mode.shell
  public private(set) var isCatWalking = false

  @ObservationIgnored private var history: [String] = []
  @ObservationIgnored private var historyIndex: Int?
  @ObservationIgnored private var draft = ""
  @ObservationIgnored private var nextID = 0
  @ObservationIgnored private var typingGeneration = 0
  @ObservationIgnored private var waitGeneration = 0
  @ObservationIgnored private var fortunes: [Fortune] = []
  @ObservationIgnored private var lastActivity: Double
  @ObservationIgnored private var hasCatVisited = false
  @ObservationIgnored private var recentKeys: [String] = []
  @ObservationIgnored private let effects: Effects

  public init(site: Site, isSoundOn: Bool, effects: Effects) {
    self.site = site
    self.isSoundOn = isSoundOn
    self.effects = effects
    lastActivity = effects.now()
  }

  public var location: SitePath {
    pager?.path ?? cwd
  }

  public var title: String {
    if let pager { return pager.title }
    return cwd == .root ? "June Bash" : "\(cwd.display) · June Bash"
  }

  public var prompt: String {
    "guest@junebash:\(cwd)$"
  }

  public func started(at path: SitePath) {
    print(.welcome)
    arrive(at: path, announce: true)
    effects.setLocation(location, false)
  }

  public func locationChanged(to path: SitePath) {
    guard path != location else { return }
    popup = nil
    isMenuOpen = false
    arrive(at: path, announce: false)
  }

  public func inputChanged(_ text: String) {
    guard !isTyping, mode == .shell, text != input else { return }
    input = text
    historyIndex = nil
    completionMenu = nil
    play(.key)
  }

  public func returnKeyPressed() {
    if let menu = completionMenu {
      completionMenu = nil
      if let selection = menu.selection {
        input = selection + (selection.hasSuffix("/") ? "" : " ")
        play(.key)
        return
      }
    }
    let line = input
    input = ""
    historyIndex = nil
    print(.command(cwd: cwd, text: line))
    let trimmed = line.trimmingWhitespace
    guard !trimmed.isEmpty else { return }
    if history.last != trimmed { history.append(trimmed) }
    play(.enter)
    run(trimmed)
  }

  /// Like zsh: fill in what's certain, then list the candidates, then step through them.
  public func tabKeyPressed() {
    if completionMenu != nil {
      stepCompletion(by: 1)
      return
    }
    switch site.complete(input, cwd: cwd, commands: Self.commands.map(\.name)) {
    case .none:
      play(.error)
    case .replaced(let text):
      input = text
      play(.key)
    case .candidates(let base, let names):
      print(.command(cwd: cwd, text: input))
      print(.candidates(names))
      completionMenu = CompletionMenu(entryID: nextID - 1, base: base, names: names)
      play(.blip)
    }
  }

  public func shiftTabKeyPressed() {
    stepCompletion(by: -1)
  }

  private func stepCompletion(by step: Int) {
    guard var menu = completionMenu else { return }
    let count = menu.names.count
    menu.selected = menu.selected.map { ($0 + step + count) % count } ?? (step > 0 ? 0 : count - 1)
    completionMenu = menu
    input = menu.selection ?? input
    play(.key)
  }

  public func upArrowPressed() {
    completionMenu = nil
    guard !history.isEmpty else { return }
    if historyIndex == nil { draft = input }
    let index = max(0, (historyIndex ?? history.count) - 1)
    historyIndex = index
    input = history[index]
  }

  public func downArrowPressed() {
    completionMenu = nil
    guard let index = historyIndex else { return }
    if index + 1 < history.count {
      historyIndex = index + 1
      input = history[index + 1]
    } else {
      historyIndex = nil
      input = draft
    }
  }

  public static let konamiCode = ["ArrowUp", "ArrowUp", "ArrowDown", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowLeft", "ArrowRight", "b", "a"]

  /// Sees every shell keydown, as `KeyboardEvent.key`. `true` if it swallowed the key.
  public func keyPressed(_ key: String) -> Bool {
    recentKeys.append(key.count == 1 ? key.lowercased() : key)
    if recentKeys.count > Self.konamiCode.count { recentKeys.removeFirst() }
    guard recentKeys == Self.konamiCode else { return false }
    recentKeys = []
    input = ""
    historyIndex = nil
    completionMenu = nil
    print(.text("LIVES += 30"))
    play(.powerUp)
    return true
  }

  public func interruptPressed() {
    if mode == .waiting {
      mode = .shell
      print(.text("^C"))
      return
    }
    completionMenu = nil
    print(.command(cwd: cwd, text: input + "^C"))
    input = ""
    historyIndex = nil
  }

  public func clearScreenPressed() {
    completionMenu = nil
    output = []
  }

  /// Escape or q: closes whatever is on top.
  public func closeKeyPressed() {
    if case .playing = mode {
      mode = .shell
      play(.close)
    } else if popup != nil {
      popupDismissed()
    } else if isMenuOpen {
      menuButtonTapped()
    } else if pager != nil {
      pagerDismissed()
    }
  }

  public func entryClicked(_ path: SitePath) async {
    guard let node = site.node(at: path) else { return }
    let isListedHere = site.entries(in: cwd)?.contains { $0.path == path } == true
    let name =
      if isListedHere { path.name }
      else if path == .root { "~" }
      else if path == cwd.parent { ".." }
      else { path.display }
    if case .document = node {
      await type("open \(name)")
    } else {
      await type("cd \(name)")
    }
  }

  public func commandClicked(_ command: String) async {
    await type(command)
  }

  public func menuButtonTapped() {
    isMenuOpen.toggle()
    play(.blip)
  }

  public func menuItemTapped(_ command: String) async {
    isMenuOpen = false
    await type(command)
  }

  public func leaveTapped() {
    effects.leave(location)
  }

  public func linkClicked(_ path: SitePath) {
    popup = nil
    visit(site.node(at: path) ?? .unbuilt(path))
  }

  public func pagerDismissed() {
    guard pager != nil else { return }
    pager = nil
    play(.close)
    effects.setLocation(location, true)
  }

  public func imageClicked(_ image: Image) {
    popup = .image(image)
    play(.popup)
  }

  public func embedClicked(_ embed: Embed) {
    popup = .embed(embed)
    play(.popup)
  }

  /// Any key or tap while sitting.
  public func stirred() {
    guard mode == .sitting else { return }
    mode = .shell
    print(.text("you moved. that's fine. begin again.", tone: .dim))
  }

  /// `code` is the key's physical position, as in `KeyboardEvent.code`. `false` if it isn't on the piano.
  public func pianoKeyPressed(at code: String) -> Bool {
    guard case .playing(var piano) = mode else { return false }
    switch code {
    case Piano.octaveDown:
      piano.shift(-1)
      mode = .playing(piano)
    case Piano.octaveUp:
      piano.shift(1)
      mode = .playing(piano)
    default:
      guard let key = Piano.key(at: code) else { return false }
      // Asking for a piano is asking for sound, so this ignores the sound setting.
      effects.play(.note(piano.frequency(of: key)))
    }
    return true
  }

  /// Any key, tap or scroll.
  public func userActed() {
    lastActivity = effects.now()
    hasCatVisited = false
  }

  /// Leave the keyboard alone long enough and a cat will find it, once per quiet stretch.
  /// Call it every few seconds.
  public func clockTicked() async {
    guard !hasCatVisited, effects.now() - lastActivity >= Self.catPatience,
      mode == .shell, pager == nil, popup == nil, !isMenuOpen, !isTyping, !isCatWalking
    else { return }
    hasCatVisited = true
    typingGeneration += 1
    let generation = typingGeneration
    isCatWalking = true
    isTyping = true
    completionMenu = nil
    defer { isCatWalking = false }
    await effects.pause(2200)
    var generator = SystemRandomNumberGenerator()
    for character in Pets.pawPrints(using: &generator) {
      guard generation == typingGeneration else { return }
      input.append(character)
      play(.key)
      await effects.pause(Int.random(in: 50...130))
    }
    guard generation == typingGeneration else { return }
    isTyping = false
    await effects.pause(2500)
  }

  public func popupDismissed() {
    guard popup != nil else { return }
    popup = nil
    play(.close)
  }

  /// Types `command` at the prompt, then runs it. A newer click interrupts an older one.
  private func type(_ command: String) async {
    typingGeneration += 1
    let generation = typingGeneration
    isTyping = true
    completionMenu = nil
    popup = nil
    mode = .shell
    if pager != nil {
      pager = nil
      effects.setLocation(location, false)
    }
    input = ""
    let perCharacter = max(8, min(38, 380 / max(command.count, 1)))
    for character in command {
      input.append(character)
      play(.key)
      await effects.pause(Int.random(in: perCharacter * 2 / 3...perCharacter * 4 / 3))
      guard generation == typingGeneration else { return }
    }
    await effects.pause(70)
    guard generation == typingGeneration else { return }
    isTyping = false
    returnKeyPressed()
  }

  private func run(_ line: String) {
    let stages = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingWhitespace }
    if stages.count > 1 {
      pipe(stages)
      return
    }
    let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
    let command = words[0].lowercased()
    let argument = words.dropFirst().joined(separator: " ")
    switch command {
    case "help", "?", "man":
      print(.help(Self.commands))
    case "ls", "dir", "ll":
      if let listing = listing(argument) { print(listing) }
    case "head", "tail":
      if let parsed = lineCount(argument, command: command), let listing = listing(parsed.rest) {
        print(limit(listing, to: parsed.count, fromEnd: command == "tail"))
      }
    case "cd":
      go(argument.isEmpty ? "~" : argument, command: command)
    case "cat" where argument.isEmpty:
      print(.text(Pets.cats.randomElement()!))
    case "open", "cat", "less", "more", "read", "view":
      if argument.isEmpty {
        fail("\(command): open what? try 'ls'.")
      } else {
        go(argument, command: command)
      }
    case "home":
      go("~", command: command)
    case "menu":
      print(.menu)
    case "clear", "cls":
      output = []
    case "sound":
      sound(argument.lowercased())
    case "simple", "exit", "logout", "quit":
      print(.text("goodbye.", tone: .dim))
      effects.leave(location)
    case "pwd":
      print(.text(cwd.display))
    case "whoami":
      print(.text("guest"))
    case "sudo":
      fail("nice try.")
    case "dog":
      print(.text(Pets.dog))
    case "weather":
      print(.text("in Bellingham? idk wind and/or rain probably"))
    case "import" where argument.lowercased() == "foundation":
      print(.text("What kinda machine do you think we're running here?"))
    case "swift", "swiftc":
      print(.text("What kinda machine do you think we're running here?"))
    case "xcodebuild":
      print(.text("lmao"))
    case "emacs":
      hang(for: 5000, then: "out of memory")
    case "nano":
      print(.text("nano: did you mean vim?"))
    case "vim", "vi":
      print(.text("vim: did you mean nano?"))
    case "fortune":
      if fortunes.isEmpty { fortunes = Fortune.all.shuffled() }
      print(.fortune(fortunes.removeLast()))
    case "sit", "meditate":
      mode = .sitting
      play(.bell)
    case "piano", "play":
      mode = .playing(Piano())
      play(.open)
    default:
      if site.lookup(line, from: cwd) != nil {
        go(line, command: command)
      } else {
        fail("\(words[0]): command not found. try 'help'.")
      }
    }
  }

  private func hang(for milliseconds: Int, then message: String) {
    mode = .waiting
    waitGeneration += 1
    let generation = waitGeneration
    Task {
      await effects.pause(milliseconds)
      guard mode == .waiting, generation == waitGeneration else { return }
      mode = .shell
      fail(message)
    }
  }

  private func go(_ target: String, command: String) {
    guard let node = site.lookup(target, from: cwd) else {
      fail("\(command): no such place: \(target)")
      return
    }
    visit(node)
  }

  private func visit(_ node: Node) {
    switch node {
    case .document(let page):
      pager = page
      play(.open)
    case .directory(let path), .unbuilt(let path):
      pager = nil
      cwd = path
      print(listing(of: path))
    }
    effects.setLocation(location, true)
  }

  private func arrive(at path: SitePath, announce: Bool) {
    let node = site.node(at: path) ?? .unbuilt(path)
    switch node {
    case .document(let page):
      if case .directory(let home) = site.node(at: page.home), home != cwd {
        print(.command(cwd: cwd, text: "cd \(home.display)"))
        cwd = home
        print(listing(of: home))
      }
      if pager != page {
        pager = page
        play(.open)
      }
    case .directory, .unbuilt:
      let path = node.path
      pager = nil
      guard path != cwd || announce else { return }
      if path != cwd {
        print(.command(cwd: cwd, text: "cd \(path.display)"))
      }
      cwd = path
      print(listing(of: path))
    }
  }

  /// Only `ls | head` and `ls | tail` make sense here, so that's all a pipe can be.
  private func pipe(_ stages: [String]) {
    let words = stages.map { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
    guard stages.count == 2, let source = words[0].first?.lowercased(), ["ls", "dir", "ll"].contains(source),
      let filter = words[1].first?.lowercased(), ["head", "tail"].contains(filter)
    else {
      fail("pipes only go one way here: ls | head, or ls | tail.")
      return
    }
    guard let parsed = lineCount(words[1].dropFirst().joined(separator: " "), command: filter) else { return }
    guard parsed.rest.isEmpty else {
      fail("\(filter): it's already reading from ls.")
      return
    }
    if let listing = listing(words[0].dropFirst().joined(separator: " ")) {
      print(limit(listing, to: parsed.count, fromEnd: filter == "tail"))
    }
  }

  /// Reads `-5`, `-n 5` or `-n5` off the front, like head and tail do. Defaults to 10.
  private func lineCount(_ argument: String, command: String) -> (count: Int, rest: String)? {
    var words = argument.split(whereSeparator: \.isWhitespace).map(String.init)
    guard let first = words.first, first.hasPrefix("-") else { return (10, argument) }
    words.removeFirst()
    var digits = first.dropFirst()
    if digits.first == "n" {
      digits = digits.dropFirst()
      if digits.isEmpty, !words.isEmpty { digits = Substring(words.removeFirst()) }
    }
    guard let count = Int(digits), count >= 0 else {
      fail("\(command): how many? try '\(command) -5'.")
      return nil
    }
    return (count, words.joined(separator: " "))
  }

  private func limit(_ content: OutputEntry.Content, to count: Int, fromEnd: Bool) -> OutputEntry.Content {
    guard case .listing(let path, let entries, let order) = content else { return content }
    return .listing(path, Array(fromEnd ? entries.suffix(count) : entries.prefix(count)), order: order)
  }

  /// `nil` once it has complained.
  private func listing(_ argument: String) -> OutputEntry.Content? {
    let words = argument.split(whereSeparator: \.isWhitespace)
    let isFlag = { (word: Substring) in word.hasPrefix("-") && word.count > 1 }
    let flags = words.filter(isFlag).joined().filter { $0 != "-" }
    if let unknown = flags.first(where: { !"rlat1".contains($0) }) {
      fail("ls: no option -\(unknown). try 'ls -r' to flip the order.")
      return nil
    }
    let place = words.filter { !isFlag($0) }.joined(separator: " ")
    let target = place.isEmpty ? Node.directory(cwd) : site.lookup(place, from: cwd)
    switch target {
    case .directory(let path), .unbuilt(let path):
      return listing(of: path, reversed: flags.contains("r"))
    case .document(let page):
      return .listing(page.home, [Entry(path: page.path, kind: .document, title: page.title, date: page.date, note: page.note)])
    case nil:
      fail("ls: no such place: \(place)")
      return nil
    }
  }

  private func listing(of path: SitePath, reversed: Bool = false) -> OutputEntry.Content {
    guard var entries = site.entries(in: path), !entries.isEmpty else { return .underConstruction(path) }
    guard entries.allSatisfy({ $0.date != nil && $0.group == nil }),
      let first = entries.first?.date, let last = entries.last?.date, first != last
    else {
      return .listing(path, entries)
    }
    if reversed { entries.reverse() }
    let place = path == cwd ? "" : " \(path)"
    return .listing(path, entries, order: Order(newestFirst: (first > last) != reversed, flip: (reversed ? "ls" : "ls -r") + place))
  }

  private func sound(_ argument: String) {
    switch argument {
    case "on": isSoundOn = true
    case "off": isSoundOn = false
    case "": isSoundOn.toggle()
    default:
      fail("sound: on or off?")
      return
    }
    effects.saveSound(isSoundOn)
    print(.text("sound \(isSoundOn ? "on" : "off").", tone: .dim))
    play(.blip)
  }

  private func fail(_ message: String) {
    print(.text(message, tone: .error))
    play(.error)
  }

  private func play(_ effect: SoundEffect) {
    if isSoundOn { effects.play(effect) }
  }

  private func print(_ content: OutputEntry.Content) {
    output.append(OutputEntry(id: nextID, content: content))
    nextID += 1
    if output.count > Self.scrollbackLimit {
      output.removeFirst(output.count - Self.scrollbackLimit)
    }
  }
}

extension String {
  var trimmingWhitespace: String {
    String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
  }
}
