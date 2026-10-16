public enum Completion: Equatable, Sendable {
  case none
  case replaced(String)
  /// Several names fit and none can be filled in further; each would follow `base`.
  case candidates(base: String, names: [String])
}

/// A shell's menu completion: candidates are on screen, and tab steps through them.
public struct CompletionMenu: Equatable, Sendable {
  /// The output entry that shows the candidates.
  public var entryID: Int
  public var base: String
  public var names: [String]
  public var selected: Int?

  var selection: String? {
    selected.map { base + names[$0] }
  }
}

extension Site {
  public func complete(_ input: String, cwd: SitePath, commands: [String]) -> Completion {
    let words = input.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    let head = words.dropLast().joined(separator: " ")
    let word = words.last ?? ""
    let prefix = head.isEmpty ? "" : head + " "

    let slash = word.lastIndex(of: "/")
    let directoryPart = slash.map { String(word[...$0]) } ?? ""
    let namePart = slash.map { String(word[word.index(after: $0)...]) } ?? word
    let directory = cwd.resolving(directoryPart)

    var names = (entries(in: directory) ?? []).map { $0.kind == .document ? $0.name : $0.name + "/" }
    if words.count == 1 && slash == nil {
      names = commands + names
    }
    let matches = names.filter { $0.lowercased().hasPrefix(namePart.lowercased()) }

    switch matches.count {
    case 0:
      return .none
    case 1:
      let match = matches[0]
      return .replaced(prefix + directoryPart + match + (match.hasSuffix("/") ? "" : " "))
    default:
      let common = commonPrefix(matches)
      if common.count > namePart.count {
        return .replaced(prefix + directoryPart + common)
      }
      return .candidates(base: prefix + directoryPart, names: matches)
    }
  }

  private func commonPrefix(_ strings: [String]) -> String {
    guard var result = strings.first?.lowercased() else { return "" }
    for string in strings.dropFirst() {
      result = String(zip(result, string.lowercased()).prefix { $0 == $1 }.map(\.0))
    }
    return String(strings[0].prefix(result.count))
  }
}
