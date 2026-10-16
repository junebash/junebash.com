import FancyCore
import JavaScriptKit

final class App {
  let router = Router()
  let synth = Synth()
  let boot = BootScreen()
  private var views: [AnyObject] = []

  func run() async {
    boot.systemImageLoaded()
    boot.line("SYSTEM IMAGE ........", status: "OK")
    await boot.beat(120)

    let data: SiteData
    do {
      let text = byID("fancy-data").textContent.string ?? ""
      data = try JSValueDecoder().decode(SiteData.self, from: window.JSON.object!.parse!(text))
    } catch {
      boot.fail("MEMORY CORRUPTED. PLEASE TRY THE SIMPLE SITE.")
      return
    }

    let site = await readContent(data)
    let art = await developPhotographs(site)

    boot.line("CALIBRATING PHOSPHOR ", status: "OK")
    await boot.beat(160)
    boot.line("LOOKING FOR YOU ......", status: "FOUND")
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
        pause: { await pause(milliseconds: prefersReducedMotion ? 0 : $0) }
      )
    )
    let layout = Layout()
    let shell = ShellView(model: model, layout: layout)
    let pager = PagerView(model: model, router: router, layout: layout, art: art, shell: shell)
    views = [layout, shell, pager, PopupView(model: model), MenuView(model: model)]
    listen(model: model, shell: shell, pager: pager, layout: layout)

    await boot.waitForGesture { [synth] in
      synth.unlock { if isSoundOn { synth.play(.boot) } }
      shell.reveal()
      byID("menu-button").setHidden(false)
    }
    layout.measure()
    model.started(at: router.currentPath)
  }

  private func readContent(_ data: SiteData) async -> Site {
    let parser = window.DOMParser.function!.new()
    let converter = HTMLConverter(isLocal: Router.isLocalAsset)
    func convert(_ html: String) -> Document {
      let parsed = parser.parseFromString!(html, "text/html").object!
      return converter.document(from: DOMNode(parsed.body.object!))
    }

    let entities = element("textarea")
    func decodeEntities(_ text: String) -> String {
      guard text.contains("&") else { return text }
      entities.innerHTML = .string(text)
      return entities.value.string ?? text
    }

    let progress = boot.line("READING POSTS .......", status: "0/\(data.posts.count)")
    var posts: [Page] = []
    for (index, post) in data.posts.enumerated() {
      posts.append(
        Page(
          path: SitePath(urlPath: post.path),
          title: decodeEntities(post.title),
          date: String(post.date.prefix(10)),
          tags: post.tags,
          document: convert(post.html)
        )
      )
      if index % 9 == 8 {
        progress.update("\(index + 1)/\(data.posts.count)")
        await pause(milliseconds: 0)
      }
    }
    progress.update("OK")
    let about = Page.about(
      data.about,
      path: SitePath(["about"]),
      bio: convert(data.about.bioHTML),
      skills: convert(data.about.skillsHTML)
    )
    return Site(sections: data.sections, about: about, posts: posts)
  }

  private func developPhotographs(_ site: Site) async -> [String: AsciiArt] {
    var sources: [String] = []
    for page in [site.node(at: SitePath(["about"]))].compactMap({ if case .document(let page) = $0 { page } else { nil } }) + site.posts {
      for image in page.document.images where image.isLocal && !sources.contains(image.src) {
        sources.append(image.src)
      }
    }
    let progress = boot.line("DEVELOPING PHOTOS ...", status: "0/\(sources.count)")
    var art: [String: AsciiArt] = [:]
    for (index, src) in sources.enumerated() {
      art[src] = await ArtLoader.load(src)
      progress.update("\(index + 1)/\(sources.count)")
    }
    progress.update(art.count == sources.count ? "OK" : "\(art.count)/\(sources.count) OK")
    return art
  }

  private func listen(model: AppModel, shell: ShellView, pager: PagerView, layout: Layout) {
    window.listen("popstate") { [router] _ in model.locationChanged(to: router.currentPath) }
    window.listen("resize", passive: true) { _ in layout.measure() }

    document.listen("pointerdown", passive: true) { [synth] _ in synth.unlock() }
    document.listen("keydown") { [synth] event in
      synth.unlock()
      let key = event.key.string ?? ""
      if model.popup != nil, key == "Escape" {
        model.escapePressed()
        _ = event.preventDefault()
      } else if pager.handleKey(key) {
        _ = event.preventDefault()
      } else if event.target.object != shell.input, key.count == 1, event.metaKey.boolean != true,
        event.ctrlKey.boolean != true, event.altKey.boolean != true, model.pager == nil
      {
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
    switch object.nodeType.number {
    case 1: object.tagName.string?.lowercased()
    case 3: nil
    default: "#other"
    }
  }

  var textContent: String {
    object.textContent.string ?? ""
  }

  var childNodes: [DOMNode] {
    let list = object.childNodes.object!
    let count = Int(list.length.number ?? 0)
    return (0..<count).compactMap { list[$0].object.map(DOMNode.init) }
  }

  func attribute(_ name: String) -> String? {
    object.getAttribute!(name).string
  }
}
