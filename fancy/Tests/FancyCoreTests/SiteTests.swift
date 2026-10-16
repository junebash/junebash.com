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
    #expect(site.node(at: SitePath(["code"])) == .unbuilt(SitePath(["code"])))
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

  @Test func completesCommandsAndNames() {
    let commands = AppModel.commands.map(\.name)
    #expect(site.complete("he", cwd: .root, commands: commands) == .replaced("help "))
    #expect(site.complete("po", cwd: .root, commands: commands) == .replaced("posts/"))
    #expect(site.complete("cd po", cwd: .root, commands: commands) == .replaced("cd posts/"))
    #expect(site.complete("open posts/de", cwd: .root, commands: commands) == .replaced("open posts/decay "))
    #expect(site.complete("open t", cwd: posts, commands: commands) == .candidates(["the-very-last-light", "type-erasure"]))
    #expect(site.complete("open x", cwd: posts, commands: commands) == .none)
  }

  @Test func asciiArtScalesDown() {
    let art = AsciiArt(width: 4, height: 2, luminance: [0, 0, 255, 255, 0, 0, 255, 255])
    #expect(art.lines(maxColumns: 80) == ["  @@", "  @@"])
    #expect(art.lines(maxColumns: 2) == [" @"])
  }
}
