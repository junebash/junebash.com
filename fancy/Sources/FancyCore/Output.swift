public struct OutputEntry: Identifiable, Equatable, Sendable {
  public let id: Int
  public let content: Content

  public enum Content: Equatable, Sendable {
    case command(cwd: SitePath, text: String)
    case text(String, tone: Tone = .normal)
    case listing(SitePath, [Entry], order: Order? = nil)
    case candidates([String])
    case help([CommandInfo])
    case menu
    case welcome
    case underConstruction(SitePath)
  }

  public enum Tone: Equatable, Sendable {
    case normal
    case dim
    case bright
    case error
  }
}

/// How a dated listing is sorted, and the command that shows it the other way round.
public struct Order: Equatable, Sendable {
  public let newestFirst: Bool
  public let flip: String
}

public struct CommandInfo: Equatable, Sendable {
  public let name: String
  public let usage: String
  public let summary: String
}

public enum SoundEffect: Equatable, Sendable {
  case key
  case enter
  case error
  case open
  case close
  case blip
  case popup
  case boot
}

public enum Popup: Equatable, Sendable {
  case image(Image)
  case embed(Embed)
}
