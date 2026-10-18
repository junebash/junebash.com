import FancyCore
import JavaScriptKit

private func now() -> Double {
  window.performance.now().number ?? 0
}

/// `sit`: a breathing lotus over the whole screen.
final class ZenView {
  let model: AppModel
  let screen = byID("zen")
  let lotus = byID("zen-lotus")
  let breath = byID("zen-breath")
  private var sittingSince: Double?

  init(model: AppModel) {
    self.model = model
    observe { [self] in render(isSitting: model.mode == .sitting) }
  }

  /// The keypress that started sitting shouldn't also end it.
  var isSettled: Bool {
    sittingSince.map { now() - $0 > 800 } ?? false
  }

  private func render(isSitting: Bool) {
    guard isSitting != (sittingSince != nil) else { return }
    screen.setHidden(!isSitting)
    guard isSitting else {
      sittingSince = nil
      return
    }
    let start = now()
    sittingSince = start
    let figure = sized()
    if prefersReducedMotion {
      lotus.textContent = .string(figure.frame(time: Double(4)).joined(separator: "\n"))
      breath.textContent = "breathe."
      return
    }
    Task {
      while sittingSince == start {
        let time = (now() - start) / 1000
        lotus.textContent = .string(figure.frame(time: time).joined(separator: "\n"))
        breath.textContent = .string(Lotus.breath(at: time).isInhaling ? "breathe in" : "breathe out")
        await pause(milliseconds: 80)
      }
    }
  }

  private func sized() -> Lotus {
    let characterWidth = (byID("probe").getBoundingClientRect!().object!.width.number ?? 100) / 10
    lotus.textContent = .string(Array(repeating: " ", count: 10).joined(separator: "\n"))
    let lineHeight = (lotus.getBoundingClientRect!().object!.height.number ?? 200) / 10
    let width = (screen.clientWidth.number ?? 800) - 60
    let height = (screen.clientHeight.number ?? 600) - 60 - lineHeight * 2
    let columns = min(96, max(24, Int(width / max(characterWidth, 1))))
    let rows = min(36, max(10, Int(height / max(lineHeight, 1))))
    return Lotus(columns: columns, rows: rows, cellAspect: Float(characterWidth / max(lineHeight, 1)))
  }
}

/// `piano`: the keyboard becomes one.
final class PianoView {
  let model: AppModel
  let synth: Synth
  let screen = byID("piano")
  let keys = byID("piano-keys")
  let register = byID("piano-register")
  private var buttons: [Character: JSObject] = [:]

  init(model: AppModel, synth: Synth) {
    self.model = model
    self.synth = synth
    for (index, key) in Piano.lower.enumerated() {
      add(key, row: 2, column: index * 2 + 1)
    }
    for (slot, key) in Piano.upper {
      add(key, row: 1, column: slot * 2 + 2)
    }
    keys.listen("pointerdown") { [self] event in
      guard let character = event.target.closest(matching: "[data-key]")?.getAttribute!("data-key").string?.first else { return }
      _ = event.preventDefault()
      press(character)
    }
    observe { [self] in
      guard case .playing(let piano) = model.mode else {
        screen.setHidden(true)
        return
      }
      screen.setHidden(false)
      register.textContent = .string("octave \(piano.register)")
    }
  }

  /// Everything but shortcuts stops here, so letters don't leak into the prompt.
  func handleKey(_ event: JSValue) {
    let key = event.key.string ?? ""
    if key == "Escape" {
      model.closeKeyPressed()
    } else if event.repeat.boolean != true, key.count == 1, let character = key.first {
      press(character)
    }
  }

  private func press(_ character: Character) {
    synth.unlock()
    guard model.pianoKeyPressed(character), let button = buttons[Character(character.lowercased())] else { return }
    button.setClass("is-down", true)
    Task {
      await pause(milliseconds: 140)
      button.setClass("is-down", false)
    }
  }

  private func add(_ key: Piano.Key, row: Int, column: Int) {
    let button = element("div", "piano-key\(key.isUpper ? " is-upper" : "")")
    button.setAttr("data-key", String(key.key))
    button.setAttr("style", "grid-row: \(row); grid-column: \(column) / span 2")
    button.add(element("span", "piano-letter", text: String(key.key)))
    button.add(element("span", "piano-note", text: key.note))
    keys.add(button)
    buttons[key.key] = button
  }
}

/// Five idle minutes in, a cat crosses the bottom of the screen.
final class CatView {
  let model: AppModel
  let cat = byID("cat")
  private var isShown = false

  init(model: AppModel) {
    self.model = model
    observe { [self] in render(isWalking: model.isCatWalking) }
  }

  private func render(isWalking: Bool) {
    guard isWalking != isShown else { return }
    isShown = isWalking
    cat.setHidden(!isWalking)
    cat.setClass("is-walking", isWalking)
    guard isWalking else { return }
    Task {
      var step = 0
      while isShown {
        cat.textContent = .string(Pets.walking[step % Pets.walking.count])
        step += 1
        await pause(milliseconds: 260)
      }
    }
  }
}
