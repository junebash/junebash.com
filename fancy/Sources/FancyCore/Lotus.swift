#if canImport(Darwin)
  import Darwin
#elseif canImport(WASILibc)
  import WASILibc
#elseif canImport(Glibc)
  import Glibc
#endif

/// A lotus on still water that opens as you breathe in and closes as you breathe out.
public struct Lotus: Sendable {
  public let columns: Int
  public let rows: Int
  public var cellAspect: Float

  static let ramp = Array(" .,:;-=+*#%@")
  static let inhale = 4.0
  static let exhale = 6.0
  static let base = SIMD2<Float>(0, -0.5)

  struct Petal {
    let angle: Float
    let length: Float
    let width: Float
    let brightness: Float
  }

  /// Back to front: a later petal covers an earlier one.
  static let petals: [Petal] =
    [52, -52, 18, -18].map { Petal(angle: $0, length: 1.0, width: 0.2, brightness: 0.1) }
    + [66, -66].map { Petal(angle: $0, length: 0.7, width: 0.2, brightness: 0.25) }
    + [36, -36].map { Petal(angle: $0, length: 0.85, width: 0.22, brightness: 0.32) }
    + [Petal(angle: 0, length: 0.95, width: 0.24, brightness: 0.42)]

  public init(columns: Int, rows: Int, cellAspect: Float = 0.5) {
    self.columns = columns
    self.rows = rows
    self.cellAspect = cellAspect
  }

  /// How far into the breath, from 0 (empty) to 1 (full), and which way it's going.
  public static func breath(at time: Double) -> (amount: Double, isInhaling: Bool) {
    let t = time.truncatingRemainder(dividingBy: inhale + exhale)
    let ease = { (x: Double) in (1 - cos(Double.pi * x)) / 2 }
    return t < inhale ? (ease(t / inhale), true) : (1 - ease((t - inhale) / exhale), false)
  }

  /// Every line is exactly `columns` wide.
  public func frame(time: Double) -> [String] {
    let breath = Float(Lotus.breath(at: time).amount)
    let spread = 0.82 + 0.28 * breath
    let reach = 0.94 + 0.08 * breath
    let petals = Lotus.petals.map { petal in
      let angle = petal.angle * spread * .pi / 180
      return (petal, sin(angle), cos(angle))
    }
    let height: Float = 1.6
    let width = height * Float(columns) * cellAspect / Float(rows)

    var lines: [String] = []
    lines.reserveCapacity(rows)
    for row in 0..<rows {
      var line = ""
      line.reserveCapacity(columns)
      let y = 0.55 - (Float(row) + 0.5) / Float(rows) * height
      for column in 0..<columns {
        let x = ((Float(column) + 0.5) / Float(columns) - 0.5) * width
        var level: Float?
        for (petal, s, c) in petals.reversed() {
          let d = SIMD2(x, y) - Lotus.base
          let along = d.x * s + d.y * c
          let across = d.x * c - d.y * s
          let length = petal.length * reach
          guard along > 0, along < length else { continue }
          let t = along / length
          // Widest a third of the way up, then tapering to a point.
          let halfWidth = petal.width * pow(sin(.pi * pow(t, 0.7)), 0.8) * (1.15 - 0.3 * t)
          let edge = abs(across) / max(halfWidth, 0.0001)
          guard edge < 1 else { continue }
          level = edge > 0.82 ? 0.08 : petal.brightness + 0.3 * (1 - edge) + 0.2 * t + 0.12 * breath
          break
        }
        line.append(level.map(Lotus.shade) ?? water(x: x, y: y, time: time))
      }
      lines.append(line)
    }
    return lines
  }

  private static func shade(_ level: Float) -> Character {
    let index = Int(level * Float(ramp.count - 1))
    return ramp[min(max(index, 1), ramp.count - 1)]
  }

  private func water(x: Float, y: Float, time: Double) -> Character {
    let pad = pow(x / 0.75, 2) + pow((y + 0.54) / 0.06, 2)
    if pad < 1 { return "=" }
    guard y < Lotus.base.y - 0.08 else { return " " }
    let depth = Lotus.base.y - y
    let ripple = sin(Double(x) * 7 / Double(1 + depth * 3) - time * 0.6 + Double(depth) * 31)
    let fade = Double(abs(x)) * 0.35 + Double(depth) * 0.5
    return ripple > 0.55 + fade ? "-" : " "
  }
}
