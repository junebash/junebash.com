import Testing

@testable import FancyCore

struct HTMLConverterTests {
  let converter = HTMLConverter { $0.hasPrefix("/") }

  func convert(_ nodes: FakeNode...) -> [Block] {
    converter.document(from: FakeNode(tagName: "body", childNodes: nodes)).blocks
  }

  @Test func paragraphsCollapseWhitespaceAndKeepStyles() {
    let blocks = convert(
      .element("p", [:], .text("\n  Hello,   "), .element("em", [:], .text("dear")), .text(" world  \n"))
    )
    #expect(blocks == [.paragraph([Span("Hello, "), Span("dear", style: .italic), Span(" world")])])
  }

  @Test func looseTextBecomesParagraphsAroundBlocks() {
    let blocks = convert(.text("before"), .element("hr"), .text("after"))
    #expect(blocks == [.paragraph([Span("before")]), .rule, .paragraph([Span("after")])])
  }

  @Test func headingsDropZolaAnchors() {
    let blocks = convert(
      .element("h2", [:], .text("Title "), .element("a", ["class": "zola-anchor", "href": "#title"], .text("#")))
    )
    #expect(blocks == [.heading(level: 2, [Span("Title")])])
  }

  @Test func linksKeepHrefButNotFragments() {
    let blocks = convert(
      .element(
        "p", [:],
        .element("a", ["href": "https://example.com"], .text("out")),
        .text(" "),
        .element("a", ["href": "#note"], .text("here"))
      )
    )
    #expect(blocks == [.paragraph([Span("out", link: "https://example.com"), Span(" here")])])
  }

  @Test func imagesInsideParagraphsBecomeBlocks() {
    let blocks = convert(
      .element("p", [:], .text("look: "), .element("img", ["src": "/images/a.png", "alt": "a"]), .text("nice"))
    )
    #expect(
      blocks == [
        .paragraph([Span("look:")]),
        .image(Image(src: "/images/a.png", alt: "a", isLocal: true)),
        .paragraph([Span("nice")]),
      ]
    )
  }

  @Test func iframesBecomeEmbeds() {
    let blocks = convert(.element("iframe", ["src": "https://www.youtube.com/embed/abc"]))
    #expect(blocks == [.embed(Embed(src: "https://www.youtube.com/embed/abc", kind: .video, title: "youtube"))])
  }

  @Test func framesKeepTheirPixelSize() {
    let blocks = convert(
      .element("iframe", ["src": "https://bandcamp.com/EmbeddedPlayer/album=1/", "style": "border: 0; width: 100%; height: 786px; max-width: 500px;"])
    )
    #expect(blocks == [.embed(Embed(src: "https://bandcamp.com/EmbeddedPlayer/album=1/", kind: .audio, title: "bandcamp", width: 500, height: 786))])
  }

  @Test func definitionListsBecomeFacts() {
    let blocks = convert(
      .element(
        "dl", [:],
        .element("dt", [:], .text("type")), .element("dd", [:], .text("Album")),
        .element("dt", [:], .text("year")), .element("dd", [:], .text("2013"))
      )
    )
    #expect(
      blocks == [
        .paragraph([
          Span("TYPE  ", style: .dim), Span("Album", style: .bold), Span("\n"),
          Span("YEAR  ", style: .dim), Span("2013", style: .bold),
        ])
      ]
    )
  }

  @Test func listsNestBlocks() {
    let blocks = convert(
      .element(
        "ul", [:],
        .text("\n"),
        .element("li", [:], .text("one")),
        .element("li", [:], .text("two"), .element("ol", [:], .element("li", [:], .text("inner"))))
      )
    )
    #expect(
      blocks == [
        .list(
          ordered: false,
          items: [
            [.paragraph([Span("one")])],
            [.paragraph([Span("two")]), .list(ordered: true, items: [[.paragraph([Span("inner")])]])],
          ]
        )
      ]
    )
  }

  @Test func preservesCodeText() {
    let blocks = convert(.element("pre", [:], .element("code", [:], .text("let x = 1\n  y\n"))))
    #expect(blocks == [.code("let x = 1\n  y")])
  }

  @Test func lineBreaksSurviveCollapsing() {
    let blocks = convert(.element("p", [:], .text("one "), .element("br"), .text(" two")))
    #expect(blocks == [.paragraph([Span("one\ntwo")])])
  }

  @Test func footnotes() {
    let blocks = convert(
      .element("p", [:], .text("claim"), .element("sup", ["class": "footnote-reference"], .element("a", ["href": "#1"], .text("1")))),
      .element(
        "div", ["class": "footnote-definition", "id": "1"],
        .element("sup", ["class": "footnote-definition-label"], .text("1")),
        .element("p", [:], .text("source"))
      )
    )
    #expect(
      blocks == [
        .paragraph([Span("claim"), Span("[1]", style: .dim)]),
        .paragraph([Span("[1] ", style: .dim), Span("source")]),
      ]
    )
  }

  @Test func skipsScripts() {
    let blocks = convert(.element("script", [:], .text("alert(1)")), .text("ok"))
    #expect(blocks == [.paragraph([Span("ok")])])
  }
}
