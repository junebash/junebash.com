---
title: A Crash Course in Swift Combine
date: 2020-10-05 17:03
categories:
  - Code
---

_(Note: This post uses Swift 5.3 and the iOS 14 SDK)_

Combine is Apple's new-ish framework for **functional reactive programming**, a coding paradigm that specializes in working with asynchronous streams of values in a "declarative" style. That's a lot of buzzwords that may not make a lot of sense until you see it in action. So let's take a look at how we can use it to write more adaptable asynchronous code. <!--more-->

## "Functional Reactive Programming"?!

Let's parse out what that phrase actually means. We hopefully already know what "programming" means, but what about the other two words in there?

"Functional" basically means a style of programming that prefers getting its jobs done in a way that uses lots of functions working together. Pure functions, meaning one that simply takes something in and spits something out (with the same output for any input every time) without any side effects, are especially preferred. Often functions will take in other functions (i.e., closures), making them "higher order functions." (If you've ever used `map`, `filter`, `reduce`, etc on arrays, other sequences, or other types, then you've used higher-order functions.)

"Reactive" in this context means that we can _react_ to changes. As a simplified example, have you ever put a `didSet` observer on a property?

```swift
var models: [Model] {
    didSet {
        updateViews()
    }
}
```

This is, more or less, a kind of "reactive" programming. We're reacting to changes in the models array; when the models change, we do something.

Put together, "functional reactive programming" is using this functional style of programming to react to changes. But what does that look like in practice?

Before we answer that question, let's look at how Combine accomplishes all of this.

## Combine Conceptually

The `Publisher` is a protocol that _publishes_ an `Output`. It may publish once and finish, or it may go on publishing values forever. It may publish immediately, or it may wait for a network response. It may wrap another publisher, mutate its output, and republish it. What matters is that at some point it spits out a value (or a stream of values). If it can fail for some reason, it may also spit out an error (its `Failure`). A publisher might also be guaranteed not to fail, in which case its `Failure` will be `Never`.

When a publisher fails, it "completes," signaling that anything subscribed to it will no longer receive more values. It might also complete successfully. For example, for fetching data from the internet, a publisher might publish a single value (the data it was asked to fetch), and then signal that it completed successfully. This `Completion` signal is modeled as an enum very similar to the `Result` type, but its `finished` case has no associated value; only its `failure` case does.

```swift
extension Subscribers {
    enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
```

To work with these publishers, you can also attach _operators_ to them. Technically most of these are also publishers in their own right, but we call them operators when they're implemented as extensions on the `Publisher` protocol. You can therefore use dot-syntax to chain operators one after the other, performing powerful transformations like `map`, `flatMap`, filtering, merging with other publishers, waiting for another publisher, receiving on specific threads, and more.

```swift
URLSession.shared.dataTaskPublisher(for: request)
    .tryMap { (d, r) in try Result(data: d, response: r).get() }
    .decode(type: T.self, decoder: JSONDecoder())
    .mapError(NetworkError.init)
    .receive(on: DispatchQueue.main)
    .eraseToAnyPublisher()
```

We get the values published by these using a `Subscriber`, another protocol. Like operators, most subscribers are implemented as extensions on the `Publisher` protocol, and are usually accessed via dot syntax. Subscribing to a publisher produces a `Subscription`, which you'll need to hold a strong reference to if you want to continue to receive values. Usually you'll have access to this via an `AnyCancellable` instance. You can explicitly `cancel` this subscription, or it will be auto-cancelled if you let it die by letting go of all strong references to it.

## Passthrough Subject

Let's look at a couple of simple examples. Our first example uses `PassthroughSubject`. This publisher can be sent values via the `send` method, and subscribers can subscribe to it like any other publisher.

Try putting this in a new playground:

```swift
import Combine

struct SimpleError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String = "unknown error") {
        self.description = description
    }
}

let stringSignal = PassthroughSubject<String, SimpleError>()

stringSignal.send("Hello, world!")
```

Of course, nothing happens yet, because we haven't subscribed to it yet. Let's do that! The easiest way is via the `sink` operator. This allows you to pass in two closures; the first will be run when the publisher "completes", and the second anytime the publisher publishes a value.

Add the following below our previous code:

```swift
stringSignal
    .sink { completion in
        switch completion {
        case .finished:
            print("all done!")
        case .failure(let error):
            print("WHOOPS. Error: \(error)")
        }
    } receiveValue: { str in
        print("received message: \(str)")
    }
```

We still don't see anything, though. That's because we didn't subscribe until _after_ the string signal sent its value. If you add `stringSignal.send("Hello again!!")` after we set up our subscription, we should then see "`received message: Hello again!!`" printed to the console.

