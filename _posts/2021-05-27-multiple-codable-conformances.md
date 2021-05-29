---
title: Multiple Conformances to Codable in Swift
date: 2021-05-29 14:46
categories:
  - Code
---

_(Note: This post uses Swift 5.4 and the iOS 14 SDK)_

There may be some circumstances where you want to encode/decode a model in multiple ways, depending on certain conditions or use-cases. There's a lot of potential solutions to this problem. Here's some of them. 

<!--more-->

## Examples

Maybe most of the time, you want the simple, default conformance for a model like this:

```swift
struct MyModel: Codable {
  var name: String
  var id: UUID
  var created: Date
}
```

If you do nothing else, then this will encode/decode to JSON (or whatever else) in a very similar format.

```json
{
  "name": "June Bash"
  "id": "CAFED00D-CAFE-D00D-CAFE-D00DCAFED00D",
  "created": 643813980.32495201
}
```

Let's say that sometimes, you'll only want to encode a partial model (like just the ID and name), or sometimes you won't get the entire model. How do we handle these cases?

First, though, let's look at encoding, as it's much simpler.

## Encoding

The most straightforward way to do this (for both encoding and decoding, really) is to just make a second version of the model.

```swift
struct MyPartialModel: Codable {
  var name: String
  var created: Date
}
```

That's it, end of blog post.

...There are some downsides to this though. First and foremost, you'll have to make your own way of translating from one version of the model to another, and decide when to use each one. Maybe this isn't a big deal, but if your model has a lot more properties, it can get pretty annoying and complicated.

Let's explore some alternatives.

### A Second Encode Method

Encoding is implemented using the `encode(to encoder: Encoder) throws` method. This can be automatically synthesized by the compiler if all stored properties are also `Encodable`, or we can manually implement it, similarly to `Hashable` and `Equatable`. Let's say that when the model is a child of some other model, we'll only encode the id. Let's say the key will also be `uuid` instead of `id` in those cases. That could look something like this:

```swift
private extension MyModel {
  func encodeForParent(to encoder: Encoder) throws {
    enum ParentCodingKeys: CodingKey { case uuid }
    var container = encoder.container(keyedBy: ParentCodingKeys.self)
    try container.encode(id, forKey: .uuid)
  }
}

struct Parent: Codable {
  var id: UUID
  var someInt: Int
  var child: MyModel

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(someInt, forKey: .someInt)
    try child.encodeForParent(to: container.superEncoder(forKey: .child))
  }
}
```

(Note that `CodingKeys` is automatically synthesized as long as we leave either `init(from decoder:)` or `encode(to encoder:)` as the default, synthesized implementation.)

This will output the following JSON:

```swift
{
  "id" : "00439575-65F8-4D00-953B-B8605F60310B",
  "someInt" : 9,
  "child" : {
    "uuid" : "D4350E5E-3051-4950-ABE2-2792C7A59D96"
  }
}
```

Exactly what we wanted!

But wait, there's more (alternatives)!

## An Inline Partial Model

We can hide a second model that matches our JSON spec _within_ the encode method body.

```swift
struct Parent: Codable {
  //...

  func encode(to encoder: Encoder) throws {
    struct PartialChild: Encodable {
      var uuid: UUID
    }

    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(someInt, forKey: .someInt)
    try container.encode(PartialChild(uuid: child.id), forKey: .child)
  }
}
```

This will output the same results as the previous method. If you don't like either version, there's one more way to do this...

### AnyEncodable

