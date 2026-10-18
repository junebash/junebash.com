#if canImport(Darwin)
  import Darwin
#elseif canImport(WASILibc)
  import WASILibc
#elseif canImport(Glibc)
  import Glibc
#endif

/// The home row plays C lydian, the boot chord's scale; the row above fills in the other five notes.
/// Keys are physical positions (`KeyboardEvent.code`), so the shape is the same on any layout.
public struct Piano: Equatable, Sendable {
  public struct Key: Equatable, Sendable {
    public let code: String
    public let note: String
    public let semitone: Int
    public let isUpper: Bool
  }

  public static let lower = keys(
    ["KeyA", "KeyS", "KeyD", "KeyF", "KeyG", "KeyH", "KeyJ", "KeyK", "KeyL", "Semicolon", "Quote"],
    [0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 18],
    isUpper: false
  )
  /// Each upper key sits between the two home-row keys at `slot` and `slot + 1`.
  public static let upper = Array(
    zip(
      [0, 1, 2, 4, 5, 7, 8],
      keys(["KeyW", "KeyE", "KeyR", "KeyY", "KeyU", "KeyO", "KeyP"], [1, 3, 5, 8, 10, 13, 15], isUpper: true)
    )
  )
  public static let octaveDown = "KeyZ"
  public static let octaveUp = "KeyX"

  public static let octaves = -2...2

  public private(set) var octave = 0

  public init() {}

  public static func key(at code: String) -> Key? {
    lower.first { $0.code == code } ?? upper.first { $0.1.code == code }?.1
  }

  public var register: String {
    "C\(4 + octave)"
  }

  public mutating func shift(_ step: Int) {
    octave = min(max(octave + step, Self.octaves.lowerBound), Self.octaves.upperBound)
  }

  /// Equal temperament, except F# sits a little flat, the way it does in the boot chord.
  public func frequency(of key: Key) -> Double {
    let semitone = key.semitone + 12 * octave
    let cents = key.semitone % 12 == 6 ? -15.0 : 0
    return 261.63 * pow(2, (Double(semitone) + cents / 100) / 12)
  }

  private static func keys(_ codes: [String], _ semitones: [Int], isUpper: Bool) -> [Key] {
    let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return zip(codes, semitones).map { pair in
      Key(code: pair.0, note: names[pair.1 % 12], semitone: pair.1, isUpper: isUpper)
    }
  }
}
