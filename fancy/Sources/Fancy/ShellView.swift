import FancyCore
import JavaScriptKit
import Observation

@Observable
final class Layout {
  var columns = 80

  @ObservationIgnored private let probe = byID("probe")
  @ObservationIgnored private let measured = byID("output")

  func measure() {
    let characterWidth = (probe.getBoundingClientRect!().object!.width.number ?? 100) / 10
    let width = measured.clientWidth.number ?? 800
    let columns = max(20, Int(width / max(characterWidth, 1)))
    if columns != self.columns { self.columns = columns }
  }
}

enum SpinnerView {
  static func start(in node: JSObject, wide: Bool) {
    let columns = wide ? 44 : 30
    let rows = wide ? 16 : 11
    node.textContent = .string(Array(repeating: " ", count: rows).joined(separator: "\n"))
    let characterWidth = (byID("probe").getBoundingClientRect!().object!.width.number ?? 100) / 10
    let lineHeight = (node.getBoundingClientRect!().object!.height.number ?? Double(rows) * 20) / Double(rows)
    let spinner = Spinner(columns: columns, rows: rows, cellAspect: Float(characterWidth / max(lineHeight, 1)))
    if prefersReducedMotion {
      node.textContent = .string(spinner.frame(time: 1.1).joined(separator: "\n"))
      return
    }
    let start = window.performance.now().number ?? 0
    Task {
      while node.isConnected.boolean == true {
        if isVisible(node) {
          let elapsed = ((window.performance.now().number ?? 0) - start) / 1000
          node.textContent = .string(spinner.frame(time: elapsed + 0.6).joined(separator: "\n"))
        }
        await pause(milliseconds: 70)
      }
    }
  }

  private static func isVisible(_ node: JSObject) -> Bool {
    guard document.hidden.boolean != true, byID("pager").hidden.boolean == true else { return false }
    let rect = node.getBoundingClientRect!().object!
    let shell = byID("shell").getBoundingClientRect!().object!
    return (rect.bottom.number ?? 0) > (shell.top.number ?? 0) && (rect.top.number ?? 0) < (shell.bottom.number ?? 0)
  }
}

/// The scrollback, prompt, and the real (visually hidden) input that keeps phone keyboards working.
final class ShellView {
  let model: AppModel
  let layout: Layout
  let screen = byID("shell")
  let output = byID("output")
  let prompt = byID("prompt")
  let mirror = byID("input-mirror")
  let input = byID("input")
  let renderer: OutputRenderer
  private var lastRenderedID = -1

  init(model: AppModel, layout: Layout) {
    self.model = model
    self.layout = layout
    renderer = OutputRenderer(site: model.site)

    observe { [self] in renderOutput(model.output) }
    observe { [self] in
      prompt.textContent = .string(model.prompt + " ")
      syncInput(model.input)
    }

    input.listen("input") { [self] _ in
      model.inputChanged(input.value.string ?? "")
      renderMirror()
    }
    for event in ["keyup", "click", "select"] {
      input.listen(event) { [self] _ in renderMirror() }
    }
    input.listen("focus") { [self] _ in screen.setClass("is-focused", true) }
    input.listen("blur") { [self] _ in screen.setClass("is-focused", false) }
    input.listen("keydown") { [self] event in handleKey(event) }
  }

  /// Phones are menu-first, so only desktop gets the keyboard focus up front.
  func reveal() {
    screen.setHidden(false)
    if !isTouchDevice { focus() }
  }

  func focus() {
    let options = JSObject()
    options.preventScroll = .boolean(true)
    _ = input.focus!(options)
  }

  private func handleKey(_ event: JSValue) {
    let key = event.key.string ?? ""
    let control = event.ctrlKey.boolean == true
    var handled = true
    switch key {
    case "Enter": model.returnKeyPressed()
    case "Tab": model.tabKeyPressed()
    case "ArrowUp": model.upArrowPressed()
    case "ArrowDown": model.downArrowPressed()
    case "Escape": model.escapePressed()
    case "c" where control: model.interruptPressed()
    case "l" where control: model.clearScreenPressed()
    default: handled = false
    }
    if handled { _ = event.preventDefault() }
  }

  private func renderOutput(_ entries: [OutputEntry]) {
    trim(before: entries.first?.id ?? .max)
    for entry in entries where entry.id > lastRenderedID {
      let node = renderer.render(entry)
      output.add(node)
      lastRenderedID = entry.id
      if entry.content == .welcome, let spinner = node.querySelector!(".t-spinner").object {
        SpinnerView.start(in: spinner, wide: layout.columns >= 76)
      }
    }
    screen.scrollTop = screen.scrollHeight
  }

  private func trim(before id: Int) {
    while let first = output.firstElementChild.object,
      let firstID = first.getAttribute!("data-id").string.flatMap(Int.init), firstID < id
    {
      _ = first.remove!()
    }
  }

  private func syncInput(_ text: String) {
    if input.value.string != text {
      input.value = .string(text)
      let end = text.utf16.count
      _ = input.setSelectionRange!(end, end)
    }
    renderMirror()
  }

  private func renderMirror() {
    let text = model.input
    let caret = min(Int(input.selectionStart.number ?? Double(text.utf16.count)), text.utf16.count)
    let utf16 = Array(text.utf16)
    let before = String(decoding: utf16[..<caret], as: UTF16.self)
    let rest = String(decoding: utf16[caret...], as: UTF16.self)
    mirror.removeChildren()
    _ = mirror.append!(before)
    let cursor = element("span", "t-cursor", text: rest.first.map(String.init) ?? " ")
    mirror.add(cursor)
    _ = mirror.append!(String(rest.dropFirst()))
    screen.scrollTop = screen.scrollHeight
  }
}
