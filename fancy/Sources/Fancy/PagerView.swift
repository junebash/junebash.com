import FancyCore
import JavaScriptKit

final class PagerView {
  let model: AppModel
  let router: Router
  let layout: Layout
  let darkroom: Darkroom
  let shell: ShellView
  let root = byID("pager")
  let title = byID("pager-title")
  let meta = byID("pager-meta")
  let body = byID("pager-body")
  let status = byID("pager-status")
  private var media: [Popup] = []
  private var shownPath: SitePath?

  init(model: AppModel, router: Router, layout: Layout, darkroom: Darkroom, shell: ShellView) {
    self.model = model
    self.router = router
    self.layout = layout
    self.darkroom = darkroom
    self.shell = shell

    observe { [self] in render(model.pager, columns: layout.columns) }
    observe { document.title = .string(model.title) }
    body.listen("scroll", passive: true) { [self] _ in updateStatus() }
  }

  func mediaClicked(_ index: Int) {
    guard media.indices.contains(index) else { return }
    switch media[index] {
    case .image(let image): model.imageClicked(image)
    case .embed(let embed): model.embedClicked(embed)
    }
  }

  /// Returns whether the pager consumed the key. Browser shortcuts (cmd-f and friends) pass through.
  func handleKey(_ event: JSValue) -> Bool {
    guard model.pager != nil, model.popup == nil, !model.isMenuOpen,
      event.metaKey.boolean != true, event.altKey.boolean != true
    else { return false }
    let key = event.key.string ?? ""
    let isControl = event.ctrlKey.boolean == true
    let line = 24.0
    let page = max(line, (body.clientHeight.number ?? 400) - line * 2)
    switch (key, isControl) {
    case ("d", true): scroll(by: page)
    case ("u", true): scroll(by: -page)
    case (_, true): return false
    case (" ", _): scroll(by: event.shiftKey.boolean == true ? -page : page)
    case ("Backspace", _), ("ArrowLeft", _): model.pagerDismissed()
    case ("ArrowDown", _), ("j", _): scroll(by: line * 2, smoothly: false)
    case ("ArrowUp", _), ("k", _): scroll(by: -line * 2, smoothly: false)
    case ("PageDown", _), ("f", _): scroll(by: page)
    case ("PageUp", _), ("b", _): scroll(by: -page)
    case ("g", _), ("Home", _): body.scrollTop = .number(0)
    case ("G", _), ("End", _): body.scrollTop = body.scrollHeight
    default: return false
    }
    return true
  }

  /// Line steps jump, like a real pager; a smooth step would cancel the one before it when keys repeat.
  private func scroll(by amount: Double, smoothly: Bool = true) {
    let options = JSObject()
    options.top = .number(amount)
    options.behavior = .string(smoothly && !prefersReducedMotion ? "smooth" : "auto")
    _ = body.scrollBy!(options)
  }

  private func render(_ page: Page?, columns: Int) {
    guard let page else {
      if shownPath != nil {
        shownPath = nil
        root.setHidden(true)
        body.removeChildren()
        media = []
        if !isTouchDevice { shell.focus() }
      }
      return
    }
    let isNewPage = shownPath != page.path
    shownPath = page.path
    title.textContent = .string(page.title)
    meta.textContent = .string(([page.date].compactMap { $0 } + page.tags.map { "#" + $0 }).joined(separator: "  "))
    var renderer = DocumentRenderer(router: router, art: darkroom.art, columns: min(columns, 76))
    let content = renderer.render(page.document)
    media = renderer.media
    let offset = body.scrollTop
    body.removeChildren()
    body.add(content)
    root.setHidden(false)
    if isNewPage {
      body.scrollTop = .number(0)
      _ = shell.input.blur!()
    } else {
      body.scrollTop = offset
    }
    updateStatus()
    develop(page)
  }

  /// Photos appear as links first, then turn into art as each one develops.
  private func develop(_ page: Page) {
    let sources = darkroom.claim(page.document.images)
    guard !sources.isEmpty else { return }
    Task { [self] in
      for src in sources {
        if await darkroom.develop(src), shownPath == page.path, let current = model.pager {
          render(current, columns: layout.columns)
        }
      }
    }
  }

