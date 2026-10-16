import Testing

@testable import FancyCore

struct SiteTests {
  let site = Site.fixture
  let posts = SitePath(["posts"])

  @Test func pathsRoundTripThroughURLs() {
    #expect(SitePath(urlPath: "/posts/decay/").components == ["posts", "decay"])
    #expect(SitePath(urlPath: "/posts/decay").urlPath == "/posts/decay/")
    #expect(SitePath(urlPath: "/").urlPath == "/")
  }

  @Test func resolvesRelativePaths() {
    #expect(posts.resolving("..") == .root)
    #expect(posts.resolving("~/about") == SitePath(["about"]))
    #expect(posts.resolving("/") == .root)
    #expect(posts.resolving("./decay/") == SitePath(["posts", "decay"]))
    #expect(SitePath.root.resolving("../..") == .root)
  }

  @Test func nodes() {
    #expect(site.node(at: .root) == .directory(.root))
    #expect(site.node(at: SitePath(["code"])) == .directory(SitePath(["code"])))
    #expect(site.node(at: SitePath(["lab"])) == .unbuilt(SitePath(["lab"])))
    #expect(site.node(at: SitePath(["solo_music"])) == .directory(SitePath(["music"])))
    #expect(site.node(at: SitePath(["nope"])) == nil)
    if case .document(let page) = site.node(at: SitePath(["about"])) {
      #expect(page.title == "Hi! I'm June!")
    } else {
      Issue.record("about should be a document")
    }
  }

  @Test func lookupForgivesCasePrefixesAndTitles() {
    #expect(site.lookup("DECAY", from: posts)?.path == SitePath(["posts", "decay"]))
    #expect(site.lookup("the-very", from: posts)?.path == SitePath(["posts", "the-very-last-light"]))
    #expect(site.lookup("the very last light", from: posts)?.path == SitePath(["posts", "the-very-last-light"]))
    #expect(site.lookup("t", from: posts) == nil)
    #expect(site.lookup("posts/decay", from: .root)?.path == SitePath(["posts", "decay"]))
  }

  @Test func homeListsBareNames() {
    let about = site.rootEntries.first { $0.name == "about" }
    #expect(about?.title == nil)
    #expect(about?.note == "who's this?")
    #expect(site.rootEntries.first { $0.name == "music" }?.kind == .directory)
  }

  @Test func readsListingsFromHTML() {
    let html = FakeNode.element(
      "div", [:],
      .element("a", ["href": "/code/"], .text("code")),
      .element("h2", [:], .text(" concert music ")),
      .element("p", [:], .element("a", ["href": "/concert_music/evocations/"], .text("Evocations")))
    )
    #expect(
      Directory.items(in: [html]) == [
        Directory.Item(path: SitePath(["code"])),
        Directory.Item(path: SitePath(["concert_music", "evocations"]), group: "concert music"),
      ]
    )
  }

  @Test func completesCommandsAndNames() {
    let commands = AppModel.commands.map(\.name)
    #expect(site.complete("hel", cwd: .root, commands: commands) == .replaced("help "))
    #expect(site.complete("po", cwd: .root, commands: commands) == .replaced("posts/"))
    #expect(site.complete("cd po", cwd: .root, commands: commands) == .replaced("cd posts/"))
    #expect(site.complete("open posts/de", cwd: .root, commands: commands) == .replaced("open posts/decay "))
    #expect(site.complete("open t", cwd: posts, commands: commands) == .candidates(base: "open ", names: ["the-very-last-light", "type-erasure"]))
    #expect(site.complete("open x", cwd: posts, commands: commands) == .none)
  }

  @Test func asciiArtScalesDown() {
    let art = AsciiArt(width: 4, height: 2, luminance: [0, 0, 255, 255, 0, 0, 255, 255])
    #expect(art.lines(maxColumns: 80) == ["  @@", "  @@"])
    #expect(art.lines(maxColumns: 2) == [" @"])
  }
}

struct SpinnerTests {
  @Test func drawsADiscThatTurnsWithoutChangingSize() {
    let spinner = Spinner(columns: 34, rows: 15)
    let frames = stride(from: 0.0, to: 8, by: 0.35).map { spinner.frame(time: $0) }
    #expect(frames.allSatisfy { $0.count == 15 && $0.allSatisfy { $0.count == 34 } })
    #expect(frames[0].joined().count { $0 != " " } > 100)
    #expect(Set(frames).count == frames.count)
  }
}
