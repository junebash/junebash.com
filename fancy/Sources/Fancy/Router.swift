import FancyCore
import JavaScriptKit

/// Maps site paths to browser URLs. On fancy.<domain> the site lives at the root;
/// anywhere else (local dev, deploy previews) it lives under /fancy.
struct Router {
  let base: String
  let simpleOrigin: String

  init() {
    let location = window.location
    let host = location.host.string ?? ""
    let scheme = location.protocol.string ?? "https:"
    if host.hasPrefix("fancy.") {
      base = ""
      simpleOrigin = scheme + "//" + host.dropFirst("fancy.".count)
    } else {
      base = "/fancy"
      simpleOrigin = location.origin.string ?? ""
    }
  }

  var currentPath: SitePath {
    if let handedOff = JSObject.global.URLSearchParams.function!.new(window.location.search).get!("at").string {
      return SitePath(urlPath: handedOff)
    }
    var path = Substring(window.location.pathname.string ?? "/")
    if !base.isEmpty, path.hasPrefix(base) {
      path = path.dropFirst(base.count)
    }
    return SitePath(urlPath: String(path))
  }

  func href(for path: SitePath) -> String {
    base + path.urlPath
  }

  func setLocation(_ path: SitePath, push: Bool) {
    let url = href(for: path)
    if push {
      guard url != window.location.pathname.string else { return }
      _ = window.history.pushState(JSValue.null, "", url)
    } else {
      _ = window.history.replaceState(JSValue.null, "", url)
    }
  }

  func leave(to path: SitePath) {
    window.location.href = .string(simpleOrigin + path.urlPath)
  }

  /// Same-site page links become in-terminal navigation; links to files stay ordinary links.
  func internalPath(for href: String) -> SitePath? {
    var rest = Substring(href)
    for origin in ["https://junebash.com", "http://junebash.com", "https://www.junebash.com", simpleOrigin]
    where !origin.isEmpty && rest.hasPrefix(origin) {
      rest = rest.dropFirst(origin.count)
      break
    }
    guard rest.hasPrefix("/"), !rest.hasPrefix("//") else { return nil }
    let path = rest.prefix { $0 != "?" && $0 != "#" }
    if path.split(separator: "/").last?.contains(".") == true { return nil }
    return SitePath(urlPath: String(path))
  }

  /// Only root-relative images are same-origin on every host, which canvas reads require.
  static func isLocalAsset(_ src: String) -> Bool {
    src.hasPrefix("/") && !src.hasPrefix("//")
  }
}
