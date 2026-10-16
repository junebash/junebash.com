import Testing

@testable import FancyCore

final class Recorder {
  var locations: [(SitePath, Bool)] = []
  var sounds: [SoundEffect] = []
  var left: SitePath?

  var pause: (Int) async -> Void = { _ in }

  func model(isSoundOn: Bool = true) -> AppModel {
    AppModel(
      site: .fixture,
      isSoundOn: isSoundOn,
      effects: AppModel.Effects(
        setLocation: { self.locations.append(($0, $1)) },
        play: { self.sounds.append($0) },
        leave: { self.left = $0 },
        saveSound: { _ in },
        pause: { await self.pause($0) }
      )
    )
  }
}

struct AppModelTests {
  let recorder = Recorder()

  func run(_ model: AppModel, _ line: String) {
    model.inputChanged(line)
    model.returnKeyPressed()
  }

  @Test func startsWithWelcomeAndRootListing() {
    let model = recorder.model()
    model.started(at: .root)
    #expect(model.output.map(\.content) == [.welcome, .listing(.root, Site.fixture.rootEntries)])
    #expect(recorder.locations.last! == (.root, false))
  }

  @Test func deepLinkToPostOpensPagerOverItsDirectory() {
    let model = recorder.model()
    model.started(at: SitePath(["posts", "decay"]))
    #expect(model.cwd == SitePath(["posts"]))
    #expect(model.pager?.title == "Decay")
    model.pagerDismissed()
    #expect(model.pager == nil)
    #expect(recorder.locations.last! == (SitePath(["posts"]), true))
  }

