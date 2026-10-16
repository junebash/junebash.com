extension Page {
  public static func about(_ about: SiteData.About, path: SitePath, bio: Document, skills: Document) -> Page {
    var blocks: [Block] = [.image(Image(src: about.portrait, alt: "Portrait of June Bash", isLocal: true))]
    blocks += about.facts.map { fact in
      .paragraph([Span(fact.label.uppercased() + "  ", style: .dim), Span(fact.value, style: .bold)])
    }
    blocks += bio.blocks
    blocks.append(.heading(level: 2, [Span("What I work with")]))
    blocks += skills.blocks
    blocks.append(.heading(level: 2, [Span("Elsewhere")]))
    blocks.append(
      .list(
        ordered: false,
        items: about.socials.map { [.paragraph([Span($0.name, link: $0.url)])] }
      )
    )
    return Page(path: path, title: about.title, document: Document(blocks: blocks))
  }
}
