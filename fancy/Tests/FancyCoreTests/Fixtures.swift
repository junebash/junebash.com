@testable import FancyCore

struct FakeNode: HTMLNode {
  var tagName: String?
  var attributes: [String: String] = [:]
  var text = ""
  var childNodes: [FakeNode] = []

  var textContent: String {
    tagName == nil ? text : childNodes.map(\.textContent).joined()
  }

  func attribute(_ name: String) -> String? {
    attributes[name]
  }

  static func text(_ text: String) -> FakeNode {
    FakeNode(tagName: nil, text: text)
  }

  static func element(_ tag: String, _ attributes: [String: String] = [:], _ children: FakeNode...) -> FakeNode {
    FakeNode(tagName: tag, attributes: attributes, childNodes: children)
  }
}

extension Site {
  static func page(_ path: String, home: String? = nil, _ title: String, date: String? = nil, note: String? = nil) -> Page {
    Page(
      path: SitePath(urlPath: path),
      home: home.map(SitePath.init(urlPath:)),
      title: title,
      date: date,
      note: note,
      document: Document(blocks: [])
    )
  }

  static func items(_ paths: String..., group: String? = nil) -> [Directory.Item] {
    paths.map { Directory.Item(path: SitePath(urlPath: $0), group: group) }
  }

  static let fixture = Site(
    directories: [
      Directory(path: .root, items: items("/code/", "/music/", "/about/", "/posts/", "/now/", "/lab/")),
      Directory(path: SitePath(["code"]), note: "things i've built", items: items("/code/papanca/", "/code/redzone/")),
      Directory(
        path: SitePath(["music"]),
        note: "noise i've made",
        intro: "A collection of my musical works.",
        aliases: [SitePath(["solo_music"]), SitePath(["concert_music"])],
        items: items("/solo_music/nonscapes/", group: "solo projects & bands")
          + items("/concert_music/evocations/", group: "concert music")
      ),
      Directory(path: SitePath(["posts"]), note: "3 things i've written", items: items("/posts/decay/", "/posts/the-very-last-light/", "/posts/type-erasure/")),
      Directory(path: SitePath(["now"]), items: items("/now/2026-06-24/", "/now/2025-08-02/")),
    ],
    pages: [
      page("/about/", "Hi! I'm June!", note: "who's this?"),
      page("/code/papanca/", "Papanca", note: "a meditation timer"),
      page("/code/papanca/privacy-policy/", home: "/code/", "Papanca — Privacy Policy"),
      page("/code/redzone/", "Redzone"),
      page("/solo_music/nonscapes/", home: "/music/", "Nonscapes", date: "2013-01-01", note: "Album · 2013"),
      page("/concert_music/evocations/", home: "/music/", "Evocations", date: "2015-01-01", note: "sax & percussion"),
      page("/posts/decay/", "Decay", date: "2026-08-31"),
      page("/posts/the-very-last-light/", "The Very Last Light", date: "2026-03-29"),
      page("/posts/type-erasure/", "Type Erasure", date: "2020-09-30"),
      page("/now/2026-06-24/", "I'm now principal iOS engineer", date: "2026-06-24"),
      page("/now/2025-08-02/", "Moved house", date: "2025-08-02"),
    ]
  )

  var rootEntries: [Entry] { entries(in: .root)! }
}
