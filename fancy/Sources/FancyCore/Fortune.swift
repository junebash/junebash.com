/// Lines lifted word for word from the posts. Don't tidy them: they're quotes.
public struct Fortune: Equatable, Sendable {
  public let text: String
  public let source: SitePath

  init(_ text: String, from post: String) {
    self.text = text
    source = SitePath(["posts", post])
  }

  public static let all = [
    Fortune("Music is only what you make of it.", from: "music-is-meaningless"),
    Fortune("There is no such thing as sad music.", from: "music-is-meaningless"),
    Fortune("To realize that music itself does not have any meaning is freedom.", from: "music-is-meaningless"),
    Fortune("Metal doesn’t have to be satanic.", from: "music-is-meaningless"),
    Fortune("Maybe your song doesn’t need a chorus.", from: "mindful-composition"),
    Fortune("Art and capitalism have a very dubious relationship.", from: "on-art-commercialism-and-elitism"),
    Fortune("Making a machine do all the labor completely defeats the purpose.", from: "maybe-ai-can-be-good-sometimes"),
    Fortune("Not every gadget in my house has to be artisanally hand-assembled by a human being.", from: "maybe-ai-can-be-good-sometimes"),
    Fortune("That exclamation point makes me nervous, but sometimes it's necessary.", from: "non-generic-init"),
    Fortune("The previous version was using a sledgehammer where a regular hammer would suffice.", from: "combine-intro"),
    Fortune("Sometimes this lesson is best learned the hard way.", from: "lessons-from-labs"),
    Fortune("Don't wait to feel motivated.", from: "dont-wait-for-inspiration"),
    Fortune("Consume less, create more.", from: "dont-wait-for-inspiration"),
    Fortune("No more excuses.", from: "dont-wait-for-inspiration"),
    Fortune("Spoiler alert: it never worked.", from: "habitual-composition-commit-to-writing-one-measure-of-music-every-day"),
    Fortune("Even on your worst day, the stupid-small version is easy to get done.", from: "habitual-composition-commit-to-writing-one-measure-of-music-every-day"),
    Fortune("Nothing is permanent.", from: "why-do-you-meditate"),
    Fortune("Nothing ever satisfies us.", from: "why-do-you-meditate"),
    Fortune("Everything in our experience is always changing.", from: "why-do-you-meditate"),
    Fortune("Are you an accumulation of your experiences?", from: "why-do-you-meditate"),
    Fortune("You're here now; you're only alive in this moment.", from: "whats-going-on"),
    Fortune("Compassion is the only rational mode of interaction with others.", from: "universal-system"),
    Fortune("How did you fail today?", from: "how-did-you-fail-today"),
    Fortune("Reading and listening to those we don’t think we like can only make us better people.", from: "listen-to-people-you-dont-like"),
    Fortune("Humans did not evolve in a world of eight billion people.", from: "you-cannot-change-the-world"),
    Fortune("We can just be us, do our work, and watch what happens.", from: "getting-over-self-esteem"),
    Fortune("Let's build each other up rather than keeping ourselves and each other down.", from: "mental-health-shame"),
    Fortune("But everyone gets their turn at the wheel of the struggle bus.", from: "mental-health-shame"),
    Fortune("By pushing any one person down, you push the whole world down.", from: "insults"),
    Fortune("So pay me for my work, please, and do the same for others.", from: "free-work"),
    Fortune("Do you think it’s the Bestest Game Ever Like Oh My God?", from: "what-makes-undertale-so-wonderful"),
    Fortune("This is probably just high grade copium.", from: "predictions"),
    Fortune("A single coal left of the campfire of the universe.", from: "the-very-last-light"),
    Fortune("Not for lack of want; more for lack of followthrough.", from: "hello"),
  ]
}
