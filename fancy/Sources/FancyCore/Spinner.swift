#if canImport(Darwin)
  import Darwin
#elseif canImport(WASILibc)
  import WASILibc
#elseif canImport(Glibc)
  import Glibc
#endif

/// A slowly turning CRT monitor, ray-marched into ASCII. Swap `distance(_:)` to change the object.
public struct Spinner: Sendable {
  public let columns: Int
  public let rows: Int
  /// Width of a character cell relative to its height.
  public var cellAspect: Float = 0.5

  static let ramp = Array(".,-~:;=!*#$@")
  typealias Vector = SIMD3<Float>

  public init(columns: Int, rows: Int, cellAspect: Float = 0.5) {
    self.columns = columns
    self.rows = rows
    self.cellAspect = cellAspect
  }

  public func frame(time: Double) -> [String] {
    let turn = Float(time * 0.55)
    let tilt = Float(0.22 + 0.07 * sin(time * 0.6))
    let rotation = Rotation(yaw: turn, pitch: tilt)
    let light = normalize(Vector(-0.55, 0.65, 0.75))
    let origin = Vector(0, 0, 4.6)
    let band = Int(time * 9)

    var lines: [String] = []
    lines.reserveCapacity(rows)
    for row in 0..<rows {
      var line = ""
      line.reserveCapacity(columns)
      let v = 1 - (Float(row) + 0.5) / Float(rows) * 2
      for column in 0..<columns {
        let u = (Float(column) + 0.5) / Float(columns) * 2 - 1
        let x = u * Float(columns) * cellAspect / Float(rows)
        let direction = normalize(Vector(x, v, -2.45))
        line.append(shade(origin: origin, direction: direction, rotation: rotation, light: light, row: row, band: band))
      }
      while line.last == " " { line.removeLast() }
      lines.append(line)
    }
    return lines
  }

  private func shade(origin: Vector, direction: Vector, rotation: Rotation, light: Vector, row: Int, band: Int) -> Character {
    var distanceTravelled: Float = 2.5
    for _ in 0..<48 {
      let point = origin + direction * distanceTravelled
      let local = rotation.apply(point)
      let distance = Spinner.distance(local)
      if distance < 0.003 {
        if Spinner.isScreen(local) {
          return (row + band) % 7 == 0 ? "=" : (row % 2 == 0 ? ":" : ".")
        }
        let normal = rotation.unapply(Spinner.normal(local))
        let lambert = max(0, dot(normal, light))
        let level = 0.12 + 0.88 * lambert
        let index = Int(level * Float(Spinner.ramp.count - 1))
        return Spinner.ramp[min(max(index, 0), Spinner.ramp.count - 1)]
      }
      distanceTravelled += distance
      if distanceTravelled > 9 { break }
    }
    return " "
  }

  static func isScreen(_ p: Vector) -> Bool {
    p.z > 0.55 && abs(p.x) < 0.66 && abs(p.y - 0.18) < 0.5
  }

  static func distance(_ p: Vector) -> Float {
    let body = roundBox(p - Vector(0, 0.1, 0), Vector(0.95, 0.82, 0.7), 0.1)
    let tube = roundBox(p - Vector(0, 0.16, -0.9), Vector(0.68, 0.55, 0.45), 0.16)
    let foot = roundBox(p - Vector(0, -0.86, 0.05), Vector(0.62, 0.08, 0.55), 0.04)
    let screen = roundBox(p - Vector(0, 0.18, 0.8), Vector(0.66, 0.5, 0.18), 0.06)
    let slot = roundBox(p - Vector(0.42, -0.5, 0.75), Vector(0.24, 0.022, 0.1), 0.01)
    let shell = min(min(body, tube), foot)
    return max(max(shell, -screen), -slot)
  }

  static func normal(_ p: Vector) -> Vector {
    let e: Float = 0.002
    let a = Vector(e, -e, -e)
    let b = Vector(-e, -e, e)
    let c = Vector(-e, e, -e)
    let d = Vector(e, e, e)
    return normalize(a * distance(p + a) + b * distance(p + b) + c * distance(p + c) + d * distance(p + d))
  }

  static func roundBox(_ p: Vector, _ halfSize: Vector, _ radius: Float) -> Float {
    let q = Vector(abs(p.x), abs(p.y), abs(p.z)) - halfSize + Vector(repeating: radius)
    let outside = length(Vector(max(q.x, 0), max(q.y, 0), max(q.z, 0)))
    return outside + min(max(q.x, max(q.y, q.z)), 0) - radius
  }

  struct Rotation {
    let cy, sy, cp, sp: Float

    init(yaw: Float, pitch: Float) {
      cy = cos(yaw)
      sy = sin(yaw)
      cp = cos(pitch)
      sp = sin(pitch)
    }

    /// World → object space.
    func apply(_ v: Vector) -> Vector {
      let pitched = Vector(v.x, v.y * cp - v.z * sp, v.y * sp + v.z * cp)
      return Vector(pitched.x * cy + pitched.z * sy, pitched.y, -pitched.x * sy + pitched.z * cy)
    }

    /// Object → world space.
    func unapply(_ v: Vector) -> Vector {
      let yawed = Vector(v.x * cy - v.z * sy, v.y, v.x * sy + v.z * cy)
      return Vector(yawed.x, yawed.y * cp + yawed.z * sp, -yawed.y * sp + yawed.z * cp)
    }
  }
}

private func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
  (a * b).sum()
}

private func length(_ v: SIMD3<Float>) -> Float {
  dot(v, v).squareRoot()
}

private func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
  v / max(length(v), 0.000_001)
}
