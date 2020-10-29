---
title: Functional, Composable Swift Styles With UIKit (and Beyond)
date: 2020-10-27 05:12
categories:
  - Code
---

_(Note: This post uses Swift 5.3 and the iOS 14 SDK)_

SwiftUI is the hot new kid on the block in iOS Development, but as most developers know, UIKit isn't going anywhere anytime soon (and indeed, a decent chunk of SwiftUI utilizes it under the hood). Despite this, there's still a lot of aspects of UI programming that can be pretty obnoxious with UIKit. However, there are some interesting ways that we can make it a little bit more usable by taking some nods from a more functional programming style. <!--more-->

A while back, John Sundell wrote [a great article about writing small utility functions](https://www.swiftbysundell.com/articles/writing-small-utility-functions-in-swift/), and ever since I've been using his `configure` blocks all throughout my code (much to the initial-chagrin-and-later-delight of my teammates):

```swift
@discardableResult
func configure<T>(_ item: T, with transform: (inout T) -> Void) -> T {
    var result = item
    transform(&result)
    return result
}
```

(I've marked this as `@discardableResult` for the cases where a class is passed in; in that case, we don't need to get anything out, since the value pointed to by the reference parameter we passed in will have been mutated.)

This doesn't look like it does much at first, but read John's article and you'll get an idea of its power.

That alone can be really helpful in many ways, but it might not cut down on the carpal tunnel caused by typing `translatesAutoresizingMaskIntoConstraints` one too many times (okay, you can probably get away with typing `tamic` and letting the code completion fill in the rest, but you'll still have a decent bit of duplication). It would be nice if we could _compose_ these styles together.

It just so happens that PointFree has an [excellent (and free!) video on this topic](https://www.pointfree.co/episodes/ep3-uikit-styling-with-functions). In that video, they demonstrate how, using closures and a simple custom operator, you can vastly cut down on the amount of duplication in a codebase and write code that's very reusable and composable.

```swift
infix operator <>

func <> <A>(
  f: @escaping (A) -> A,
  g: @escaping (A) -> A
) -> (A) -> A {
  return g(f(a))
}
func <> <A>(
  f: @escaping (inout A) -> Void,
  g: @escaping (inout A) -> Void
) -> (inout A) -> Void {
  return { a in
    f(&a)
    g(&a)
  }
}
func <> <A: AnyObject>(
  f: @escaping (A) -> Void,
  g: @escaping (A) -> Void
) -> (A) -> Void {
  return { a in
    f(a)
    g(a)
  }
}

func baseButtonStyle(_ button: UIButton) {
  button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
  button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
}
let filledButtonStyle =
  baseButtonStyle
    <> {
      $0.backgroundColor = .black
      $0.tintColor = .white
}
let roundedButtonStyle =
  baseButtonStyle
    <> {
      $0.clipsToBounds = true
      $0.layer.cornerRadius = 6
}
let filledButtonStyle =
  roundedButtonStyle
    <> {
      $0.backgroundColor = .black
      $0.tintColor = .white
}
```

I'd highly recommend watching the video to get an idea of what's happening here, but the main idea is that _styles_ are really just _functions_ (or closures) that take something in and spit it back out with some changes applied. Taking this as a starting point, we can then _compose_ (or combine, or chain) these styling functions using this custom operator.

As a brief aside, I've heard a lot of pushback on the use of custom operators; folks say that it makes code harder to read, it takes folks longer to figure out what's going on in a project, etc. But I would argue that this is true of any reasonably-sized codebase. Anytime you get started with a project, there will be new functions to learn, custom types and methods, ways of doing things. If you can get past the fact that it's a symbol instead of a word, an operator is just a function that you would have to look up the meaning of, just like any regular function or type or variable in a codebase.

Anyways... this is all great, but where are we going to keep these styles? If they're global, our global namespace is going to get pretty cluttered. Even putting them on their base types might get a little obnoxious.

We could make an empty enum as a namespace:

```swift
enum Style {
  static func baseButton(_ button: UIButton) {
    button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
  }
}
```

...But that could also get pretty cluttered. So how about making it generic?

```swift
enum Style<T> {}

extension Style where T: UIButton {
  func baseButton(_ button: UIButton) {
    button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
  }
  //...
}
```

Cool, that can help keep our codebase more organized; everything in its right place.

...But one of my favorite things about having static factory methods like that is the ability to call `.whateverStaticProperty` or `.whateverStaticFunc()`. In the above cases, we can never actually instantiate an instance of `Style`; it's purely a namespace only. And it would get pretty annoying to have to call `Style<UIButton>.whatever` all the time. And of course, we can't make an extension on a function signature; I can't call `((inout T) -> Void).staticProperty`; it doesn't make any sense!

So, let's make a wrapper type for our functions. And really this goes far beyond just styling views, so let's give it a better name as well.

```swift
struct Mod<T> {
  var apply: (inout T) -> Void
}
```

You may not realize it yet, but this just opens up so many possibilities.

Let's write an overload on that `configure` method from the start of the article.

```swift
@discardableResult
func configure<T>(_ item: T, with mod: Mod<T>) -> T {
	var result = item
	mod(&result)
	return result
}
```

And if we wanted to make our configuration calls even quicker, we could define another custom operator for performing configurations.

```swift
precedencegroup FunctionalPipePrecedence {
	associativity: left
	lowerThan: AdditionPrecedence
}

infix operator |>: FunctionalPipePrecedence

@discardableResult
func |> <T>(item: T, mod: Mod<T>) -> T {
	configure(item, with: mod)
}
```

(Don't worry too much about the `precedencegroup` business for now; maybe for another post...)

We can also bring back the custom operator we used earlier, or even, if we like, just use an addition operator.

```swift
extension Mod {
	static func + (lhs: Mod, rhs: Mod) -> Mod {
		Mod {
			lhs(&$0)
			rhs(&$0)
		}
	}
}
```

This creates a new `Mod` whose wrapped function performs the left operation and then the right operation. We've got quite the ergonomic composability! So we can do stuff like this now...!

```swift
typealias LabelStyle = Mod<UILabel>

extension LabelStyle {
	static let dynamicFont = LabelStyle { $0.adjustsFontForContentSizeCategory = true }
	static let centered = LabelStyle { $0.textAlignment = .center }
	static let centerTitle = dynamicFont(.title1) + centered
	static let multiline = LabelStyle { $0.numberOfLines = 0 }

	static func textStyle(_ style: UIFont.TextStyle) -> LabelStyle {
		LabelStyle { $0.font = .preferredFont(forTextStyle: style) }
	}

	static func dynamicFont(_ style: UIFont.TextStyle) -> LabelStyle {
		dynamicFont + textStyle(style)
	}

	static func text(_ newText: String?) -> LabelStyle {
		LabelStyle { $0.text = newText }
	}

	static func alignment(_ alignment: NSTextAlignment) -> LabelStyle {
		LabelStyle { $0.textAlignment = alignment }
	}

	static func caption(_ text: String) -> LabelStyle {
		.text(text.uppercased()) + .dynamicFont(.caption1)
	}
}

extension Mod where T == DateFormatter {
	static let shortDate = Mod { $0.dateStyle = .short }
	static let noTime = Mod { $0.timeStyle = .none }
	static let episodeDatestamp = shortDate + noTime
}

class ViewController: UIViewController {
	static let dateFormatter = DateFormatter() |> .episodeDatestamp

	let episodeTitle = UILabel()
		|> .text("Building a Layout Library")
		+ .centerTitle
		+ .multiline
	let episodeNumber = UILabel()
		|> .text("123")
		+ .dynamicFont(.body)
	let episodeViews = UILabel()
		|> .text("1000")
		+ .dynamicFont(.body)
	let episodeDate = UILabel()
		|> .text(Date() |> dateFormatter.string(from:))
		+ .dynamicFont(.body)

	let episodeNumberTitle = UILabel() |> .caption("Episode #")
	let episodeViewsTitle = UILabel() |> .caption("Views")
	let episodeDateTitle = UILabel() |> .caption("Release Date")

  //...
}
```

Think about how much more typing we would need to do if we didn't have these, and how much cleaner our configuration code is with it. I think this is quite powerful, quite readable, and makes our jobs as programmers easier. What more could we ask for?