There's another "subject" publisher called `CurrentValueSubject` that works very similarly; I'll let you take a look at that in [Apple's documentation](https://developer.apple.com/documentation/combine/currentvaluesubject)! For now, let's look at another publisher type.

## Just

```swift
let justAString = Just("Hello goodbye.")
```

`Just`, like its name implies, _just_ publishes a single value when it's subscribed to, and then it's done. This may not seem super useful, but we'll see later how it can actually really come in handy in some scenarios. Here's a more simple use case, though.

```swift
let justAString = Just("Hello goodbye.")

justAString
    .sink { print("Someone said: \($0)") }

justAString
    .sink { _ in print("See ya!") } receiveValue: { _ in }
```

First, notice we don't have to handle the completion case at all if we don't want to. This is true of any publisher whose `Failure` type is `Never`; it can't fail, so we can choose to ignore the completion entirely if we want to.

Also notice that if you run this code now, we'll see the "someone said" print statement, but the second subscription won't fire. That's because `Just` publishes its value just once and immediately completes, so any additional subscribers are essentially arriving at the party after it's already finished. It's a very short one-person party.

## Operators

Let's try publishing a bunch of stuff from our `stringSignal` from earlier.

```swift
stringSignal.send("blep")
stringSignal.send("539")
stringSignal.send("beep")
stringSignal.send("77.22")
stringSignal.send("123.333")
stringSignal.send("bwup")
```

If you run this, you'll see that the previous subscription still does its thing. Let's add another subscriber. Somewhere before these signals are sent (remember we need to set up the subscription _before_ the value is published, or else we'll miss it), add the following code:

```swift
stringSignal
    .map { Double($0) }
    .sink { _ in } receiveValue: { print("Double! \($0)") }
```

We're using the `Double` initializer to turn those strings into doubles if we can. But in the console, we'll see some awkward output, and we'll also get the compiler warning us about a debug description. Remember that the `Double` initializer returns an `Optional` value, since not all strings can be converted into doubles.

So instead, we can replace `map` with `compactMap` to essentially ignore any nil values.

```swift
stringSignal
    .compactMap { Double($0) }
    .sink { _ in } receiveValue: { print("Double! \($0)") }
```

Alternatively, we might want to stop and throw an error if there are any nil values. For that, we could use `tryMap`.

```swift
stringSignal
    .tryMap { str throws -> Double in
        guard let d = Double(str) else { throw SimpleError() }
        return d
    }.sink { _ in } receiveValue: { print("Double! \($0)") }
```

With `compactMap`, though, we could even simplify further. Consider that the `Double` initializer could be thought of as a function that takes in a `String` and returns `Double?` (`(String) -> Double?`). And recall that any function that takes in a closure could also take in a function. Now look at the signature of the closure that `compactMap` takes in (`(T) -> U?`). `(String) -> Double?` fits that pattern! So rather than calling the method _within_ a closure we provide, we can instead just provide the initializer itself!

```swift
stringSignal
    .compactMap(Double.init)
    .sink { _ in } receiveValue: { print("Double! \($0)") }
```

There's a lot more we could potentially do with operators; for one, we could merge this publisher with the other string publisher we made, so it acts as one stream of values! First, though, we'll have to decide how we want to handle the difference in errors. Remember our passthrough subject might fail, but our `Just` publisher can't fail. This is unfortunately a bit of a pain to solve, but here's the best solution I've come up with:

```swift
stringSignal
    .merge(with: justAString.mapError { _ in SimpleError() })
    .sink { completion in
        print(completion)
    } receiveValue: { str in
        print("merged publisher says: \(str)")
    }
```

Since we can't merge these two publishers without addressing the difference in `Failure` types, we have to adjust one of the errors. It makes the most sense to map the error of the `Just` publisher; since it will never fail, that `mapError` closure will never actually run, but it signals to the compiler that their failure types are now equivalent.

I'd highly recommend just browsing through the various operators you can perform on publishers; I feel like I'm still learning new operators and usages for them every time I use Combine!

## Erasing to AnyPublisher

If you're like me, you might be a little worried about that `PassthroughSubject`'s `send` method being so out-in-the-open like that. Consider the following code:

```swift
struct Habit: Codable {
    let id: UUID
    let name: String
    // ...
}

struct HabitListState {
    var habits: [Habit] = []
    // ...
}

class HabitsStore {
    private(set) var state = CurrentValueSubject<HabitListState, Never>(HabitListState())
    // ...
}
```

Anything that can access an instance of `HabitStore` can `send` a new value through the `state` publisher. We may not want that; maybe we only want to be able to subscribe to it. In this case, we could easily fix this by using the `@Published` property wrapper, and that would be my recommended way to go, but let's pretend for a moment that that didn't exist. How would we make it possible to _subscribe_ to the publisher, but _not_ to publish new values?

```swift
class HabitsStore {
    private var _state = CurrentValueSubject<HabitListState, Never>(HabitListState())

    var state: AnyPublisher<HabitListState, Never> {
        _state.eraseToAnyPublisher()
    }

    //...
}
```

The `eraseToAnyPublisher` operator wraps, well, _any publisher_, and essentially forwards all the usual publisher protocol methods to its wrapped, "erased" publisher. It doesn't matter what kind of publisher it was before; what matters is that it's some kind of publisher that outputs `HabitListState` and never fails.

But we can go further with this and make our code more testable using this type erasure. Let's make a protocol called `HabitStoring`. We'll have our `HabitsStore` conform to that class, and in testing we can replace it with a mock implementation of the protocol.

```swift
protocol HabitStoring {
    var state: AnyPublisher<HabitListState, Never> { get }
    //...
}

class HabitsStore: HabitStoring {
    // (same as before)
}

extension Array where Element == Habit {
    static let mockHabits = [
        Habit(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
              name: "Exercise"),
        Habit(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
              name: "Meditate"),
    ]
}

struct MockHabitStore: HabitStoring {
    var empty: Bool
    // other options

    var state: AnyPublisher<HabitListState, Never> {
        Just(HabitListState(habits: empty ? [] : .mockHabits))
            .eraseToAnyPublisher()
    }
    //...
}
```

As you can see, behind the scenes, the publishers are completely different. One is a `CurrentValueSubject` and the other is a `Just`. But since they're both type-erased, all that matters is that the output and failure types are the same. We could even have several different options of publishers and erase them all so the return type is always the same.

```swift
struct MockHabitStore: HabitStoring {
    var version: MockHabitStoreVersion

    var state: AnyPublisher<HabitListState, Never> {
        switch version {
        case .empty:
            return Just(HabitListState(habits: [])).eraseToAnyPublisher()
        case .twoHabits:
            // Just doing this one a different way to show that it could be anything!
            return Array.mockHabits.publisher
                .collect()
                .map(HabitListState.init)
                .eraseToAnyPublisher()
        case .duplicates:
            return Just(.mockHabits)
                .append(.mockHabits)
                .map(HabitListState.init)
                .eraseToAnyPublisher()
        }
    }
}
```

## Hanging on to Subscriptions

Let's try another experiment. Let's say we've got the following class.

```swift
class ListView {
    @Published var strings: [String] = []

    init() {
        $strings
            .sink { print("new strings! \($0)") }
    }
}
```

The `@Published` property wrapper, as I previously alluded to, is sort of like a wrapped `CurrentValueSubject` that allows us to easily change/send new values as if it were a regular variable, but we can also access its publisher using the `$` in front of the variable name (in property wrapper terminology, this is actually accessing the wrapper's `projectedValue`).

Let's now try instantiating this class and setting its strings.

```swift
let myListView = ListView()
myListView.strings = ["bleep", "blep", "meep", "morp"]
```

You might expect to see those strings printed, as we set up a `sink` that did just that. And indeed, we see an empty array printed out. However, note that `sink` returns an `AnyCancellable`, which we've thus far ignored. That's our subscription, and if we want to keep running the closure we pass into `sink`, we need to hang onto it somehow! (Note that we didn't need to do this in a playground (I'm not certain why this is, but it doesn't matter much for now).)

If our class is just going to have one subscription, we can just make it a simple property on the class.

```swift
class ListView {
    @Published var strings: [String] = []

    private var stringSubscription: AnyCancellable?

    init() {
        stringSubscription = $strings
            .sink(receiveValue: { print("new strings! \($0)") })
    }
}
```

Or, if we're going to have several subscriptions, it might make more sense to just throw them all in a colLection. If we make that collection a `Set`, we even get a handy convenience operator:

```swift
class ListView {
    @Published var strings: [String] = []

    private var subscriptions: Set<AnyCancellable> = []

    init() {
        $strings
            .sink(receiveValue: { print("new strings! \($0)") })
            .store(in: &subscriptions)
    }
}
```

Using `.store` here is essentially a shortcut to writing:

```swift
subscriptions.insert(
    $strings.sink(receiveValue: { print("new strings! \($0)") })
)
```

...which feels a lot weirder to write. In any case, we are now holding on to the subscription, so it'll keep doing its thing until we call `cancel` on it or it gets deallocated when we let go of all strong references to the list view holding the subscription.

## Conclusions

We covered a lot of ground, but this is only the beginning! Combine is a powerful framework that takes a bit of a paradigm shift to fully grasp, but once you do, it makes operations of all kinds much easier to build, compose, parse, mutate, and generally work with.

If you want to read more on Combine, here's a few resources:

- ["Getting started with the Combine framework in Swift" (article from Antoine van der Lee)](https://www.avanderlee.com/swift/combine/)
- ["Combine: Getting Started" (article from Ray Wenderlich)](https://www.raywenderlich.com/7864801-combine-getting-started)
- [_Combine: Asynchronous Programming with Swift_ (book from Ray Wenderlich)](https://store.raywenderlich.com/products/combine-asynchronous-programming-with-swift)
- [_Practical Combine_ (book from Donny Wals)](https://practicalcombine.com)
