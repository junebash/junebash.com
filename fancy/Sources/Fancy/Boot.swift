import FancyCore
import JavaScriptKit

final class BootScreen {
  let root = byID("boot")
  let log = byID("boot-log")
  private let fast = prefersReducedMotion

  final class Line {
    let status: JSObject

    init(status: JSObject) {
      self.status = status
    }

    func update(_ text: String) {
      status.textContent = .string(text)
    }
  }

  @discardableResult
  func line(_ label: String, status: String = "") -> Line {
    let row = element("div", "boot-line")
    row.add(element("span", "", text: label + " "))
    let value = element("span", "boot-status", text: status)
    row.add(value)
    log.add(row)
    return Line(status: value)
  }

  func beat(_ milliseconds: Int) async {
    await pause(milliseconds: fast ? 0 : milliseconds)
  }

  func fail(_ message: String) {
    line(message).status.className = .string("boot-status boot-error")
    window.fancyBootFailed.function?()
  }

  /// Resolves on the first key or tap, running `onGesture` synchronously inside it
  /// so audio unlock and keyboard focus count as user-initiated.
  func waitForGesture(_ onGesture: @escaping @MainActor () -> Void) async {
    let prompt = element("div", "boot-line boot-prompt", text: isTouchDevice ? "TAP TO BEGIN" : "PRESS ANY KEY TO BEGIN")
    log.add(prompt)
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      var done = false
      let handler: @MainActor (JSValue) -> Void = { event in
        guard !done else { return }
        if event.metaKey.boolean == true || event.ctrlKey.boolean == true { return }
        done = true
        _ = event.preventDefault()
        onGesture()
        continuation.resume()
      }
      document.listen("keydown", handler)
      document.listen("pointerup", handler)
    }
    root.setHidden(true)
  }
}

enum ArtLoader {
  static let sampleColumns = 96
  /// Character cell width ÷ height for VT323 at `line-height: 1`.
  static let cellAspect = 0.42

  /// Draws a same-origin image small enough that each pixel is one character cell.
  static func load(_ src: String) async -> AsciiArt? {
    let image = window.Image.function!.new()
    image.src = .string(src)
    guard await settle(image.decode!()) else { return nil }
    let width = image.naturalWidth.number ?? 0
    let height = image.naturalHeight.number ?? 0
    guard width > 0, height > 0 else { return nil }
    let columns = sampleColumns
    let rows = max(1, Int(Double(columns) * height / width * cellAspect))

    let canvas = element("canvas")
    canvas.width = .number(Double(columns))
    canvas.height = .number(Double(rows))
    let options = JSObject()
    options.willReadFrequently = .boolean(true)
    guard let context = canvas.getContext!("2d", options).object else { return nil }
    context.imageSmoothingQuality = .string("high")
    context.fillStyle = .string("#000")
    _ = context.fillRect!(0, 0, columns, rows)
    _ = context.drawImage!(image, 0, 0, columns, rows)
    let pixels = JSUInt8ClampedArray(unsafelyWrapping: context.getImageData!(0, 0, columns, rows).object!.data.object!)
    let luminance = pixels.withUnsafeBytes { bytes -> [UInt8] in
      var result: [UInt8] = []
      result.reserveCapacity(bytes.count / 4)
      for index in stride(from: 0, to: bytes.count, by: 4) {
        let red = Int(bytes[index]) * 299
        let green = Int(bytes[index + 1]) * 587
        let blue = Int(bytes[index + 2]) * 114
        result.append(UInt8((red + green + blue) / 1000))
      }
      return result
    }
    return AsciiArt(width: columns, height: rows, luminance: luminance)
  }
}
