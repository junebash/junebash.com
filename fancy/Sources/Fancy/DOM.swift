import JavaScriptKit
import Observation

let window = JSObject.global
let document = JSObject.global.document.object!

func byID(_ id: String) -> JSObject {
  document.getElementById!(id).object!
}

func element(_ tag: String, _ className: String = "", text: String? = nil) -> JSObject {
  let node = document.createElement!(tag).object!
  if !className.isEmpty { node.className = .string(className) }
  if let text { node.textContent = .string(text) }
  return node
}

extension JSObject {
  @discardableResult
  func add(_ child: JSObject) -> JSObject {
    _ = self.appendChild!(child)
    return self
  }

  func setAttr(_ attribute: String, _ value: String) {
    _ = self.setAttribute!(attribute, value)
  }

  func setClass(_ name: String, _ isOn: Bool) {
    _ = self.classList.object!.toggle!(name, isOn)
  }

  func setHidden(_ isHidden: Bool) {
    self.hidden = .boolean(isHidden)
  }

  func removeChildren() {
    self.textContent = ""
  }

  func listen(_ event: String, passive: Bool = false, capture: Bool = false, _ handler: @escaping @MainActor (JSValue) -> Void) {
    let closure = JSClosure { arguments in
      MainActor.assumeIsolated { handler(arguments[0]) }
      return .undefined
    }
    let options = JSObject()
    options.passive = .boolean(passive)
    options.capture = .boolean(capture)
    _ = self.addEventListener!(event, closure, options)
  }
}

extension JSValue {
  func closest(matching selector: String) -> JSObject? {
    guard let target = object, target.closest.function != nil else { return nil }
    return target.closest!(selector).object
  }

  func data(_ key: String) -> String? {
    object?.getAttribute!("data-" + key).string
  }
}

/// Re-runs `body` whenever any observable state it read changes.
func observe(_ body: @escaping @MainActor @Sendable () -> Void) {
  withObservationTracking(body) {
    Task { @MainActor in observe(body) }
  }
}

var prefersReducedMotion: Bool {
  window.matchMedia!("(prefers-reduced-motion: reduce)").matches.boolean ?? false
}

var isTouchDevice: Bool {
  window.matchMedia!("(hover: none)").matches.boolean ?? false
}

enum Preferences {
  static func get(_ key: String) -> String? {
    window.fancyPrefs.get(key).string
  }

  static func set(_ key: String, _ value: String) {
    _ = window.fancyPrefs.set(key, value)
  }
}

/// Waits for a JS promise; `false` if it rejected.
func settle(_ promise: JSValue) async -> Bool {
  guard let promise = promise.object.flatMap(JSPromise.init) else { return false }
  return await withCheckedContinuation { continuation in
    _ = promise.then(
      success: { _ in
        continuation.resume(returning: true)
        return .undefined
      },
      failure: { _ in
        continuation.resume(returning: false)
        return .undefined
      }
    )
  }
}

func pause(milliseconds: Int) async {
  try? await Task.sleep(for: .milliseconds(milliseconds))
}
