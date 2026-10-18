import FancyCore
import JavaScriptKit

final class App {
  let router = Router()
  let synth = Synth()
  let boot = BootScreen()
  private var views: [AnyObject] = []

  func run() async {
    boot.systemImageLoaded()
    boot.line("SYSTEM IMAGE", status: "OK")
    await boot.beat(120)

    guard let site = await readContent() else {
      boot.fail("MEMORY CORRUPTED. PLEASE TRY THE SIMPLE SITE.")
      return
    }
    let darkroom = await developPhotographs(site)

    boot.line("CALIBRATING PHOSPHOR", status: "OK")
    await boot.beat(160)
    boot.line("LOOKING FOR YOU", status: "FOUND")
    await boot.beat(240)

    let isSoundOn = Preferences.get("sound") != "off"
    let model = AppModel(
      site: site,
      isSoundOn: isSoundOn,
      effects: AppModel.Effects(
        setLocation: { [router] in router.setLocation($0, push: $1) },
        play: { [synth] in synth.play($0) },
        leave: { [router] in router.leave(to: $0) },
        saveSound: { Preferences.set("sound", $0 ? "on" : "off") },
        pause: { await pause(milliseconds: prefersReducedMotion ? 0 : $0) },
        now: { window.performance.now().number ?? 0 }
      )
    )
    let layout = Layout()
    let shell = ShellView(model: model, layout: layout)
    let pager = PagerView(model: model, router: router, layout: layout, darkroom: darkroom, shell: shell)
    let menu = MenuView(model: model, shell: shell)
    let zen = ZenView(model: model)
    let piano = PianoView(model: model, synth: synth)
    views = [layout, shell, pager, PopupView(model: model), menu, zen, piano, CatView(model: model)]
    listen(model: model, shell: shell, pager: pager, menu: menu, layout: layout)
    listenOutsideTheShell(model: model, zen: zen, piano: piano)

    await boot.waitForGesture { [synth] in
      synth.unlock { if isSoundOn { synth.play(.boot) } }
      shell.reveal()
      byID("menu-button").setHidden(false)
    }
    layout.measure()
    model.started(at: router.currentPath)
  }

  /// The shell page carries every page as an inert `<template>`, so nothing in them loads until shown.
  private func readContent() async -> Site? {
    let list = document.querySelectorAll!("#fancy-site > template").object!
    let count = Int(list.length.number ?? 0)
    guard count > 0 else { return nil }
    let converter = HTMLConverter(isLocal: Router.isLocalAsset)
    let progress = boot.line("READING PAGES", status: "0/\(count)")
    var directories: [Directory] = []
    var pages: [Page] = []
    for index in 0..<count {
      let template = list[index].object!
      func attribute(_ name: String) -> String? {
        template.getAttribute!(name).string.flatMap { $0.isEmpty ? nil : $0 }
      }
      let content = DOMNode(template.content.object!)
      if let path = attribute("data-dir") {
        directories.append(
          Directory(
            path: SitePath(urlPath: path),
            note: attribute("data-note"),
            intro: attribute("data-intro"),
            aliases: (attribute("data-aliases") ?? "").split(separator: " ").map { SitePath(urlPath: String($0)) },
            items: Directory.items(in: content.childNodes)
          )
        )
      } else if let path = attribute("data-page").map(SitePath.init(urlPath:)) {
        pages.append(
          Page(
            path: path,
            home: attribute("data-home").map(SitePath.init(urlPath:)),
            title: attribute("data-title") ?? path.name,
            date: attribute("data-date").map { String($0.prefix(10)) },
            note: attribute("data-note"),
            tags: (attribute("data-tags") ?? "").split(separator: ",").map(String.init),
            document: converter.document(from: content)
          )
        )
      }
      if index % 9 == 8 {
        progress.update("\(index + 1)/\(count)")
        await pause(milliseconds: 0)
      }
    }
    progress.update("OK")
    return Site(directories: directories, pages: pages)
  }

  /// Only the photos a first visit is likely to see; the darkroom develops the rest when they're opened.
  private func developPhotographs(_ site: Site) async -> Darkroom {
    let darkroom = Darkroom()
    let pages = site.pages(under: SitePath(["about"])) + site.pages(under: SitePath(["posts"]))
    let sources = darkroom.claim(pages.flatMap(\.document.images))
    let progress = boot.line("DEVELOPING PHOTOS", status: "0/\(sources.count)")
    var developed = 0
    for (index, src) in sources.enumerated() {
      if await darkroom.develop(src) { developed += 1 }
      progress.update("\(index + 1)/\(sources.count)")
    }
    progress.update(developed == sources.count ? "OK" : "\(developed)/\(sources.count) OK")
    return darkroom
  }

