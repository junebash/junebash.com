+++
title = "Writing an Atomic Property Wrapper in Swift"
date = "2020-01-26 15:48:00+00:00"

[taxonomies]
tags = [ "ios", "programming", "swift",]

[extra]
comment = true
+++

_(Note: This post uses Swift 5.1.)_

This weekend I was working on [a framework for fetch operations][framework source], and was wanting an easy way to make access to a property [atomic][atomic definition] in order to prevent [race conditions][race condition definition] where multiple things try to access or change something at the same time, which could cause all sorts of issues.

After doing a bit of research, this ended up being a two-step process, but in the end it makes both creating and accessing this property easy and succinct.

<!-- more -->

## Writing the wrapper

To start with, let's write a struct that wraps any value type with a dispatch queue.

```swift
struct Atomic<Value> {
    private lazy var queue: DispatchQueue = {
        let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        return DispatchQueue(label: "\(appName).AtomicQueue.\(Value.self)")
    }()
    private var _value: Value

    var value: Value {
        mutating get { queue.sync { _value } }
        set { queue.sync { _value = newValue } }
    }

    init(_ value: Value) {
        self._value = value
    }
}
```

The `DispatchQueue` essentially makes a "checkout line," where anything that tries to either `get` or `set` the value first has to wait in line behind anything else that's queued up to try to access it. I label it with the name of the app and its type for easier debugging purposes[^1].

The underlying `_value` is only accessible within this struct, so there's no danger of it being accessed by something outside without going through the queue (unless we were to re-write/add to it and mess up somewhere, but prefixing with the underscore makes that less likely).

It's a little strange that we need to mark the getter of `value` with `mutating`; that's because, as I understand it, adding something to the queue actually changes the queue, which changes the struct, and anything that does so must be marked `mutating` so the compiler knows whether certain actions can be taken when using `let` vs. `var` instances of this struct.

Now if we want to make something atomic, all we need to do is:

```swift
var x: Atomic<Int> = Atomic(1)

// later...
x.value = 2
print(x.value)

// on another thread somewhere else at the same time...
x.value = 3
print(x.value)
```

As you might imagine, though, writing `.value` every time we want to use it is probably going to get old really quickly.

This is where property wrappers save the day.

## Making it a Property Wrapper

Essentially, a property wrapper is a new-ish Swift feature that allows us to build a wrapper object around another object and make access to the wrapped object quick & easy. [This post][property wrapper post] explains things quite well.

Even using a small portion of their capabilities, this is a perfect use case for our `Atomic` struct, and quite fortunately, it only requires a very minor rewrite of our previous code.

```swift
@propertyWrapper
struct Atomic<Value> {
    private lazy var queue: DispatchQueue = {
        let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        return DispatchQueue(label: "\(appName).AtomicQueue.\(Value.self)")
    }()
    private var value: Value

    var wrappedValue: Value {
        mutating get { queue.sync { value } }
        set { queue.sync { value = newValue } }
    }

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
}
```

The only things we've changed from before are:

- We've added the `@propertyWrapper` keyword immediately before the declaration of our type
- We've renamed some variables (`_value` to `value`, `value` to `wrappedValue`)

That's it! Now you might be thinking, "Okay June, but now I have to type *even more* characters every time I access it; `.wrappedValue` has 8 more key-presses than `.value`![^2] Why would you do that to me?!"

Fear not, my dear, lazy reader. Firstly, `@propertyWrapper` is sort of like a protocol that requires a non-private var `.wrappedValue`, so we're required to use that name exactly.

As for having to type more... well, check this out:

```swift
@Atomic var x: Int = 1

// later...
x = 2
print(x)

// on another thread somewhere else at the same time...
x = 3
print(x)
```

All we need to do now when we want to make something atomic is put the `@Atomic` keyword before it, and then anything else that accesses it doesn't even need to know that it's a wrapped value, and you never need to access `.wrappedValue` (in fact, I don't think you can at least without a few more steps). I don't know about you, but I found this to be awesome.

Now the only danger is avoiding the temptation to needlessly use it everywhere...

### <UPDATE 2020-04-25>

Donny Wals made [a great post](https://www.donnywals.com/why-your-atomic-property-wrapper-doesnt-work-for-collection-types/) about why this will not work with collections in Swift. Worth a reading and worth keeping in mind.

[^1]: Theoretically, at least; honestly, I've never needed to make use of this.
[^2]: If you include the `shift` for the capital `V`.

[framework source]: https://github.com/Junebash/networker
[atomic definition]: https://en.wikipedia.org/wiki/Linearizability#Atomic
[race condition definition]: https://en.wikipedia.org/wiki/Race_condition
[property wrapper post]: https://www.vadimbulavin.com/swift-5-property-wrappers/
