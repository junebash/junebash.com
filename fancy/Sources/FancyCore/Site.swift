public struct Page: Equatable, Sendable {
  public var path: SitePath
  public var title: String
  public var date: String?
  public var tags: [String]
  public var document: Document

  public init(path: SitePath, title: String, date: String? = nil, tags: [String] = [], document: Document) {
    self.path = path
    self.title = title
    self.date = date
    self.tags = tags
    self.document = document
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
  public static let postsPath = SitePath(["posts"])

  public var rootEntries: [Entry]
  public var posts: [Page]
  private var pages: [SitePath: Page]

  public init(sections: [SiteData.Section], about: Page, posts: [Page]) {
    self.posts = posts
    pages = Dictionary(uniqueKeysWithValues: (posts + [about]).map { ($0.path, $0) })
    rootEntries = []
    rootEntries = sections.map { section in
      let path = SitePath(urlPath: section.path)
      let kind: Entry.Kind =
        if path == Site.postsPath { .directory }
        else if pages[path] != nil { .document }
        else { .unbuilt }
      return Entry(path: path, kind: kind, title: nil, date: nil)
    }
  }

  public func node(at path: SitePath) -> Node? {
    if path == .root || path == Site.postsPath { return .directory(path) }
    if let page = pages[path] { return .document(page) }
    if rootEntries.contains(where: { $0.path == path && $0.kind == .unbuilt }) { return .unbuilt(path) }
    return nil
  }

  public func entries(in path: SitePath) -> [Entry]? {
    switch path {
    case .root:
      rootEntries
    case Site.postsPath:
      posts.map { Entry(path: $0.path, kind: .document, title: $0.title, date: $0.date) }
    default:
      node(at: path).flatMap { if case .unbuilt = $0 { [] } else { nil } }
    }
  }

  /// Resolves what someone typed, forgiving case, unambiguous prefixes, and post titles.
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
