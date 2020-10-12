---
title: An Alternative Type-Erasure with Swift Using Closures
date: 2020-10-14 07:59
categories:
  - Code
---

_(Note: This post uses Swift 5.3 and the iOS 14 SDK)_

In [a recent post](/blog/type-erasure), I described a method of type-erasure in Swift using a complicated, verbose system that took advantage of generics, private wrapper types, and subclassing. It turns out, however, that there's a much quicker, Swiftier, and arguably simpler way to accomplish this that uses closures. <!--more-->

## Some Notes on Closures

Closures in Swift are essentially functions, but they can behave in potentially surprising ways.

Let's start with a simple example.

```swift
var number = 42

let provideNumber: () -> Int = {
	return number / 2
}

provideNumber() // 21
```

This seems pretty normal and expected. We wrote this closure expression that simply returns `number` (set to 42) divided by 2, and it returns 21. Now what if we write a struct that takes in a closure?

```swift
struct NumberProvider {
	let get: () -> Int

	init(_ get: @escaping () -> Int) {
		self.get = get
	}
}

let numProvider = NumberProvider(provideNumber)
numProvider.get() // 21
```

Again, this all seems as expected. `NumberProvider` takes an `@escaping` closure (since the closure needs to last after the scope of the initializer; i.e., it needs to _escape_ the expected scope), and when we call that we still get the same number. But what if we now change the value of `number`?

```swift
number = 84
numProvider.get() // 42?!
```

This might not seem so surprising until you recall that `Int` is a value type, and value types are supposed to be copied when you pass them around. The closure we passed in, though, is referring explicitly to the original variable. Is that what we want?

Well, the good news is we can explicitly capture the variable.

```swift
var newNumber = 42
let newNumProvider = NumberProvider { [number] in number / 2 }
newNumber = 84
newNumProvider.get() // still 21!
```

If you've dealt with retain cycles, you've probably worked with capture lists by capturing `[weak self]` in a closure. But you can capture other values and references as well, which is what we've done here. By explicitly capturing `number`, we've essentially copied the value to a new variable, so we're no longer referring to the original copy. Therefore, we can now change the original number and not affect the one in the closure (which may or may not be what we want).

## Type Erasure With Closures

Now back to the really fun stuff.

Let's use the same protocol we did last time for simplicity's sake, and some really simple implementations of it.

```swift
protocol Query: Encodable {
	associatedtype Output: Decodable

	var queryString: String { get }
}

struct GetPersonWithID: Query {
	typealias Output = Person

	let id: UUID
	let queryString: String

	init(id: UUID) {
		self.id = id
		self.queryString = "get person with id \(id)"
	}
}

struct GetPersonWithName: Query {
	typealias Output = Person

	let name: String
	let queryString: String

	init(name: String) {
		self.name = name
		self.queryString = "get person with name \(name)"
	}
}
```

Recall that our purpose with type erasure is to have a solid implementation of `Query` that can wrap, erase, and group any other implementation of the protocol that has the same `Output` type, so we can do stuff like this:

```swift
let queries: [AnyQuery<Person>] = [
	AnyQuery(GetPersonWithID(id: UUID())),
	AnyQuery(GetPersonWithName(name: "Jon Bash")),
	AnyQuery(GetPersonWithID(id: UUID()))
]
```

Last time we had to have a wrapper type, a base type, and a box type that inherited from the base. Here, however, we can get away with just a single struct.

```swift
struct AnyQuery<Output: Decodable>: Query {
	let queryString: String

	private var _encode: (Encoder) throws -> Void

	init<Q: Query>(_ query: Q) where Q.Output == Output {
		self.queryString = query.queryString
		self._encode = query.encode
	}

	func encode(to encoder: Encoder) throws {
		try _encode(encoder)
	}
}
```

The most interesting bit here is the `encode` method. Remember I said closures are essentially functions? Well, that's so essential that we can pass in a function as the closure here. Pretty cool!

And we don't have to explicitly capture anything; our initializer essentially does that work for us when the query is passed into the `init` function. It's an immutable copy of whatever's passed in. (This will be important in a bit.)

Another mostly-unrelated cool thing we can do is actually sort of keep track of the type that we're wrapping.

```swift
struct AnyQuery<Output: Decodable>: Query {
	let queryString: String

    let wrappedType: Any.Type

	private var _encode: (Encoder) throws -> Void

	init<Q: Query>(_ query: Q) where Q.Output == Output {
		self.queryString = query.queryString
		self._encode = query.encode
        self.wrappedType = Q.self
	}

	func encode(to encoder: Encoder) throws {
		try _encode(encoder)
	}
}
```

Having that `wrappedType` there may or may not be useful (maybe it would be used for a cell identifier somewhere or something?), but it's certainly interesting!

There's still one potential problem with this, but we'll have to loop back around to it...

## Mutable Properties

What if we had a mutable property on a protocol? Things get a tiny bit more complicated there.

Let's say, for some bizarre reason, our `Query` protocol allowed mutating the `queryString` (I don't think I would ever recommend this, but it's the simplest example I can think of for now).

```swift
protocol Query: Encodable {
	associatedtype Output: Decodable

	var queryString: String { get set }
}


struct GetPersonWithID: Query {
	typealias Output = Person

	let id: UUID
	var queryString: String

	init(id: UUID) {
		self.id = id
		self.queryString = "get person with id \(id)"
	}
}

struct GetPersonWithName: Query {
	typealias Output = Person

	let name: String
	var queryString: String

	init(name: String) {
		self.name = name
		self.queryString = "get person with name \(name)"
	}
}
```

