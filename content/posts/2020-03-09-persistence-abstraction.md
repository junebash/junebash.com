+++
title = "Abstracting Away Your Persistence with Swift"
date = "2020-03-09 10:54:00+00:00"

[taxonomies]
tags = [ "ios", "programming", "swift",]

[extra]
comment = true
+++

*(Note: This post uses Swift 5.1)*

Most tutorials I've seen out there that have to do with local persistence (i.e., saving your app's data on the device) end up with the framework's tendrils wriggling all throughout the app's codebase. This isn't an issue in a tutorial app, or even in smaller apps, but in a larger app, it can become a problem especially if you want/need to switch to a different framework.<!-- more --> For example, Core Data has `NSFetchedResultsController` that's basically designed to be adopted by a `UITableViewController`, leading to an explicit dependency on Core Data. If you decide to switch your app's persistence to Realm and your table views are using the aforementioned FRC directly in your view controller code, you could have quite a bit of refactoring to do.

One solution, as you might have guessed from the title of this post, is to abstract away your persistence layer, so that the majority of your app has no knowledge whatsoever about what system is being used for persistence. The bad news is, this can be more difficult than you might expect...

## Writing the API

Our goal here is to have a generic API that can accomplish what we need to accomplish for data persistence without being explicitly dependent on any particular persistence framework; we want to be able to switch out Core Data for Realm for basic SQLite for raw JSON for some custom system without (too much) trouble.

This is a perfect use case for protocols; using protocols, we can design a `PersistentRepository` interface, write a class that adopts this protocol (and uses our desired persistence framework to implement its methods), and pass in this "generic" object throughout the app wherever it's needed, with all of these entities being none-the-wiser for what sort of framework is being used behind the scenes.

```swift
protocol PersistentModel {}

protocol PersistentRepository {
    func fetch<T: PersistentModel>(_ model: T.Type, options: FetchOptions?)
        throws -> [T]
    func save<T: PersistentModel>(_ entity: T) throws
    func write<T: PersistentModel>(_ entity: T, changes: () throws -> ()) throws
    func delete<T: PersistentModel>(_ entity: T) throws
    func deleteAll<T: PersistentModel>(_ model: T.Type) throws
}
```

