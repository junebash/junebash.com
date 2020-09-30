---
title: How to Type-Erase Protocols in Swift
date: 2020-09-30 08:25
categories:
  - Code
---

_(Note: This post uses Swift 5.3)_

Type erasure is what allows us types like `AnyCollection`. For any type that conforms to the `Collection` protocol, their interfaces will be exactly the same (except of course for the type of `Element` used). `AnyCollection` allows us to wrap up any collection and swap in one (e.g., an `Array`) for another (e.g., a `Set`, or even a custom collection type).

Unfortunately, writing a type-erased instance of a protocol is far more complicated than it has any right to be, and personally I avoid it where at all possible. Still, there are instances where it can be very useful, and it's sort of interesting from a mere curiosity perspective. So let's take a look at how we can write a type-erased implementation of a protocol! <!--more-->

## Setup

We're going to be using the situation from [my previous post](/blog/protocol-witnesses), where we have a networking function that takes in a query and returns a publisher for our expected output.

Here's what the method signature and the protocol looked like then.

```swift
func query<Input: QueryInput>(_ input: Input) -> AnyPublisher<Input.Output, QueryError>


protocol QueryInput: Encodable {
    associatedtype Output: Decodable

    static var queryString: String { get }
}
```

One quick change I'll get out of the way now: from what I could tell, we won't be able to use a static property for our `queryString`. The `Any_` wrapper needs to be able to get a different string for whatever it's wrapping without actually knowing what it is after initialization, and the only way to do that is by making it an instance property rather than a static one.

With that in mind, here's how our protocol looks now:

```swift
protocol QueryInput: Encodable {
    associatedtype Output: Decodable

    var queryString: String { get }
}
```

In the implementation, this change shouldn't make much of a difference; we can implement it in such a way that the caller will never be able to change those query strings.

So let's say we're working with the following query structs:

```swift
struct FetchPersonWithName: QueryInput {
    typealias Output = Person

    let name: String
    let queryString: String = "blah blah blah"

    init(_ name: String) {
        self.name = name
    }
}

struct FetchPersonIDWithName: QueryInput {
    typealias Output = UUID

    let name: String
    let queryString: String = "blah blah blah blah"

    init(_ name: String) {
        self.name = name
    }
}

struct FetchEventCreator: QueryInput {
    typealias Output = Person

    let eventID: UUID
    let queryString: String = "blah blah blah blah blah"
}
```

Our goal is to be able to make an array of queries that happen to have the same `Output`. Right now, if we try to do that using just our protocol, we'll get an error about `Self` or `associatedType`.

```swift
// This won't compile!
let queries: [QueryInput] = [
    FetchEventCreator(eventID: myEvent.id),
    FetchPersonWithName(name: "Jon Bash")
]
```

We don't have any way to tell the compiler that we just `QueryInput`s with an `Output` of `Person`. Our solution will be to implement a type that conforms to `QueryInput`, but for each of its requirements, it simply "forwards" from another type of query input that has the `Output` we want. So in the end it'll look something like this:

```swift
let fetchMyEventCreator = FetchEventCreator(eventID: myEvent.id)
let fetchJon = FetchPersonWithName(name: "Jon Bash")

let queries: [AnyQuery] = [
    AnyQuery(fetchMyEventCreator),
    AnyQuery(fetchJon)
]
```

## Gener(ic)ally Speaking

Now comes the weird and fun part. The final structure of our `AnyQuery` wrapper will look like this when all is said and done (generalized for any type-erased):

```swift
final class AnyX<AssociatedType>: XProtocol {
    var requiredProperty: Type { box.requiredProperty }

    private var box: _AbstractAnyXBase<AssociatedType>

    init<Wrapped: XProtocol>(_ wrapped: Wrapped) where Wrapped.AssociatedType == AssociatedType {
        self.box = _AnyXBox(wrapped)
    }
}
```

(The underlines in some of those names are just an extra signal to anyone looking at the code that they're a private implementation detail; the end user should never be seeing any of that. We'll also make it all private or fileprivate to enforce that with the compiler.)

`_AbstractAnyXBase` will be an "abstract" class; we won't be able to instantiate an instance of that base class, but we will subclass it and use that in place of a property asking for the base class, similar to how we can use a `UILabel` where a `UIView` is expected.

That's where `_AnyXBox` comes in; it subclasses `_AbstractAnyXBase`, and we use that in place of the base class. Why do we do this? That's where the magic comes in: they're generic over different types. At this point it's probably best to leave the general case and move over to our specific case.

## The Base and the Box

Here's what our abstract base class looks like for our queries:

