import FancyCore
import JavaScriptKit

final class PagerView {
  let model: AppModel
  let router: Router
  let layout: Layout
  let art: [String: AsciiArt]
  let shell: ShellView
  let root = byID("pager")
  let title = byID("pager-title")
  let meta = byID("pager-meta")
  let body = byID("pager-body")
  let status = byID("pager-status")
  private var media: [Popup] = []
  private var shownPath: SitePath?

  init(model: AppModel, router: Router, layout: Layout, art: [String: AsciiArt], shell: ShellView) {
    self.model = model
    self.router = router
    self.layout = layout
    self.art = art
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

  /// Returns whether the pager consumed the key.
  func handleKey(_ key: String) -> Bool {
    guard model.pager != nil, model.popup == nil else { return false }
    let line = 24.0
    let page = max(line, (body.clientHeight.number ?? 400) - line * 2)
    switch key {
    case "q", "Q", "Escape", "Backspace", "ArrowLeft": model.pagerDismissed()
    case "ArrowDown", "j": scroll(by: line * 2)
    case "ArrowUp", "k": scroll(by: -line * 2)
    case " ", "PageDown", "f": scroll(by: page)
    case "PageUp", "b": scroll(by: -page)
    case "g", "Home": body.scrollTop = .number(0)
    case "G", "End": body.scrollTop = body.scrollHeight
    default: return false
    }
    return true
  }

  private func scroll(by amount: Double) {
    let options = JSObject()
    options.top = .number(amount)
    options.behavior = .string(prefersReducedMotion ? "auto" : "smooth")
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
    var renderer = DocumentRenderer(router: router, art: art, columns: min(columns, 76))
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
      frame.setAttr("src", embed.src)
      frame.setAttr("title", embed.title)
      frame.setAttr("allow", "autoplay; encrypted-media; picture-in-picture; fullscreen")
      frame.setAttr("referrerpolicy", "strict-origin-when-cross-origin")
      body.add(frame)
      let open = element("a", "popup-link", text: "open in a new tab ↗")
      open.setAttr("href", embed.src)
      open.setAttr("target", "_blank")
      open.setAttr("rel", "noopener noreferrer")
      body.add(open)
    }
    root.setHidden(false)
  }
}

final class MenuView {
  let model: AppModel
  let panel = byID("menu")

  init(model: AppModel) {
    self.model = model
    for item in MenuItem.allCases {
      panel.add(item.button(className: "menu-item", commandAttribute: "data-menu-command"))
    }
    observe { [self] in panel.setClass("is-open", model.isMenuOpen) }
    observe { byID("sound-led").setClass("is-on", model.isSoundOn) }
  }
}
