public struct SitePath: Hashable, Sendable, CustomStringConvertible {
  public var components: [String]

  public init(_ components: [String] = []) {
    self.components = components
  }

  public init(urlPath: String) {
    let path = urlPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
    components = path.split(separator: "/").map(String.init)
  }

  public static let root = SitePath()

  public var urlPath: String {
    components.isEmpty ? "/" : "/" + components.joined(separator: "/") + "/"
  }

  public var display: String {
    "/" + components.joined(separator: "/")
  }

  public var description: String {
    components.isEmpty ? "~" : "~/" + components.joined(separator: "/")
  }

  public var name: String {
    components.last ?? "~"
  }

  public var parent: SitePath {
    SitePath(Array(components.dropLast()))
  }

  public func appending(_ component: String) -> SitePath {
    SitePath(components + [component])
  }

  public func resolving(_ input: String) -> SitePath {
    var result: SitePath
    var rest = Substring(input)
    if rest.hasPrefix("~") {
      result = .root
      rest = rest.dropFirst()
    } else if rest.hasPrefix("/") {
      result = .root
    } else {
      result = self
    }
    for part in rest.split(separator: "/") {
      switch part {
      case ".": continue
      case "..": result = result.parent
      default: result = result.appending(String(part))
      }
    }
    return result
  }
}