```swift
fileprivate class _AnyQueryBase<Output: Decodable>: QueryInput {
    var queryString: String { fatalError("must use subclass") }

    private init() { fatalError("must use subclass init") }

    func encode(to encoder: Encoder) throws {
        fatalError("must use subclass") // maybe use more descriptive messages
    }
}
```

Your first impression might be "Ahhh! Everything causes a fatal error!" But remember, we won't ever be using an instance of this base class (and since the initializer is private, we _can't_ even initialize it). We'll only be using the subclass, which will override everything.

What's more important is that this base class matches the signature we're after: it's generic over the _output_, and it conforms to `QueryInput`. That may not _seem_ important yet, so let's move on to the subclass:

```swift
fileprivate final class _AnyQueryBox<Input: QueryInput>: _AnyQueryBase<Input.Output> {
    typealias Output = Input.Output

    var wrapped: Input

    override var queryString: String { wrapped.queryString }

    init(_ input: Input) {
        self.wrapped = input
    }

    override func encode(to encoder: Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
```

Now we're getting somewhere. We're "forwarding" requirements of the protocol (i.e., the `queryString` property and the `encode` method) to our wrapped input, so no more fatal errors. But the magic is again in the generics.

Our box is now generic over the _Input_ of the query... but it subclasses from a base generic over _that_ input's _Output_. So anywhere we might ask for an `_AnyQueryBase<Person>`, we could feed this Box any query where the output is Person, and use it in place of the subclass.

"So why don't we just use these two classes?" you might ask. "Why do we have to wrap it in yet _another_ class?"

Essentially, it's to make it easier for anyone using this API. I don't want to have to remember to never instantiate this base class, to use its signature all over but always instantiate only its subclass. Especially if we were to leave a codebase and come back, it would simply be harder to reason about and use if we're counting on us to remember that all or even read all the documentation that we left. So we're doing more work up front to save ourselves time and energy later, which I think is one of our primary duties as programmers.

## The Final Class

With that in mind, let's finish the final wrapper, the class that folks will actually be using.

```swift
final class AnyQuery<Output: Decodable>: QueryInput {
    var queryString: String { box.queryString }

    private var box: _AnyQueryBase<Output>

    init<I: QueryInput>(_ input: I) where I.Output == Output {
        self.box = _AnyQueryBox(input)
    }

    func encode(to encoder: Encoder) throws {
        try box.encode(to: encoder)
    }
}
```

Now, as intended, our final class is generic over just the output type. The only place where we consider our input is in the initializer.

`I` here is simply the actual type of the `Query` we're wrapping (e.g. `FetchPersonWithName` or `FetchEventCreator`). The `_AnyQueryBox` we use (which, again is a subclass of `_AnyQueryBase`) will be generic over this query type `I`. The `Output` of our `AnyQuery` and of our `_AnyQueryBase` will be generic over the `Output` of `I`. Once we set the `box` property to the box we make in the initializer, our `AnyQuery` forgets all about `I`; all it knows is that `box` is an `_AnyQueryBase<Output>` (or in this case, a subclass of it).

This all might look very confusing, I know. I didn't really get it until I made my own protocol with an associated type and made my own type-erased box around it. I'd highly recommend giving this a try if you'd like to understand it better!

## In Practice

Now, _finally_, we can make an array of different queries that spit out a `Person`.

```swift
let fetchMyEventCreator = FetchEventCreator(eventID: myEvent.id)
let fetchJon = FetchPersonWithName(name: "Jon Bash")

let queries: [AnyQuery] = [
    AnyQuery(fetchMyEventCreator),
    AnyQuery(fetchJon)
]
```

...and we can, of course, use it in our query method.

```swift
for q in queries {
    query(q)
        .sink(// ...etc
}
```

We could even use the publisher that Combine adds to arrays to do some work in a slick, functional style.

```swift
queries.publisher
    .flatMap(query(_:))
    .collect()
    .sink { completion in
        if case .failure(let error) = completion {
            print(error)
        }
    } receiveValue: { people in
        print(people)
    }.store(in: &cancellables)
```

...But maybe that's best saved for another time.

## Why It's Not Ideal

[In my previous post](/blog/protocol-witnesses), we discussed a better solution to for this particular problem; having to wrap everything in `AnyQuery` is pretty tedious, not to mention that whole rigamarole we went through just to implement the type-erasure.

However, writing a struct in place of a protocol won't always be the most effective way to go, in and some cases it may not even be possible. And hey, we had some fun, and we got more comfortable with how protocols, generics, and subclassing work in Swift! Even if this may not be an ideal solution, now we can see clearly why, and we're better equipped to handle similar challenges in the future.