This is a pretty basic interface for [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) operations and loading your saved objects. `PersistentModel` is a blank protocol that just lets us limit what can be passed in to the methods, letting us write types that adopt the protocol, signaling that they can be persisted using this system. (`FetchOptions` is a tiny custom struct I wrote that just encapsulates a couple of options that are commonly used when fetching data (`NSPredicate`, a string for the key by which to sort, and an "ascending" boolean).

## Challenges in the Implementation

There's a couple of problems with this though. Here's how I've implemented part of this protocol with Realm.

```swift
class RealmRepository: PersistentRepository {
    var realm: Realm

    init(realm: Realm? = nil) throws {
        let realm = try realm ?? .main()
        self.realm = realm
    }

    func fetch<T: PersistentModel>(
        _ model: T.Type,
        options: FetchOptions?
    ) throws -> [T] {
        var results = realm.objects(T.self)
        if let predicate = options?.predicate {
            results = results.filter(predicate)
        }
        if let sorting = options?.sorting {
            results = results.sorted(byKeyPath: sorting.key,
                                     ascending: sorting.ascending)
        }
        return results.asArray
    }

    //...
```

*Some quick notes:*

1. *`Realm.main()` is a static extension with my default configuration. I've written the method this way because `Realm`'s initializer can throw an error, and throwing initializers can't be used as default parameters in a method.*
2. *`results.asArray` is a custom Realm `Results` extension that converts it to an array. I'll get back to that later...*


The problem may not be immediately obvious unless you know how Realm works or try to compile this. `Realm.objects(_:)` expects a subclass of `Object`, Realm's equivalent of Core Data's `NSManagedObject` from which any persisted object must inherit. But there's no restriction in this method that `T` must inherit from anything; it just has to conform to `PersistentModel`. `deleteAll(_:)` ends up having the same problem.

"No worries," you might be thinking. "Just make `Object` conform to `PersistentModel` and we're golden." Not so fast! Our `fetch` method still expects *any* object that conforms to `PersistentModel`, so what we get might not be an `Object` subclass. The compiler requires that the method accept any `PersistentModel`.

"Then just downcast it as an `Object`." No can do, friend. As soon as we do that, `Realm.objects(_:)` thinks we want every ol' `Object` that's being persisted, rather than the specific type we asked for. We seem to be out of luck.

## Solving the Fetch Challenge

It took me several weeks to find the solution to this issue, with several diversions into type erasure and protocol associated types (which cannot be conformed to or inherited from, because they can be structs/enums). Ultimately, the solution required literally thinking outside the box. While working through a related issue, I remembered that Core Data's `NSManagedObject` fetches can be performed from a static method on the subclass itself.

This was fairly straightforward to accomplish using a couple of adjustments and extensions.

```swift
protocol PersistentContext {}

extension Realm: PersistentContext {}

protocol PersistentModel {
    static func fetch(
        in context: PersistentContext,
        options: FetchOptions?)
        throws -> [Self]
    static func deleteAll(in context: PersistentContext) throws
}
```

Since we need a `Realm` from which to fetch our objects (and, as another example, Core Data uses an `NSManagedObjectContext`), we'll need to pass that in to the fetch request, hence our new `PersistentContext` protocol to which `Realm` is conforming.

We now need to write the code that will be used when our persisted objects inherit from `Object` and conform to `PersistentModel`.

```swift
extension PersistentModel where Self: Object {
    static func fetch(
        in context: PersistentContext,
        options: FetchOptions?
    ) throws -> [Self] {
        guard let realm = context as? Realm else {
            throw CustomError.incompatiblePersistentContext
        }
        var results = realm.objects(Self.self)
        if let predicate = options?.predicate {
            results = results.filter(predicate)
        }
        if let sorting = options?.sorting {
            results = results.sorted(byKeyPath: sorting.key,
                                     ascending: sorting.ascending)
        }
        return results.asArray
    }
}
```

Rather than extend `Object` directly and having that conform to `PersistentModel`, I like the idea of explicitly telling the compiler which types I want to conform to this protocol. With this code, if I tell an object to conform to this protocol, and it already happens to inherit from Realm's `Object` type, it will now get these static methods "for free." It begins by making sure the `PersistentContext` we passed in is actually a `Realm`, or else throws a custom error. It then uses `Self`, referring to the type of this conforming object (not downcasted, avoiding our previous issues) to perform the fetch from this Realm.

Unfortunately, if we wanted to use this version of the fetch method throughout the app, we'd have to manually pass in a Realm, ruining our persistence abstraction. However, our persistence manager's fetch method could "forward" the parameters that can passed in to call the model's static fetch method.

The `RealmRepository`'s fetch now becomes very simple:

```swift
class RealmRepository: PersistentRepository {
    var realm: Realm
    //...
    func fetch<T: PersistentModel>(
        _ model: T.Type,
        options: FetchOptions?
    ) throws -> [T] {
        try T.fetch(in: realm, options: options)
    }
    //...
}
```

Now, because anything that conforms to `PersistentModel` must have a throwing, static method called `fetch(in:options:)`, and we've successfully implemented it when it inherits from Realm's `Object`, we've now successfully abstracted away our persistence. Of course, we could accidentally pass in an object that conforms to `PersistentModel` but does not inherit from `Object`, and we won't get any build-time errors, but we will be thrown an error at runtime. As long as we make sure to write unit tests for all of our code, I think this is an acceptable trade-off.

## Keeping Framework Benefits Through the Abstraction

There's (at least) one last problem with this, and it has to do with Realm's `Results` type. This is a custom collection that contains references to a set of fetched objects in the database, but these objects are not actually loaded into memory until they are directly accessed, making for a nice performance boost especially with large sets of data.

You might remember earlier I mentioned a custom extension on this type that transforms it into an array. Sadly, this totally ruins the entire benefit of the `Results` class, as it accesses every object in the collection and crams it into an array. To be fair, I haven't tested this, so it might not really matter in most cases, but on principle (and as an exercise in learning) I'd like to try to have the best of both worlds.

I can't just pass the `Results` type around, since that would mean the app has explicit awareness of the framework again. I can't return a generic `Collection<T>`, because protocols can't be genericized like that.

The solution is to use `AnyCollection`, a **type-erased** wrapper which wraps, well, *any collection*, and any call to the standard `Collection` methods and properties are "forwarded" to the wrapped collection. This way, whether it's wrapping a basic array, Realm `Results`, or literally any other `Collection`, the logic behind the scenes is unaffected, and hence we get to keep the performance gains of Realm's `Results` class.

To implement this, we only have a few more changes to make...

```swift
protocol PersistentRepository {
    func fetch<T: PersistentModel>(_ model: T.Type, options: FetchOptions?)
        throws -> AnyCollection<T>
    //...
}

protocol PersistentModel {
    static func fetch(
        in context: PersistentContext,
        options: FetchOptions?)
        throws -> AnyCollection<Self>
    //...
}

extension PersistentModel where Self: Object {
    static func fetch(
        in context: PersistentContext,
        options: FetchOptions?
    ) throws -> AnyCollection<Self> {
        //...(same as before)...
        return AnyCollection(results)
    }
    //...
}
```

All we do is change our return types and wrap our results in an `AnyCollection`. Easy-peasy. Now when I want to write an object to be persisted in `Realm`, the only new thing I need to add is to make sure it conforms to `PersistentModel`, which will be enforced by the compiler.

```swift
class NewEntity: Object, PersistentModel {
    //...insert entity properties here...
}
```

------

We've now got a set of interfaces for persisting our data on-device with any persistence framework, while keeping the implementation details relegated to just a few spots in our code, allowing us both the to use the power of these frameworks as well as the flexibility to switch out frameworks without rewriting our entire app. There are of course edge cases we have not yet handled, and some ways we can further improve this (our persisted objects are still explicitly dependent on the persistence framework...), but we've got the start of something that we can build upon. In the future I'll likely revisit this, and let you know what I find!

In the meantime, do you see anything that doesn't quite work, or an obvious piece of code that could be easily & quickly improved? Get in touch & let me know!
