public protocol HTMLNode {
  /// Lowercased tag name for elements, `nil` for text nodes.
  var tagName: String? { get }
  var textContent: String { get }
  var childNodes: [Self] { get }
  func attribute(_ name: String) -> String?
}

public struct HTMLConverter {
  public var isLocal: (String) -> Bool

  public init(isLocal: @escaping (String) -> Bool) {
    self.isLocal = isLocal
  }

  public func document<Node: HTMLNode>(from root: Node) -> Document {
    Document(blocks: blocks(from: root.childNodes))
  }

  func blocks<Node: HTMLNode>(from nodes: [Node]) -> [Block] {
    var builder = BlockBuilder()
    for node in nodes {
      visit(node, style: [], link: nil, into: &builder)
    }
    return builder.finish()
  }

  func spans<Node: HTMLNode>(from nodes: [Node], style: Style = []) -> [Span] {
    var builder = BlockBuilder()
    for node in nodes {
      visit(node, style: style, link: nil, into: &builder)
    }
    return builder.finish().flatMap { block -> [Span] in
      if case .paragraph(let spans) = block { spans } else { [] }
    }
  }

  private func visit<Node: HTMLNode>(
    _ node: Node,
    style: Style,
    link: String?,
    into builder: inout BlockBuilder
  ) {
    guard let tag = node.tagName else {
      builder.appendText(node.textContent, style: style, link: link)
      return
    }
    let classes = node.attribute("class")?.split(separator: " ") ?? []
    if classes.contains("zola-anchor") { return }

    func children(style: Style = style, link: String? = link) {
      for child in node.childNodes {
        visit(child, style: style, link: link, into: &builder)
      }
    }

    switch tag {
    case "script", "style", "noscript", "template", "button", "input", "form":
      return

    case "h1", "h2", "h3", "h4", "h5", "h6":
      let level = Int(String(tag.dropFirst())) ?? 2
      builder.append(.heading(level: level, spans(from: node.childNodes)))

    case "ul", "ol":
      let items = node.childNodes
        .filter { $0.tagName == "li" }
        .map { blocks(from: $0.childNodes) }
      builder.append(.list(ordered: tag == "ol", items: items))

    case "pre":
      var text = node.textContent
      while text.last == "\n" { text.removeLast() }
      builder.append(.code(text))

    case "blockquote":
      builder.append(.quote(blocks(from: node.childNodes)))

    case "hr":
      builder.append(.rule)

    case "img":
      guard let src = node.attribute("src"), !src.isEmpty else { return }
      builder.append(.image(Image(src: src, alt: node.attribute("alt") ?? "", isLocal: isLocal(src))))

    case "iframe", "video", "audio", "embed", "object":
      let source = node.attribute("src") ?? node.attribute("data")
        ?? node.childNodes.first { $0.tagName == "source" }?.attribute("src")
      guard let source, !source.isEmpty else { return }
      builder.append(.embed(Embed(src: source, title: node.attribute("title"))))

    case "table":
      for row in rows(of: node) {
        var line: [Span] = []
        for (index, cell) in row.enumerated() {
          if index > 0 { line.append(Span(" | ", style: .dim)) }
          line += spans(from: cell.childNodes, style: cell.tagName == "th" ? .bold : [])
        }
        builder.append(.paragraph(line))
      }

    case "p", "div", "section", "article", "header", "footer", "main", "aside", "figure",
      "center", "li", "dl", "dd", "dt", "details", "summary", "nav":
      if classes.contains("footnote-definition") {
        builder.append(contentsOf: footnote(node))
        return
      }
      builder.flush()
      children()
      builder.flush()

    case "figcaption":
      builder.flush()
      children(style: style.union(.italic).union(.dim))
      builder.flush()

    case "br":
      builder.appendBreak()

    case "strong", "b":
      children(style: style.union(.bold))

    case "em", "i", "cite", "dfn", "var":
      children(style: style.union(.italic))

    case "code", "kbd", "samp", "tt":
      children(style: style.union(.code))

    case "del", "s", "strike":
      children(style: style.union(.strike))

    case "a":
      let href = node.attribute("href")
      children(link: href.flatMap { $0.hasPrefix("#") || $0.isEmpty ? nil : $0 } ?? link)

    case "sup" where classes.contains("footnote-reference"):
      builder.appendText("[\(node.textContent)]", style: style.union(.dim), link: nil)

    default:
      children()
    }
  }

  private func footnote<Node: HTMLNode>(_ node: Node) -> [Block] {
    let label = node.childNodes.first { $0.tagName == "sup" }?.textContent ?? ""
    var result = blocks(from: node.childNodes.filter { $0.tagName != "sup" })
    let marker = Span("[\(label)] ", style: .dim)
    if case .paragraph(let spans) = result.first {
      result[0] = .paragraph([marker] + spans)
    } else {
      result.insert(.paragraph([marker]), at: 0)
    }
    return result
  }

  private func rows<Node: HTMLNode>(of node: Node) -> [[Node]] {
    node.childNodes.flatMap { child -> [[Node]] in
      switch child.tagName {
      case "tr": [child.childNodes.filter { $0.tagName == "td" || $0.tagName == "th" }]
      case "thead", "tbody", "tfoot": rows(of: child)
      default: []
      }
    }
  }
}

struct BlockBuilder {
  private var blocks: [Block] = []
  private var spans: [Span] = []

  mutating func appendText(_ text: String, style: Style, link: String?) {
    var collapsed = ""
    var lastWasSpace = spans.last.map { $0.text.last == " " || $0.text.last == "\n" } ?? true
    for character in text {
      if character.isWhitespace {
        if !lastWasSpace { collapsed.append(" ") }
        lastWasSpace = true
      } else {
        collapsed.append(character)
        lastWasSpace = false
      }
    }
    append(Span(collapsed, style: style, link: link))
  }

  mutating func appendBreak() {
    if var last = spans.popLast() {
      while last.text.last == " " { last.text.removeLast() }
      spans.append(last)
    }
    append(Span("\n"))
  }

  private mutating func append(_ span: Span) {
    guard !span.text.isEmpty else { return }
    if var last = spans.last, last.style == span.style, last.link == span.link {
      last.text += span.text
      spans[spans.count - 1] = last
    } else {
      spans.append(span)
    }
  }

  mutating func append(_ block: Block) {
    flush()
    blocks.append(block)
  }

  mutating func append(contentsOf blocks: [Block]) {
    flush()
    self.blocks += blocks
  }

  mutating func flush() {
    while var last = spans.last, last.text.last?.isWhitespace == true {
      last.text.removeLast()
      if last.text.isEmpty { spans.removeLast() } else { spans[spans.count - 1] = last }
    }
    if !spans.isEmpty {
      blocks.append(.paragraph(spans))
    }
    spans = []
  }

  mutating func finish() -> [Block] {
    flush()
    return blocks
  }
}
