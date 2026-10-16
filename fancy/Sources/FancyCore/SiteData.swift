public struct SiteData: Decodable, Sendable {
  public var sections: [Section]
  public var about: About
  public var posts: [Post]

  public struct Section: Decodable, Sendable {
    public var name: String
    public var path: String
  }

  public struct About: Decodable, Sendable {
    public var title: String
    public var facts: [Fact]
    public var portrait: String
    public var socials: [Social]
    public var bioHTML: String
    public var skillsHTML: String
  }

  public struct Fact: Decodable, Sendable {
    public var label: String
    public var value: String
  }

  public struct Social: Decodable, Sendable {
    public var name: String
    public var url: String
  }

  public struct Post: Decodable, Sendable {
    public var title: String
    public var path: String
    public var date: String
    public var tags: [String]
    public var html: String
  }
}
