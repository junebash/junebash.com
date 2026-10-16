public struct Document: Equatable, Sendable {
  public var blocks: [Block]

  public init(blocks: [Block]) {
    self.blocks = blocks
  }

  public var images: [Image] {
    blocks.flatMap(\.images)
  }
}

public indirect enum Block: Equatable, Sendable {
  case heading(level: Int, [Span])
  case paragraph([Span])
  case list(ordered: Bool, items: [[Block]])
  case code(String)
  case quote([Block])
  case rule
  case image(Image)
  case embed(Embed)

  var images: [Image] {
    switch self {
    case .image(let image): [image]
    case .list(_, let items): items.flatMap { $0.flatMap(\.images) }
    case .quote(let blocks): blocks.flatMap(\.images)
    default: []
    }
  }
}

public struct Span: Equatable, Sendable {
  public var text: String
  public var style: Style
  public var link: String?

  public init(_ text: String, style: Style = [], link: String? = nil) {
    self.text = text
    self.style = style
    self.link = link
  }
}

public struct Style: OptionSet, Hashable, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let bold = Style(rawValue: 1 << 0)
  public static let italic = Style(rawValue: 1 << 1)
  public static let code = Style(rawValue: 1 << 2)
  public static let strike = Style(rawValue: 1 << 3)
  public static let dim = Style(rawValue: 1 << 4)
}

public struct Image: Equatable, Hashable, Sendable {
  public var src: String
  public var alt: String
  public var isLocal: Bool

  public init(src: String, alt: String, isLocal: Bool) {
    self.src = src
    self.alt = alt
    self.isLocal = isLocal
  }
}

public struct Embed: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case video
    case audio
    case page
  }

  public var src: String
  public var kind: Kind
  public var title: String
  /// The size the simple site gives the frame, in CSS pixels, when it gives one.
  public var width: Int?
  public var height: Int?

  public init(src: String, kind: Kind, title: String, width: Int? = nil, height: Int? = nil) {
    self.src = src
    self.kind = kind
    self.title = title
    self.width = width
    self.height = height
  }

  public init(src: String, title: String?) {
    let host = Embed.host(of: src)
    let kind: Kind =
      if host.contains("youtube") || host.contains("vimeo") { .video }
      else if host.contains("bandcamp") || host.contains("soundcloud") || host.contains("spotify") { .audio }
      else { .page }
    let fallback =
      switch kind {
      case .video: host.contains("vimeo") ? "vimeo" : "youtube"
      case .audio: host.contains("bandcamp") ? "bandcamp" : host.contains("soundcloud") ? "soundcloud" : "audio"
      case .page: host.isEmpty ? "embedded page" : host
      }
    self.init(src: src, kind: kind, title: title.flatMap { $0.isEmpty ? nil : $0 } ?? fallback)
  }

  static func host(of url: String) -> String {
    var rest = Substring(url)
    if let scheme = rest.firstRange(of: "//") {
      rest = rest[scheme.upperBound...]
    }
    return String(rest.prefix { $0 != "/" && $0 != "?" && $0 != "#" }).lowercased()
  }
}