Our `AnyQuery` wrapper has to adjust a bit. We might be tempted to start off with the following.

```swift
struct AnyQuery<Output: Decodable>: Query {
	var queryString: String

	private var _encode: (Encoder) throws -> Void

	init<Q: Query>(_ query: Q) where Q.Output == Output {
		self.queryString = query.queryString
		self._encode = query.encode
	}

	func encode(to encoder: Encoder) throws {
		try _encode(encoder)
	}
}
```

There's a major problem here, though. If our wrapped query's `encode` method relies on the value of `queryString`, it has no way to access it, since it would be referring to the original `query.queryString` rather than our newly mutated queryString. So we've got a bit more work to do.

```swift
struct AnyQuery<Output: Decodable>: Query2 {
	var queryString: String {
		get { _getQueryString() }
		set { _setQueryString(newValue) }
	}

	private var _getQueryString: () -> String
	private var _setQueryString: (String) -> Void
	private var _encode: (Encoder) throws -> Void

	init<Q: Query>(_ query: Q) where Q.Output == Output {
		var copy = query
		self._getQueryString = { copy.queryString }
		self._setQueryString = { copy.queryString = $0 }
		self._encode = copy.encode
	}

	func encode(to encoder: Encoder) throws {
		try _encode(encoder)
	}
}
```

We've done two important things here:

1. `queryString` now has a separate getter and setter.
2. We make a mutable copy of `query` so that we can mutate it within those closures.

Remember earlier with the `NumberProvider` closure and how it kept referring back to the original method? By initializing `var copy` and using that within these closures, we're keeping that `copy` alive and continuing to refer to it. Let's test this:

```swift
var anyquery2 = AnyQuery2(GetPersonWithName2(name: "Jon"))
print(anyquery2.queryString) // "get person with name Jon"
anyquery2.queryString = "HI THERE"
print(anyquery2.queryString) // "HI THERE"
```

It works!

...But there's one more danger still lurking, which I alluded to before. Let's make it easier to see by adding a method to our `Query` protocol (along with a default conformance to make things easier on ourselves) and modify our type-erased wrapper.

```swift
protocol Query: Encodable {
	associatedtype Output: Decodable

	var queryString: String { get set }
	func speak()
}

extension Query {
	func speak() {
		print("Self: \(Self.self)\nOutput: \(Output.self)\nqueryString: \(queryString)")
	}
}

struct AnyQuery<Output: Decodable>: Query {
	var queryString: String {
		get { _getQueryString() }
		set { _setQueryString(newValue) }
	}

	private var _getQueryString: () -> String
	private var _setQueryString: (String) -> Void
	private var _encode: (Encoder) throws -> Void
	private var _speak: () -> Void

	init<Q: Query>(_ query: Q) where Q.Output == Output {
		var copy = query
		self._getQueryString = { copy.queryString }
		self._setQueryString = { copy.queryString = $0 }
		self._encode = copy.encode
		self._speak = copy.speak
	}

	func encode(to encoder: Encoder) throws {
		try _encode(encoder)
	}

	func speak() {
		_speak()
	}
}
```

Now let's test it really quick. If it's working as expected, when we mutate the query string, it should be reflected when we call `speak()`.

```swift
var anyquery = AnyQuery(GetPersonWithName2(name: "Jon"))
anyquery.speak()
    // Self: GetPersonWithName
    // Output: Person
    // queryString: get person with name Jon

anyquery.queryString = "HI THERE"
anyquery.speak()
    // Self: GetPersonWithName
    // Output: Person
    // queryString: get person with name Jon
```

Uh oh. The `speak()` method isn't reflecting the mutations we make as we expect. How do we fix this?

Recall that by using `copy` within a closure, we hang on to a "reference" to the original. However, by assigning `copy.speak` to `self._speak`, we are essentially making _another_ copy of copy, and assigning _that_ copy's `speak` method to `self._speak`, so it never gets the mutations we assign in the query string setter. So instead of directly assigning the method to the closure like I was so excited to do, we'll have to wrap that method call in another closure to keep a reference to the copy.

```swift
struct AnyQuery<Output: Decodable>: Query {
	var queryString: String {
		get { _getQueryString() }
		set { _setQueryString(newValue) }
	}

	private var _getQueryString: () -> String
	private var _setQueryString: (String) -> Void
	private var _encode: (Encoder) throws -> Void
	private var _speak: () -> Void

	init<Q: Query>(_ query: Q) where Q.Output == Output {
		var copy = query
		self._getQueryString = { copy.queryString }
		self._setQueryString = { copy.queryString = $0 }
		self._encode = { try copy.encode(to: $0) }
		self._speak = { copy.speak() }
	}

	func encode(to encoder: Encoder) throws {
		try _encode(encoder)
	}

	func speak() {
		_speak()
	}
}

var anyquery = AnyQuery(GetPersonWithName(name: "Jon"))
anyquery.speak()

anyquery.queryString = "HI THERE"
anyquery.speak()
```

_Now_ the `speak` method correctly reflects our mutations. Huzzah!

## Conclusions

Like I mentioned last time, type erasure isn't always the best solution to this problem, but there are certainly times when it might come in handy, and as long as we remember to test our type erasure thoroughly and remember the idiosyncracies of Swift's closures, this method will likely be quicker to pull off than the base-box-subclass-wrapper dance. And similarly to last time, even if we never use this, hopefully we've learned quite a bit about how closures work in Swift!
