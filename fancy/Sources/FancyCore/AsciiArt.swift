public struct AsciiArt: Equatable, Sendable {
  public static let ramp = Array(" .,:;-=+*#%@")

  public let width: Int
  public let height: Int
  private let levels: [UInt8]

  /// `luminance` is row-major, one value per character cell.
  public init(width: Int, height: Int, luminance: [UInt8]) {
    precondition(luminance.count == width * height)
    self.width = width
    self.height = height
    let low = Int(luminance.min() ?? 0)
    let high = Int(luminance.max() ?? 255)
    let span = max(high - low, 1)
    levels = luminance.map { UInt8((Int($0) - low) * 255 / span) }
  }

  public func lines(maxColumns: Int) -> [String] {
    let columns = max(1, min(width, maxColumns))
    let rows = max(1, height * columns / width)
    var lines: [String] = []
    lines.reserveCapacity(rows)
    for row in 0..<rows {
      let top = row * height / rows
      let bottom = max(top + 1, (row + 1) * height / rows)
      var line = ""
      for column in 0..<columns {
        let left = column * width / columns
        let right = max(left + 1, (column + 1) * width / columns)
        var total = 0
        for y in top..<bottom {
          for x in left..<right {
            total += Int(levels[y * width + x])
          }
        }
        let average = total / ((bottom - top) * (right - left))
        line.append(AsciiArt.ramp[average * (AsciiArt.ramp.count - 1) / 255])
      }
      while line.last == " " { line.removeLast() }
      lines.append(line)
    }
    return lines
  }
}
