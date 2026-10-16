public struct Page: Equatable, Sendable {
  public var path: SitePath
  /// The listing this page belongs to, which isn't always its URL parent: music lives in five sections.
  public var home: SitePath
  public var title: String
  public var date: String?
  public var note: String?
  public var tags: [String]
  public var document: Document

  public init(
    path: SitePath,
    home: SitePath? = nil,
    title: String,
    date: String? = nil,
    note: String? = nil,
    tags: [String] = [],
    document: Document
  ) {
    self.path = path
    self.home = home ?? path.parent
    self.title = title
    self.date = date
    self.note = note
    self.tags = tags
    self.document = document
  }
}

public struct Directory: Equatable, Sendable {
  public struct Item: Equatable, Sendable {
    public var path: SitePath
    public var group: String?

    public init(path: SitePath, group: String? = nil) {
      self.path = path
      self.group = group
    }
  }

  public var path: SitePath
  public var note: String?
  public var intro: String?
  /// Other URLs that show this listing, like the simple site's per-section indexes.
  public var aliases: [SitePath]
  public var items: [Item]

  public init(path: SitePath, note: String? = nil, intro: String? = nil, aliases: [SitePath] = [], items: [Item]) {
    self.path = path
    self.note = note
    self.intro = intro
    self.aliases = aliases
    self.items = items
  }
}

public struct Entry: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case directory
    case document
    case unbuilt
  }

  public var path: SitePath
  public var kind: Kind
  public var title: String?
  public var date: String?
  public var note: String?
  public var group: String?

  public init(
    path: SitePath,
    kind: Kind,
    title: String? = nil,
    date: String? = nil,
    note: String? = nil,
    group: String? = nil
  ) {
    self.path = path
    self.kind = kind
    self.title = title
    self.date = date
    self.note = note
    self.group = group
  }

  public var name: String { path.name }
}

public enum Node: Equatable, Sendable {
  case directory(SitePath)
  case document(Page)
  case unbuilt(SitePath)

  public var path: SitePath {
    switch self {
    case .directory(let path), .unbuilt(let path): path
    case .document(let page): page.path
    }
  }
}

public struct Site: Sendable {
  private var directories: [SitePath: Directory] = [:]
  private var aliases: [SitePath: SitePath] = [:]
  private var pages: [SitePath: Page] = [:]

  public init(directories: [Directory], pages: [Page]) {
    for directory in directories {
      self.directories[directory.path] = directory
      for alias in directory.aliases {
        aliases[alias] = directory.path
      }
    }
    for page in pages {
      self.pages[page.path] = page
    }
  }

  public func node(at path: SitePath) -> Node? {
    if directories[path] != nil { return .directory(path) }
    if let canonical = aliases[path] { return .directory(canonical) }
    if let page = pages[path] { return .document(page) }
    if directories.values.contains(where: { $0.items.contains { $0.path == path } }) { return .unbuilt(path) }
    return nil
  }

  public func directory(at path: SitePath) -> Directory? {
    directories[path]
  }

  public func pages(under path: SitePath) -> [Page] {
    pages.values.filter { $0.path.components.starts(with: path.components) }
  }

  /// `nil` when `path` isn't a place; empty for places that aren't built.
  public func entries(in path: SitePath) -> [Entry]? {
    if let directory = directories[path] {
      // Home lists bare names, like a real home directory.
      return directory.items.map { path == .root ? named(entry(for: $0)) : entry(for: $0) }
    }
    if case .unbuilt = node(at: path) { return [] }
    return nil
  }

  private func named(_ entry: Entry) -> Entry {
    var entry = entry
    entry.title = nil
    entry.date = nil
    return entry
  }

  private func entry(for item: Directory.Item) -> Entry {
    if let directory = directories[item.path] {
      return Entry(path: item.path, kind: .directory, note: directory.note, group: item.group)
    }
    if let page = pages[item.path] {
      return Entry(path: page.path, kind: .document, title: page.title, date: page.date, note: page.note, group: item.group)
    }
    return Entry(path: item.path, kind: .unbuilt, group: item.group)
  }

  /// Resolves what someone typed, forgiving case, unambiguous prefixes, and titles.
  public func lookup(_ input: String, from cwd: SitePath) -> Node? {
    let target = cwd.resolving(input)
    if let node = node(at: target) { return node }
    guard let name = target.components.last?.lowercased(), let siblings = entries(in: target.parent)
    else { return nil }
    let match =
      siblings.first { $0.name.lowercased() == name }
      ?? siblings.first { $0.title?.lowercased() == name }
      ?? unique(siblings.filter { $0.name.lowercased().hasPrefix(name) })
    return match.flatMap { node(at: $0.path) }
  }

  private func unique(_ entries: [Entry]) -> Entry? {
    entries.count == 1 ? entries[0] : nil
  }
}

extension Directory {
  /// Reads a listing written as HTML: each heading starts a group, and each link is an entry.
  public static func items<Node: HTMLNode>(in nodes: [Node]) -> [Item] {
    var items: [Item] = []
    var group: String?
    func visit(_ node: Node) {
      switch node.tagName {
      case "h1", "h2", "h3", "h4", "h5", "h6":
        group = node.textContent.trimmingWhitespace
      case "a":
        if let href = node.attribute("href") {
          items.append(Item(path: SitePath(urlPath: href), group: group))
        }
      case nil:
        break
      default:
        node.childNodes.forEach(visit)
      }
    }
    nodes.forEach(visit)
    return items
  }
}
