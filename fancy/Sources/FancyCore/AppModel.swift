import Observation

@Observable
public final class AppModel {
  public struct Effects {
    public var setLocation: (_ path: SitePath, _ push: Bool) -> Void
    public var play: (SoundEffect) -> Void
    public var leave: (SitePath) -> Void
    public var saveSound: (Bool) -> Void
    public var pause: (_ milliseconds: Int) async -> Void

    public init(
      setLocation: @escaping (SitePath, Bool) -> Void,
      play: @escaping (SoundEffect) -> Void,
      leave: @escaping (SitePath) -> Void,
      saveSound: @escaping (Bool) -> Void,
      pause: @escaping (Int) async -> Void
    ) {
      self.setLocation = setLocation
      self.play = play
      self.leave = leave
      self.saveSound = saveSound
      self.pause = pause
    }
  }

  public static let commands: [CommandInfo] = [
    CommandInfo(name: "help", usage: "help", summary: "show this list"),
    CommandInfo(name: "ls", usage: "ls [place]", summary: "list what's here"),
    CommandInfo(name: "cd", usage: "cd <place>", summary: "go somewhere"),
    CommandInfo(name: "open", usage: "open <name>", summary: "read something (or: cat, less)"),
    CommandInfo(name: "menu", usage: "menu", summary: "show a clickable menu"),
    CommandInfo(name: "clear", usage: "clear", summary: "wipe the screen"),
    CommandInfo(name: "sound", usage: "sound [on|off]", summary: "toggle the noises"),
    CommandInfo(name: "simple", usage: "simple", summary: "leave for the simple site"),
  ]

  public static let scrollbackLimit = 400

  public let site: Site
  public private(set) var cwd: SitePath = .root
  public private(set) var output: [OutputEntry] = []
  public private(set) var input = ""
  public private(set) var pager: Page?
  public private(set) var popup: Popup?
  public private(set) var isMenuOpen = false
  public private(set) var isSoundOn: Bool
  public private(set) var isTyping = false

  @ObservationIgnored private var history: [String] = []
  @ObservationIgnored private var historyIndex: Int?
  @ObservationIgnored private var draft = ""
  @ObservationIgnored private var nextID = 0
  @ObservationIgnored private let effects: Effects

  public init(site: Site, isSoundOn: Bool, effects: Effects) {
    self.site = site
    self.isSoundOn = isSoundOn
    self.effects = effects
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
    guard !isTyping, text != input else { return }
    input = text
    historyIndex = nil
    play(.key)
  }

  public func returnKeyPressed() {
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

  public func tabKeyPressed() {
    switch site.complete(input, cwd: cwd, commands: Self.commands.map(\.name)) {
    case .none:
      play(.error)
    case .replaced(let text):
      input = text
      play(.key)
    case .candidates(let names):
      print(.command(cwd: cwd, text: input))
      print(.candidates(names))
      play(.blip)
    }
  }

  public func upArrowPressed() {
    guard !history.isEmpty else { return }
    if historyIndex == nil { draft = input }
    let index = max(0, (historyIndex ?? history.count) - 1)
    historyIndex = index
    input = history[index]
  }

  public func downArrowPressed() {
    guard let index = historyIndex else { return }
    if index + 1 < history.count {
      historyIndex = index + 1
      input = history[index + 1]
    } else {
      historyIndex = nil
      input = draft
    }
  }

  public func interruptPressed() {
    print(.command(cwd: cwd, text: input + "^C"))
    input = ""
    historyIndex = nil
  }

  public func clearScreenPressed() {
    output = []
  }

  public func escapePressed() {
    if popup != nil {
      popupDismissed()
    } else if isMenuOpen {
      menuButtonTapped()
    } else if pager != nil {
      pagerDismissed()
    }
  }

  public func entryClicked(_ path: SitePath) async {
    guard let node = site.node(at: path) else { return }
    let name =
      if path.parent == cwd { path.name }
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

  public func popupDismissed() {
    guard popup != nil else { return }
    popup = nil
    play(.close)
  }

  private func type(_ command: String) async {
    guard !isTyping else { return }
    isTyping = true
    popup = nil
    if pager != nil {
      pager = nil
      effects.setLocation(location, false)
    }
    input = ""
    for character in command {
      input.append(character)
      play(.key)
      await effects.pause(Int.random(in: 18...55))
    }
    await effects.pause(90)
    isTyping = false
    returnKeyPressed()
  }

  private func run(_ line: String) {
    let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
    let command = words[0].lowercased()
    let argument = words.dropFirst().joined(separator: " ")
    switch command {
    case "help", "?", "man":
      print(.help(Self.commands))
    case "ls", "dir", "ll":
      list(argument)
    case "cd":
      go(argument.isEmpty ? "~" : argument, command: command)
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
    default:
      if site.lookup(line, from: cwd) != nil {
        go(line, command: command)
      } else {
        fail("\(words[0]): command not found. try 'help'.")
      }
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
    switch site.node(at: path) ?? .unbuilt(path) {
    case .document(let page):
      let parent = page.path.parent
      if case .directory = site.node(at: parent), parent != cwd {
        print(.command(cwd: cwd, text: "cd \(parent.display)"))
        cwd = parent
        print(listing(of: parent))
      }
      if pager != page {
        pager = page
        play(.open)
      }
    case .directory, .unbuilt:
      pager = nil
      guard path != cwd || announce else { return }
      if path != cwd {
        print(.command(cwd: cwd, text: "cd \(path.display)"))
      }
      cwd = path
      print(listing(of: path))
    }
  }

  private func list(_ argument: String) {
    let target = argument.isEmpty ? Node.directory(cwd) : site.lookup(argument, from: cwd)
    switch target {
    case .directory(let path), .unbuilt(let path):
      print(listing(of: path))
    case .document(let page):
      print(.listing(page.path.parent, [Entry(path: page.path, kind: .document, title: page.title, date: page.date)]))
    case nil:
      fail("ls: no such place: \(argument)")
    }
  }

  private func listing(of path: SitePath) -> OutputEntry.Content {
    if let entries = site.entries(in: path), !entries.isEmpty {
      .listing(path, entries)
    } else {
      .underConstruction(path)
    }
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