Let's make a wrapper around an encode method. (I've talked about [type-erasure](https://www.junebash.com/blog/type-erasure/) here a [couple](https://www.junebash.com/blog/easier-type-erasure/) of times before.)

```swift
struct AnyEncodable: Encodable {
  private let _encode: (Encoder) throws -> Void

  init(_ encode: @escaping (Encoder) throws -> Void) {
    self._encode = encode
  }

  init<E: Encodable>(_ encodable: E) {
    self.init(encodable.encode)
  }

  func encode(to encoder: Encoder) throws {
    try _encode(encoder)
  }
}
```

By wrapping an encodable type in this using the second initializer, everything referring to the original type will be _erased_. In a lot of cases this type _wouldn't_ come in handy, as the `Encodable` protocol can be thrown around willy-nilly without problems since it has no `Self` or `associatedType` requirements. But it also allows us to make arbitrary `encode` methods.

```swift
struct Parent: Codable {
  //...

  func encode(to encoder: Encoder) throws {
    let childEncodable = AnyEncodable { childEncoder in
      enum ChildCodingKeys: CodingKey { case uuid }
      var container = encoder.container(keyedBy: ChildCodingKeys.self)
      try container.encode(child.id, forKey: .uuid)
    }

    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(someInt, forKey: .someInt)
    try container.encode(childEncodable, forKey: .child)
  }
}
```

I think this version has the most flexibility out of any of the methods discussed, especially if the model won't be nested within some other model.

```swift
try JSONEncoder().encode(AnyEncodable {
    enum ChildCodingKeys: CodingKey { case uuid }
    var container = $0.container(keyedBy: ChildCodingKeys.self)
    try container.encode(myModel.id, forKey: .uuid)
 })
```

## Decoding

Decoding is, perhaps surprisingly, quite a bit more complicated due to the way Swift's type system and the `Decodable` protocol are set up, but some of the solutions will be similar to encoding.

### A Single Decoding Init

We _could_ implement this with a single initializer.

```swift
extension MyModel {
  init(from decoder: Decoder) throws {
    do {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.id = try container.decode(UUID.self, forKey: .id)
      self.created = try container.decode(Date.self, forKey: .created)
    } catch {
      enum ParentCodingKeys: CodingKey { case title, uuid }
      let container = try decoder.container(keyedBy: ParentCodingKeys.self)
      self.name = try container.decode(String.self, forKey: .title)
      self.id = try container.decode(UUID.self, forKey: .uuid)
      self.created = Date()
    }
  }
}
```

This saves having to call the custom init from the parent, but it's also a decent amount of boilerplate that may not be necessary, and if we need more than one special case, it'll get messy fast. We also leave all the logic of determining when and how to decode this inside the initializer. We could decide how to decode using `Decoder.userInfo`, but that opens up a whole other can of worms. Let's look at some other ways to do this.

### A Second Decoding Init

Just like with encoding, we can make a second, custom init just for this circumstance.

```swift
extension MyModel {
  init(fromParent decoder: Decoder) throws {
    enum ParentCodingKeys: CodingKey { case title, uuid }
    let container = try decoder.container(keyedBy: ParentCodingKeys.self)
    self.name = try container.decode(String.self, forKey: .title)
    self.id = try container.decode(UUID.self, forKey: .uuid)
    self.created = Date()
  }
}
```

And then we can call this from the parent's custom init, just like we did with encoding.

```swift
struct Parent: Codable {
  //...
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.someInt = try container.decode(Int.self, forKey: .someInt)
    self.child = try MyModel(fromParent: container.superDecoder(forKey: .child))
  }
}
```

### Nested Decoding Struct

And again just as with decoding, we can make a special struct that lives within the decode `init`:

```swift
  init(from decoder: Decoder) throws {
    struct PartialChild: Decodable {
      var title: String
      var id: UUID
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.someInt = try container.decode(Int.self, forKey: .someInt)
    let partialChild = try container.decode(PartialChild.self, forKey: .child)
    self.child = MyModel(
      name: partialChild.title,
      id: partialChild.id,
      created: Date()
    )
  }
```

Note that both of the previous methods will only work when the type is nested in a parent model.

### Type Erasure

You may be thinking that we could make a type-erased `AnyDecodable` wrapper as well just as simply as we did with encoding. While we can get most of the way there, this type won't be able to conform to `Decodable`; there's no way to inject the required `init` before initializing the value. I've seen some workarounds for this, but they're all far from ideal or overly complex. 

Here's a simplified version that doesn't conform to `Decodable`, but gets things done for our purpose.

```swift
struct AnyDecoding<DecodedValue> {
  private let _decode: (Decoder) throws -> DecodedValue

  init(_ decode: @escaping (Decoder) throws -> DecodedValue) {
    self._decode = decode
  }

  func decode(from decoder: Decoder) throws -> DecodedValue {
    try _decode(decoder)
  }
}
```

The call-site will look something like this:

```swift
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.someInt = try container.decode(Int.self, forKey: .someInt)
    self.child = try AnyDecoding { childDecoder throws -> MyModel in
      enum ChildCodingKeys: CodingKey { case title, uuid }
      let container = try childDecoder.container(keyedBy: ChildCodingKeys.self)
      return MyModel(
        name: try container.decode(String.self, forKey: .title),
        id: try container.decode(UUID.self, forKey: .uuid),
        created: Date()
      )
    }.decode(from: container.superDecoder(forKey: .child))
  }
```

Not super-pretty, but it gets the job done, and keeps everything inside the `Parent` init. Unfortunately, therein lies the problem: this will, yet again, only work when we have access to that `Decoder`. `JSONDecoder` only provides a wrapper around the method that directly calls `init(from decoder:)`. How can we do this when we aren't in a parent model?

### A (Semi)Real AnyDecodable

There is a way to get something that _does_ conform to `Decodable`, but... it's a bit complicated.

```swift
protocol DecodeKey {
  associatedType DecodedValue

  static func decode(from decoder: Decoder) throws -> DecodedValue
}

public struct AnyDecodable<Key: DecodeKey>: Decodable {
  public let value: Key.DecodedValue

  public init(from decoder: Decoder) throws {
    self.value = try Key.decode(from: decoder)
  }
}
```

Any time we want to make an instance of `AnyDecodable`, we need to create another type that holds our `decode` method, like so:

```swift
enum PartialDecodeKey: DecodeKey, CodingKey {
  case uuid, title

  static func decode(from decoder: Decoder) throws -> MyModel {
    let container = try decoder.container(keyedBy: Self.self)
    return MyModel(
      name: try container.decode(String.self, forKey: .title),
      id: try container.decode(UUID.self, forKey: .uuid),
      created: Date()
    )
  }
}
```

See how we can even use this enum as the `CodingKey`? And then our parent decode method would look like this:

```swift
init(from decoder: Decoder) throws {
  let container = try decoder.container(keyedBy: CodingKeys.self)
  self.id = try container.decode(UUID.self, forKey: .id)
  self.someInt = try container.decode(Int.self, forKey: .someInt)
  self.child = try container.decode(AnyDecodable<PartialDecodeKey>.self, forKey: .child).value
}
```

And we can even use a top-level decoder like `JSONDecoder` to decode it outside of a parent model!

```swift
let myModel = try JSONDecoder().decode(AnyDecodable<PartialDecodeKey>.self, from: data).value
```

Notice we have to include the `.value` at the end of the last line. However, unlike some other implementations of `AnyDecodable`, this is completely typesafe; we don't have to rely on any runtime conditional casting.

## Conclusions

So again, all of these methods of secondary coding implementations have their upsides and downsides. And of course, I'm sure there are things that I've left out. Regardless, choose whatever works best for your situation.