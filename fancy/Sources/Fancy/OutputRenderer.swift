import FancyCore
import JavaScriptKit

enum MenuItem: CaseIterable {
  case home, about, posts, code, music, now, help, sound, simple

  var label: String {
    switch self {
    case .home: "home"
    case .about: "about"
    case .posts: "posts"
    case .code: "code"
    case .music: "music"
    case .now: "now"
    case .help: "help"
    case .sound: "sound"
    case .simple: "simple mode"
    }
  }

  var command: String? {
    switch self {
    case .home: "cd ~"
    case .about: "open ~/about"
    case .posts: "cd ~/posts"
    case .code: "cd ~/code"
    case .music: "cd ~/music"
    case .now: "cd ~/now"
    case .help: "help"
    case .sound: "sound"
    case .simple: nil
    }
  }

  func button(className: String, commandAttribute: String) -> JSObject {
    let button = element("button", className, text: label)
    button.setAttr("type", "button")
    if let command {
      button.setAttr(commandAttribute, command)
    } else {
      button.setAttr("data-action", "leave")
    }
    return button
  }
}

struct OutputRenderer {
  let site: Site

  func render(_ entry: OutputEntry) -> JSObject {
    let node = render(entry.content)
    node.setAttr("data-id", String(entry.id))
    return node
  }

  private func render(_ content: OutputEntry.Content) -> JSObject {
    switch content {
    case .command(let cwd, let text):
      let line = element("div", "t-line t-cmd")
      line.add(element("span", "t-prompt", text: "guest@junebash:\(cwd)$ "))
      line.add(element("span", "", text: text))
      return line

    case .text(let text, let tone):
      return element("div", "t-line t-\(tone)", text: text)

    case .candidates(let names):
      let line = element("div", "t-line t-candidates")
      for (index, name) in names.enumerated() {
        if index > 0 { _ = line.append!("   ") }
        line.add(element("span", "t-candidate", text: name))
      }
      return line

    case .listing(let path, let entries, let order):
      return listing(path, entries, order: order)

    case .help(let commands):
      let block = element("div", "t-block t-help")
      block.add(element("div", "t-dim", text: "commands:"))
      for command in commands {
        let row = element("div", "t-row")
        let usage = element("span", "t-click t-usage", text: command.usage)
        usage.setAttr("data-command", command.name)
        row.add(usage)
        row.add(element("span", "t-dim", text: command.summary))
        block.add(row)
      }
      block.add(element("div", "t-dim t-tip", text: "you can also type a name to open it, press tab to finish a word, or click anything underlined."))
      return block

    case .menu:
      let block = element("div", "t-block t-inline-menu")
      for item in MenuItem.allCases {
        block.add(item.button(className: "t-chip", commandAttribute: "data-command"))
      }
      return block

    case .welcome:
      let block = element("div", "t-block t-welcome")
      block.add(element("pre", "t-spinner"))
      let text = element("div", "t-welcome-text")
      text.add(element("div", "t-bright", text: "BASHWORKS COMPUTER SYSTEMS"))
      text.add(element("div", "t-dim", text: "terminal 7"))
      text.add(element("div", "t-dim", text: "you have been here before"))
      let hint = element("div", "t-hint")
      _ = hint.append!("type ")
      let help = element("span", "t-click", text: "help")
      help.setAttr("data-command", "help")
      hint.add(help)
      _ = hint.append!(", or ")
      let menu = element("span", "t-click", text: "menu")
      menu.setAttr("data-command", "menu")
      hint.add(menu)
      _ = hint.append!(", or just click things.")
      text.add(hint)
      block.add(text)
      return block

    case .underConstruction(let path):
      let block = element("div", "t-block t-construction")
      block.add(element("pre", "t-sign", text: Self.sign))
      block.add(element("div", "", text: "\(path.display) isn't built yet. the walls are still wet."))
      let leave = element("span", "t-click", text: "see it in simple mode")
      leave.setAttr("data-action", "leave")
      let row = element("div", "t-hint")
      _ = row.append!("you can ")
      row.add(leave)
      _ = row.append!(", or try ")
      let back = element("span", "t-click", text: "cd ~")
      back.setAttr("data-command", "cd ~")
      row.add(back)
      _ = row.append!(".")
      block.add(row)
      return block
    }
  }

  private func listing(_ path: SitePath, _ entries: [Entry], order: Order?) -> JSObject {
    let block = element("div", "t-block t-listing")
    if let intro = site.directory(at: path)?.intro {
      block.add(element("div", "t-dim t-intro", text: intro))
    }
    var group: String?
    for entry in entries {
      if let heading = entry.group, heading != group {
        block.add(element("div", "t-group", text: "-- \(heading) --"))
      }
      group = entry.group
      let row = element("div", "t-row t-entry t-\(entry.kind)")
      row.setAttr("data-path", entry.path.urlPath)
      if let date = entry.date {
        row.add(element("span", "t-date", text: date))
      }
      if let title = entry.title {
        row.add(element("span", "t-click t-title", text: title.count > 64 ? title.prefix(63) + "…" : title))
        if let aside = entry.note ?? (entry.name == entry.date ? nil : entry.name) {
          row.add(element("span", "t-dim t-slug", text: aside))
        }
      } else {
        row.add(element("span", "t-click t-name", text: entry.kind == .document ? entry.name : entry.name + "/"))
        row.add(element("span", "t-dim", text: entry.kind == .unbuilt ? "under construction" : entry.note ?? ""))
      }
      block.add(row)
    }
    if let order {
      let hint = element("div", "t-dim t-hint")
      _ = hint.append!("\(order.newestFirst ? "newest" : "oldest") at the top. ")
      let flip = element("span", "t-click", text: order.flip)
      flip.setAttr("data-command", order.flip)
      hint.add(flip)
      _ = hint.append!(" flips it.")
      block.add(hint)
    }
    return block
  }

  static let sign = #"""
  ////////////////////////////////////////
  //  U N D E R   C O N S T R U C T I O N
  ////////////////////////////////////////
  """#
}
