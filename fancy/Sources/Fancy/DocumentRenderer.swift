import FancyCore
import JavaScriptKit

/// Turns a `Document` into terminal-styled DOM. Clickable media are numbered with
/// `data-media` so one delegated click handler can find them in `media`.
struct DocumentRenderer {
  let router: Router
  let art: [String: AsciiArt]
  let columns: Int
  private(set) var media: [Popup] = []

  init(router: Router, art: [String: AsciiArt], columns: Int) {
    self.router = router
    self.art = art
    self.columns = columns
  }

  mutating func render(_ document: Document) -> JSObject {
    let container = element("div", "t-doc")
    for block in document.blocks {
      container.add(render(block))
    }
    return container
  }

  private mutating func render(_ block: Block) -> JSObject {
    switch block {
    case .heading(let level, let spans):
      let heading = element("div", "t-h t-h\(min(level, 4))")
      heading.add(element("span", "t-hmark", text: String(repeating: "#", count: level) + " "))
      append(spans, to: heading)
      return heading

    case .paragraph(let spans):
      let paragraph = element("p", "t-p")
      append(spans, to: paragraph)
      return paragraph

    case .list(let ordered, let items):
      let list = element(ordered ? "ol" : "ul", "t-list")
      for item in items {
        let row = element("li")
        for block in item { row.add(render(block)) }
        list.add(row)
      }
      return list

    case .code(let text):
      return element("pre", "t-code", text: text)

    case .quote(let blocks):
      let quote = element("blockquote", "t-quote")
      for block in blocks { quote.add(render(block)) }
      return quote

    case .rule:
      return element("div", "t-rule", text: String(repeating: "- ", count: max(4, min(columns, 64) / 2)))

    case .image(let image):
      media.append(.image(image))
      let index = media.count - 1
      if let art = art[image.src] {
        let figure = element("figure", "t-figure")
        figure.setAttr("data-media", String(index))
        figure.add(element("pre", "t-art", text: art.lines(maxColumns: min(columns, 60)).joined(separator: "\n")))
        figure.add(element("figcaption", "t-caption", text: "▸ " + (image.alt.isEmpty ? "view photo" : image.alt)))
        return figure
      }
      return mediaLink(index: index, label: "[IMAGE]", title: image.alt.isEmpty ? "untitled" : image.alt)

    case .embed(let embed):
      media.append(.embed(embed))
      let label =
        switch embed.kind {
        case .video: "[▶ VIDEO]"
        case .audio: "[♪ AUDIO]"
        case .page: "[WINDOW]"
        }
      return mediaLink(index: media.count - 1, label: label, title: embed.title)
    }
  }

  private func mediaLink(index: Int, label: String, title: String) -> JSObject {
    let row = element("div", "t-media")
    row.setAttr("data-media", String(index))
    row.setAttr("role", "button")
    row.setAttr("tabindex", "0")
    row.add(element("span", "t-media-label", text: label + " "))
    row.add(element("span", "t-media-title", text: title))
    row.add(element("span", "t-media-open", text: "  ▸ open"))
    return row
  }

  private func append(_ spans: [Span], to parent: JSObject) {
    for span in spans {
      let node: JSObject
      if let link = span.link {
        node = element("a", spanClass(span.style), text: span.text)
        if let path = router.internalPath(for: link) {
          node.setAttr("href", router.href(for: path))
          node.setAttr("data-internal", path.urlPath)
        } else {
          node.setAttr("href", link)
          node.setAttr("target", "_blank")
          node.setAttr("rel", "noopener noreferrer")
        }
      } else if span.style.isEmpty {
        _ = parent.append!(span.text)
        continue
      } else {
        node = element("span", spanClass(span.style), text: span.text)
      }
      parent.add(node)
    }
  }

  private func spanClass(_ style: Style) -> String {
    var classes: [String] = []
    if style.contains(.bold) { classes.append("t-b") }
    if style.contains(.italic) { classes.append("t-i") }
    if style.contains(.code) { classes.append("t-c") }
    if style.contains(.strike) { classes.append("t-s") }
    if style.contains(.dim) { classes.append("t-dim") }
    return classes.joined(separator: " ")
  }
}