  /// While sitting, playing, or stuck in emacs, the keyboard isn't the shell's.
  private func listenOutsideTheShell(model: AppModel, zen: ZenView, piano: PianoView) {
    document.listen("keydown", capture: true) { event in
      guard model.mode != .shell, event.metaKey.boolean != true else { return }
      switch model.mode {
      case .shell:
        return
      case .waiting:
        if event.ctrlKey.boolean == true, event.key.string == "c" { model.interruptPressed() }
      case .sitting:
        if zen.isSettled { model.stirred() }
      case .playing:
        piano.handleKey(event)
      }
      _ = event.preventDefault()
      _ = event.stopPropagation()
    }
    document.listen("pointerdown", capture: true) { _ in
      if model.mode == .sitting, zen.isSettled { model.stirred() }
    }

    for event in ["keydown", "pointerdown", "wheel"] {
      document.listen(event, passive: true, capture: true) { _ in model.userActed() }
    }
    Task {
      while true {
        await pause(milliseconds: 10_000)
        await model.clockTicked()
      }
    }
  }

  private func listen(model: AppModel, shell: ShellView, pager: PagerView, menu: MenuView, layout: Layout) {
    window.listen("popstate") { [router] _ in model.locationChanged(to: router.currentPath) }
    window.listen("resize", passive: true) { _ in layout.measure() }

    document.listen("pointerdown", passive: true) { [synth] _ in synth.unlock() }
    document.listen("keydown") { [synth] event in
      synth.unlock()
      let key = event.key.string ?? ""
      let isPlain = event.metaKey.boolean != true && event.ctrlKey.boolean != true && event.altKey.boolean != true
      let isTyping = event.target.object == shell.input
      let isCloseKey = key == "Escape" || (!isTyping && (key == "q" || key == "Q"))
      if isPlain, isCloseKey, model.popup != nil || model.isMenuOpen || model.pager != nil {
        model.closeKeyPressed()
        _ = event.preventDefault()
      } else if menu.handleKey(key) || pager.handleKey(event) {
        _ = event.preventDefault()
      } else if !isTyping, isPlain, key.count == 1, model.pager == nil {
        shell.focus()
      }
    }

    document.listen("click") { event in
      let target: JSValue = event.target
      if let node = target.closest(matching: "[data-action]") {
        switch node.getAttribute!("data-action").string {
        case "menu": model.menuButtonTapped()
        case "close-pager": model.pagerDismissed()
        case "close-popup": model.popupDismissed()
        case "close-piano": model.closeKeyPressed()
        case "leave": model.leaveTapped()
        default: break
        }
      } else if let command = target.closest(matching: "[data-menu-command]")?.getAttribute!("data-menu-command").string {
        Task { await model.menuItemTapped(command) }
      } else if let command = target.closest(matching: "[data-command]")?.getAttribute!("data-command").string {
        Task { await model.commandClicked(command) }
      } else if let path = target.closest(matching: "[data-path]")?.getAttribute!("data-path").string {
        Task { await model.entryClicked(SitePath(urlPath: path)) }
      } else if let index = target.closest(matching: "[data-media]")?.getAttribute!("data-media").string.flatMap(Int.init) {
        pager.mediaClicked(index)
      } else if let path = target.closest(matching: "a[data-internal]")?.getAttribute!("data-internal").string {
        _ = event.preventDefault()
        model.linkClicked(SitePath(urlPath: path))
      } else if target.object?.id.string == "popup" {
        model.popupDismissed()
      } else if model.pager == nil, !isTouchDevice, target.closest(matching: "a") == nil,
        window.getSelection!().toString().string?.isEmpty != false
      {
        shell.focus()
      }
    }
  }
}

struct DOMNode: HTMLNode {
  let object: JSObject

  init(_ object: JSObject) {
    self.object = object
  }

  var tagName: String? {
    object.nodeType.number == 1 ? object.tagName.string?.lowercased() : nil
  }

  var textContent: String {
    object.textContent.string ?? ""
  }

  var childNodes: [DOMNode] {
    let list = object.childNodes.object!
    let count = Int(list.length.number ?? 0)
    // Comments (older Zola leaves <!-- more --> in) and the like have nothing to show.
    return (0..<count).compactMap { list[$0].object }
      .filter { [1, 3].contains($0.nodeType.number) }
      .map(DOMNode.init)
  }

  func attribute(_ name: String) -> String? {
    guard object.nodeType.number == 1 else { return nil }
    return object.getAttribute!(name).string
  }
}
