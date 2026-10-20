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

  func systemImageLoaded() {
    document.querySelector!(".boot-bar").object?.setClass("is-done", true)
  }

  /// Dots lead every status to the same column as the lines in fancy.html.
  static let statusColumn = 24

  @discardableResult
  func line(_ label: String, status: String) -> Line {
    let dots = String(repeating: ".", count: max(2, Self.statusColumn - label.count - 2))
    let row = element("div", "boot-line")
    row.add(element("span", "", text: label + " " + dots + " "))
    let value = element("span", "boot-status", text: status)
    row.add(value)
    log.add(row)
    return Line(status: value)
  }

  func beat(_ milliseconds: Int) async {
    await pause(milliseconds: fast ? 0 : milliseconds)
  }

  func fail(_ message: String) {
    log.add(element("div", "boot-error", text: message))
    window.fancyBootFailed.function?()
  }

  /// Resolves on the first key or tap, running `onGesture` synchronously inside it
  /// so audio unlock and keyboard focus count as user-initiated.
  func waitForGesture(_ onGesture: @escaping @MainActor () -> Void) async {
    let prompt = element("div", "boot-line boot-prompt", text: isTouchDevice ? "TAP TO BEGIN" : "PRESS ANY KEY TO BEGIN")
    log.add(prompt)
    var wasTap = false
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      var done = false
      let handler: @MainActor (JSValue) -> Void = { event in
        guard !done else { return }
        if event.metaKey.boolean == true || event.ctrlKey.boolean == true { return }
        done = true
        wasTap = event.type.string == "pointerup"
        _ = event.preventDefault()
        onGesture()
        continuation.resume()
      }
      document.listen("keydown", handler)
      document.listen("pointerup", handler)
    }
    root.setHidden(true)
    if wasTap { swallowNextClick() }
  }

  /// A tap's click arrives after its pointerup, so it would land on whatever the revealed shell put under the finger.
  private func swallowNextClick() {
    let until = JSDate.now() + 700
    var swallowed = false
    document.listen("click", capture: true) { event in
      guard !swallowed, JSDate.now() < until else { return }
      swallowed = true
      _ = event.stopPropagation()
      _ = event.preventDefault()
    }
  }
}
