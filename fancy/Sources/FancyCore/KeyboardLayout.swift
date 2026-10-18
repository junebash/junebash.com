/// What each physical key types, pieced together from plain keypresses: browsers mostly won't say.
public struct KeyboardLayout: Equatable, Sendable {
  static let codes = [
    ["KeyQ", "KeyW", "KeyE", "KeyR", "KeyT", "KeyY", "KeyU", "KeyI", "KeyO", "KeyP", "BracketLeft", "BracketRight"],
    ["KeyA", "KeyS", "KeyD", "KeyF", "KeyG", "KeyH", "KeyJ", "KeyK", "KeyL", "Semicolon", "Quote"],
    ["KeyZ", "KeyX", "KeyC", "KeyV", "KeyB", "KeyN", "KeyM", "Comma", "Period", "Slash"],
  ]

  /// QWERTY first: it's the guess until a keypress says otherwise.
  static let known: [[String: String]] = [
    ["qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"],
    ["',.pyfgcrl/=", "aoeuidhtns-", ";qjkxbmwvz"],
    ["qwfpgjluy;[]", "arstdhneio'", "zxcvbkm,./"],
    ["qwfpbjluy;[]", "arstgmneio'", "zxcdvkh,./"],
    ["qdrwbjfup;[]", "ashtgyneoi'", "zxmcvkl,./"],
    ["azertyuiop^$", "qsdfghjklmù", "wxcvbn,;:!"],
    ["qwertzuiopü+", "asdfghjklöä", "yxcvbnm,.-"],
  ].map { rows in
    Dictionary(uniqueKeysWithValues: zip(codes.joined(), rows.joined().map(String.init)))
  }

  private var learned: [String: String] = [:]

  public init() {}

  /// Only unshifted, single-character keys teach anything. `true` if a label may have changed.
  public mutating func learn(code: String, typed: String) -> Bool {
    guard typed.count == 1, typed != " ", learned[code] != typed else { return false }
    learned[code] = typed
    return true
  }

  /// `nil` once the keys seen so far match no layout we know and this one hasn't been pressed.
  public func label(for code: String) -> String? {
    learned[code] ?? candidate?[code]
  }

  private var candidate: [String: String]? {
    Self.known.first { layout in
      learned.allSatisfy { code, typed in layout[code].map { $0 == typed } ?? true }
    }
  }
}