  private func updateStatus() {
    let top = body.scrollTop.number ?? 0
    let range = (body.scrollHeight.number ?? 0) - (body.clientHeight.number ?? 0)
    let percent = range <= 1 ? 100 : Int(min(100, top / range * 100))
    status.textContent = .string(percent >= 100 ? "-- END --" : "-- MORE (\(percent)%) --")
  }
}

final class PopupView {
  let model: AppModel
  let root = byID("popup")
  let title = byID("popup-title")
  let body = byID("popup-body")

  init(model: AppModel) {
    self.model = model
    observe { [self] in render(model.popup) }
  }

  private func render(_ popup: Popup?) {
    body.removeChildren()
    root.setClass("is-video", false)
    root.setClass("is-audio", false)
    guard let popup else {
      root.setHidden(true)
      return
    }
    switch popup {
    case .image(let image):
      title.textContent = .string(image.alt.isEmpty ? "photo" : image.alt)
      let picture = element("img", "popup-image")
      picture.setAttr("src", image.src)
      picture.setAttr("alt", image.alt)
      body.add(picture)
    case .embed(let embed):
      title.textContent = .string(embed.title)
      root.setClass("is-video", embed.kind == .video)
      root.setClass("is-audio", embed.kind == .audio)
      let frame = element("iframe", "popup-frame")
      if embed.kind == .audio, let height = embed.height {
        let width = "min(\(embed.width ?? 560)px, calc(100vw - 54px))"
        frame.style.width = .string(width)
        // Bandcamp's big players are square artwork over a fixed-height footer, so they grow with the width.
        if let artwork = embed.width, height > artwork, !embed.src.contains("artwork=small") {
          frame.style.height = .string("calc(\(width) + \(height - artwork)px)")
        } else {
          frame.style.height = .string("\(height)px")
        }
      }
      frame.setAttr("src", embed.src)
      frame.setAttr("title", embed.title)
      frame.setAttr("allow", "autoplay; encrypted-media; picture-in-picture; fullscreen")
      frame.setAttr("referrerpolicy", "strict-origin-when-cross-origin")
      body.add(frame)
    }
    let foot = element("div", "popup-foot")
    let close = element("button", "popup-close", text: "[q] close")
    close.setAttr("type", "button")
    close.setAttr("data-action", "close-popup")
    foot.add(close)
    if case .embed(let embed) = popup {
      let open = element("a", "popup-link", text: "open in a new tab ↗")
      open.setAttr("href", embed.src)
      open.setAttr("target", "_blank")
      open.setAttr("rel", "noopener noreferrer")
      foot.add(open)
    }
    body.add(foot)
    root.setHidden(false)
  }
}

final class MenuView {
  let model: AppModel
  let shell: ShellView
  let panel = byID("menu")

  init(model: AppModel, shell: ShellView) {
    self.model = model
    self.shell = shell
    for item in MenuItem.allCases {
      panel.add(item.button(className: "menu-item", commandAttribute: "data-menu-command"))
    }
    observe { [self] in
      panel.setClass("is-open", model.isMenuOpen)
      moveFocus(isOpen: model.isMenuOpen)
    }
    observe { byID("sound-led").setClass("is-on", model.isSoundOn) }
  }

  /// Returns whether the menu consumed the key.
  func handleKey(_ key: String) -> Bool {
    guard model.isMenuOpen, !isTouchDevice, key == "ArrowDown" || key == "ArrowUp" else { return false }
    let items = panel.querySelectorAll!(".menu-item").object!
    let count = Int(items.length.number ?? 0)
    var index = -1
    for candidate in 0..<count where items[candidate] == document.activeElement {
      index = candidate
    }
    let next = key == "ArrowDown" ? (index + 1) % count : (index - 1 + count) % count
    _ = items[next].object?.focus!()
    return true
  }

  /// Keyboard users land in the menu when it opens, and back where they were when it closes.
  private func moveFocus(isOpen: Bool) {
    guard !isTouchDevice else { return }
    if isOpen {
      _ = panel.querySelector!(".menu-item").object?.focus!()
    } else if panel.contains!(document.activeElement).boolean == true {
      if model.pager != nil {
        _ = byID("pager-body").focus!()
      } else {
        shell.focus()
      }
    }
  }
}
