#if canImport(Darwin)
  import Darwin
#elseif canImport(WASILibc)
  import WASILibc
#elseif canImport(Glibc)
  import Glibc
#endif

/// A compact disc flipping end over end, ray-traced into ASCII.
public struct Spinner: Sendable {
  public let columns: Int
  public let rows: Int
  /// Width of a character cell relative to its height.
  public var cellAspect: Float = 0.5

  static let ramp = Array(" .,-~:;=!*#$@")
  typealias Vector = SIMD3<Float>

  /// Disc proportions, in units of its radius. Thicker than a real CD so the rim survives edge-on.
  static let hole: Float = 0.13
  static let hub: Float = 0.34
  static let halfThickness: Float = 0.035

  public init(columns: Int, rows: Int, cellAspect: Float = 0.5) {
    self.columns = columns
    self.rows = rows
    self.cellAspect = cellAspect
  }

  /// Every line is exactly `columns` wide, so the frame never changes size.
  public func frame(time: Double) -> [String] {
    let rotation = Rotation(yaw: Float(time * 0.8), pitch: Float(0.28 + 0.1 * sin(time * 0.45)))
    let origin = rotation.apply(Vector(0, 0, 4.2))
    let light = rotation.apply(normalize(Vector(-0.5, 0.75, 0.8)))

    var lines: [String] = []
    lines.reserveCapacity(rows)
    for row in 0..<rows {
      var line = ""
      line.reserveCapacity(columns)
      let v = 1 - (Float(row) + 0.5) / Float(rows) * 2
      for column in 0..<columns {
        let u = (Float(column) + 0.5) / Float(columns) * 2 - 1
        let x = u * Float(columns) * cellAspect / Float(rows)
        let direction = rotation.apply(normalize(Vector(x, v, -3.5)))
        line.append(shade(origin: origin, direction: direction, light: light))
      }
      lines.append(line)
    }
    return lines
  }

  /// Everything here is in the disc's own space: it lies in the xy plane, centred on the origin.
  private func shade(origin: Vector, direction: Vector, light: Vector) -> Character {
    guard let (point, normal) = Spinner.hit(origin: origin, direction: direction) else { return " " }
    let diffuse = max(0, dot(normal, light))
    let radius = (point.x * point.x + point.y * point.y).squareRoot()
    let level: Float
    if normal.z == 0 {
      level = 0.35 + 0.5 * diffuse
    } else if radius < Spinner.hub {
      let stackingRing: Float = abs(radius - 0.29) < 0.025 ? 0.3 : 0
      level = 0.12 + 0.2 * diffuse + stackingRing
    } else if normal.z > 0 {
      // Grooves run in circles, so light catches where they cross the half vector: the CD's rainbow streak.
      let tangent = Vector(-point.y, point.x, 0) / radius
      let half = normalize(light - direction)
      let across = dot(tangent, half)
      let streak = pow(max(0, 1 - across * across), 80)
      let tracks: Float = radius > 0.93 ? 0.2 : 0.05 * sin(radius * 60)
      level = 0.18 + 0.3 * diffuse + 0.6 * streak + tracks
    } else {
      let band = abs(point.y) < 0.2 && radius > 0.42
      let rim = radius > 0.78 && radius < 0.9
      level = (band || rim) ? 0.1 + 0.15 * diffuse : 0.3 + 0.55 * diffuse
    }
    let index = Int(level * Float(Spinner.ramp.count - 1))
    return Spinner.ramp[min(max(index, 1), Spinner.ramp.count - 1)]
  }

  /// The nearest of the two faces and the outer rim, or nil for a miss.
  static func hit(origin: Vector, direction: Vector) -> (point: Vector, normal: Vector)? {
    var best: (distance: Float, point: Vector, normal: Vector)?
    if abs(direction.z) > 1e-6 {
      for face in [halfThickness, -halfThickness] {
        let distance = (face - origin.z) / direction.z
        guard distance > 0, distance < best?.distance ?? .infinity else { continue }
        let point = origin + direction * distance
        let radius = (point.x * point.x + point.y * point.y).squareRoot()
        if radius <= 1, radius >= hole {
          best = (distance, point, Vector(0, 0, face > 0 ? 1 : -1))
        }
      }
    }
    let a = direction.x * direction.x + direction.y * direction.y
    let b = 2 * (origin.x * direction.x + origin.y * direction.y)
    let c = origin.x * origin.x + origin.y * origin.y - 1
    let discriminant = b * b - 4 * a * c
    if a > 1e-6, discriminant >= 0 {
      let distance = (-b - discriminant.squareRoot()) / (2 * a)
      let point = origin + direction * distance
      if distance > 0, distance < best?.distance ?? .infinity, abs(point.z) <= halfThickness {
        best = (distance, point, Vector(point.x, point.y, 0))
      }
    }
    return best.map { ($0.point, $0.normal) }
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
