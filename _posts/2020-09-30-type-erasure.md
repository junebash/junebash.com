---
title: How to Type-Erase Protocols in Swift
date: 2020-09-30 10:01
categories:
  - Code
---

_(Note: This post uses Swift 5.3)_

Type erasure is what allows us classes like `AnyCollection<Element>`; the interface of the `Collection` protocol is the same except for the `Element` used, we have this wrapper type that can wrap any collection and allow us to swap one in for the other.

Unfortunately, writing a type-erased instance of a protocol is far more complicated than it has any right to be, and I avoid it where at all possible. Still, it's sort of interesting from a mere curiosity perspective. So let's take a look at how we can do it! <!--more-->

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

Our goal is to be able to make an array

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

    init() {
        fatalError("must use subclass")
    }

    func encode(to encoder: Encoder) throws {
        fatalError("must use subclass") // maybe use more descriptive messages
    }
}
```

Your first impression might be "Ahhh! Everything causes a fatal error!" But remember, we won't ever be using an instance of this base class; we'll only be using the subclass, which will override everything.

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

Our box is now generic over the _Input_ of the query... but it subclasses from _that_ input's _Output_. So anywhere we might ask for an _AnyQueryBase<Person>, we could feed this Box any query where the output is Person, and use it in place of the Person base.

"So why don't we just use these two classes?" you might ask. "Why do we have to wrap it in yet _another_ class?" Essentially to make it easier for the the end user; I don't want to have to remember to never instantiate this base class, to use its signature all over but always instantiate only its subclass.

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

Now, as intended, our final class is generic over just the output type, and the only place where we consider our input is in the initializer, where the compiler determine's the type of the instance's `Output` based on the input's `Output`. After that, we wrap it in our box, but then we stop caring that it's a box or what the input is; we just know that it's some kind of `_AnyQueryBase` (or in this case, a subclaass thereof).

Normally the initializers of generic types aren't generic themselves; as we saw with our `_AnyQueryBox`, if the generic type is used in the initializer, it can infer the rest. With our `AnyQuery` though, we had to tell it explicitly that it would be some kind of concrete type (a generic `I`) that conforms to `QueryInput` (because again, we can't use the protocol itself due to Self/associatedtype requirements).

## In Practice

Now, _finally_, we can make an array of different queries that spit out a `Person`.

```swift
let queries: [AnyQuery<Person>] = [
    AnyQuery(FetchPersonWithName("Jon Bash")),
    AnyQuery(FetchEventCreator(eventID: UUID())),
    AnyQuery(FetchPersonWithName("Jim Bash")),
//    AnyQueryInput(FetchPersonIDWithName("Chrumbus Krample")) // won't work; output isn't `Person`
]
```

...and we can, of course, use it our old query method from last time.

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
    }
    .store(in: &cancellables)
```

...But maybe that's best saved for another time.

## Why It's Not Ideal

[My previous post](/blog/protocol-witnesses) talks about a better solution to this issue, but suffice to say, having to wrap everything in `AnyQuery` is pretty tedious, not to mention that whole rigamarole we went through just to implement the type-erasure.

But hey, we had some fun, and we learned more about how protocols, generics, and subclassing work in Swift! Even if this may not be an ideal solution, now we can see clearly why, and we can better handle ourselves with similar challenges in the future.
