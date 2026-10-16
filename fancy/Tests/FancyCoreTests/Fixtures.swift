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
  static let fixture = Site(
    sections: [
      SiteData.Section(name: "code", path: "/code"),
      SiteData.Section(name: "about", path: "/about"),
      SiteData.Section(name: "posts", path: "/posts"),
    ],
    about: Page(path: SitePath(["about"]), title: "Hi! I'm June!", document: Document(blocks: [])),
    posts: [
      Page(path: SitePath(["posts", "decay"]), title: "Decay", date: "2026-08-31", document: Document(blocks: [])),
      Page(path: SitePath(["posts", "the-very-last-light"]), title: "The Very Last Light", date: "2026-03-29", document: Document(blocks: [])),
      Page(path: SitePath(["posts", "type-erasure"]), title: "Type Erasure", date: "2020-09-30", document: Document(blocks: [])),
    ]
  )
}