  @Test func cdListsAndUpdatesLocation() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "cd posts")
    #expect(model.cwd == SitePath(["posts"]))
    guard case .listing(let path, let entries, let order) = model.output.last?.content else {
      Issue.record("expected listing")
      return
    }
    #expect(path == SitePath(["posts"]))
    #expect(entries.map(\.name) == ["decay", "the-very-last-light", "type-erasure"])
    #expect(order == Order(newestFirst: true, flip: "ls -r"))
    #expect(recorder.locations.last! == (SitePath(["posts"]), true))
  }

  @Test func lsDashRFlipsTheOrder() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "ls -r posts")
    guard case .listing(_, let entries, let order) = model.output.last?.content else {
      Issue.record("expected listing")
      return
    }
    #expect(entries.map(\.name) == ["type-erasure", "the-very-last-light", "decay"])
    #expect(order == Order(newestFirst: false, flip: "ls ~/posts"))
    run(model, "ls -la")
    #expect(model.output.last?.content == .listing(.root, Site.fixture.rootEntries))
    run(model, "ls -x")
    #expect(model.output.last?.content == .text("ls: no option -x. try 'ls -r' to flip the order.", tone: .error))
  }

  @Test func bareNamesOpenThings() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "about")
    #expect(model.pager?.path == SitePath(["about"]))
  }

  @Test func unbuiltSectionsShowConstruction() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "cd lab")
    #expect(model.cwd == SitePath(["lab"]))
    #expect(model.output.last?.content == .underConstruction(SitePath(["lab"])))
  }

  @Test func musicPagesLiveInOneListingWhateverTheirURL() async {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "cd music")
    guard case .listing(_, let entries, let order) = model.output.last?.content else {
      Issue.record("expected listing")
      return
    }
    #expect(entries.map(\.group) == ["solo projects & bands", "concert music"])
    #expect(order == nil)
    run(model, "open nonscapes")
    #expect(model.pager?.path == SitePath(["solo_music", "nonscapes"]))
    model.pagerDismissed()
    #expect(model.cwd == SitePath(["music"]))
    await model.entryClicked(SitePath(["concert_music", "evocations"]))
    #expect(model.output.contains { $0.content == .command(cwd: SitePath(["music"]), text: "open evocations") })
  }

  @Test func deepLinksLandInThePageHome() {
    let model = recorder.model()
    model.started(at: SitePath(["solo_music", "nonscapes"]))
    #expect(model.cwd == SitePath(["music"]))
    #expect(model.pager?.title == "Nonscapes")

    let other = recorder.model()
    other.started(at: SitePath(["code", "papanca", "privacy-policy"]))
    #expect(other.cwd == SitePath(["code"]))
    #expect(other.pager?.title == "Papanca — Privacy Policy")
  }

  @Test func sectionURLsShowTheirListing() {
    let model = recorder.model()
    model.started(at: SitePath(["concert_music"]))
    #expect(model.cwd == SitePath(["music"]))
    #expect(recorder.locations.last! == (SitePath(["music"]), false))
  }

  @Test func onlyDatedListingsOfferToFlip() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "cd now")
    guard case .listing(_, _, let order) = model.output.last?.content else {
      Issue.record("expected listing")
      return
    }
    #expect(order == Order(newestFirst: true, flip: "ls -r"))
    run(model, "ls ~/code")
    guard case .listing(_, _, let codeOrder) = model.output.last?.content else {
      Issue.record("expected listing")
      return
    }
    #expect(codeOrder == nil)
  }

  @Test func unknownCommandsFail() {
    let model = recorder.model()
    run(model, "frobnicate")
    #expect(model.output.last?.content == .text("frobnicate: command not found. try 'help'.", tone: .error))
    #expect(recorder.sounds.last == .error)
  }

  @Test func historyWalksBackAndForth() {
    let model = recorder.model()
    run(model, "help")
    run(model, "ls")
    model.inputChanged("draft")
    model.upArrowPressed()
    #expect(model.input == "ls")
    model.upArrowPressed()
    #expect(model.input == "help")
    model.upArrowPressed()
    #expect(model.input == "help")
    model.downArrowPressed()
    model.downArrowPressed()
    #expect(model.input == "draft")
  }

  @Test func clickingTypesTheCommand() async {
    let model = recorder.model()
    model.started(at: .root)
    await model.entryClicked(SitePath(["posts"]))
    #expect(model.output.contains { $0.content == .command(cwd: .root, text: "cd posts") })
    await model.entryClicked(SitePath(["posts", "decay"]))
    #expect(model.output.contains { $0.content == .command(cwd: SitePath(["posts"]), text: "open decay") })
    #expect(model.pager?.title == "Decay")
    #expect(recorder.sounds.filter { $0 == .key }.count >= "cd posts".count)
  }

  @Test func newerClickInterruptsTyping() async {
    recorder.pause = { _ in await Task.yield() }
    let model = recorder.model()
    model.started(at: .root)
    async let first: Void = model.commandClicked("help")
    async let second: Void = model.commandClicked("ls")
    _ = await (first, second)
    let commands = model.output.compactMap { entry -> String? in
      if case .command(_, let text) = entry.content { text } else { nil }
    }
    #expect(commands == ["ls"])
    #expect(!model.isTyping)
  }

  @Test func backButtonRestoresState() {
    let model = recorder.model()
    model.started(at: .root)
    run(model, "cd posts")
    run(model, "open decay")
    model.locationChanged(to: SitePath(["posts"]))
    #expect(model.pager == nil)
    model.locationChanged(to: .root)
    #expect(model.cwd == .root)
    #expect(model.output.last?.content == .listing(.root, Site.fixture.rootEntries))
  }

  @Test func soundCanBeSilenced() {
    let model = recorder.model()
    run(model, "sound off")
    recorder.sounds = []
    run(model, "nope")
    #expect(recorder.sounds.isEmpty)
  }

  @Test func simpleLeavesFromCurrentLocation() {
    let model = recorder.model()
    model.started(at: SitePath(["posts", "decay"]))
    model.leaveTapped()
    #expect(recorder.left == SitePath(["posts", "decay"]))
    model.pagerDismissed()
    run(model, "simple")
    #expect(recorder.left == SitePath(["posts"]))
  }
}
