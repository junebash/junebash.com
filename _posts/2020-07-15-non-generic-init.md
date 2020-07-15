---
title: Non-Generic Initializers on Generic Types in Swift
date: 2020-07-15 08:06
categories:
  - Code
---

_(Note: This post uses Swift 5.2 (and a bit of 5.3 at the end))_

One of my favorite things about Swift is how it balances type safety with hidden power, such as in its implementation of generics. In certain scenarios where you want to use this power alongside an enforced type-safety, however (especially if you're coming from a more "loosey-goosey" language like Objective-C or Python), things can seem to get a little bit obnoxious. <!--more--> 

If you're not familiar, generics are essentially **placeholder** types that, upon initialization, will be replaced with a **concrete type**. For example, here's part of a struct I made for SwiftUI:

```swift
struct ColorHeader<NameView: View>: View {
   let nameView: NameView
   let color: Color

   init(nameView: NameView, color: Color) {
      self.nameView = nameView
      self.color = color
   }
   
   var body: some View { /*...*/ }
}
```

`ColorHeader` conforms to the `View` protocol, but it also uses in its body a generic `NameView` that *also* conforms to `View`. In the initializer, I can pass in any type that conforms to `View`, and henceforth, for that value, `NameView` will refer to that specific type. For example, I could pass in a `Text` value...

```swift
let header = ColorHeader(nameView: Text("Title"), color: .purple)
```

...And the type of `header` will now always be `ColorHeader<Text>`. The `NameView` placeholder has been replaced with `Text`.

Let's say that in my app, my `ColorHeader` is _usually_ going to use `Text` for as its `NameView`. It'd be nice if I could just pass in a string to an initializer and save some typing.

```swift
let header = ColorHeader("Title", color: .purple)
```

You might think this would be as simple as creating a second "convenience" initializer.

```swift
init(_ name: String, color: Color) {
   self.init(nameView: Text(name), color: color)
}
```

However, the compiler gives us the error `Cannot convert value of type 'Text' to expected argument type 'NameView'`. Luckily, it also provides us a fix that, at first glance, seems to work!

```swift
init(_ name: String, color: Color) {
   self.init(nameView: Text(name) as! NameView, color: color)
}
```

That exclamation point makes me nervous, but sometimes it's necessary. Worse, though, if we go to use this new initializer, we get a new error...

```swift
let header = ColorHeader("Title", color: .purple)  // "Generic parameter 'NameView' could not be inferred"
```

The fix it offers indeed allows it to work...

```swift
let header = ColorHeader<Text>("Title", color: .purple)
```

...but that kind of defeats the purpose of having the second, non-generic initializer if we have to explicitly provide the type every time. Let's try this:

```swift
init(_ name: String, color: Color) where NameView == Text {
   self.init(nameView: Text(name), color: color)
}
```

Here, we're telling the compiler: "In this initializer, `NameView` is going to be `Text`." ...At least, that's what I thought I was doing. Unfortunately it doesn't compile (in Swift 5.2); we get the error `'where' clause cannot be attached to a non-generic declaration`. We'll come back to this later...

So how do we solve this? Well, there's another way to look at what we were telling the compiler in the last example: "When `NameView` is `Text`, give me this initializer." This sounds like we need to _extend_ `ColorHeader`.

```swift
extension ColorHeader where NameView == Text {
   init(_ name: String, color: Color) {
      self.init(nameView: Text(name), color: color)
   }
}
```

What does _that_ mean? Let's walk through it.

By extending `ColorHeader` conditionally (`where NameView == Text`), we're telling the compiler: "Hey, for this `ColorHeader`, if I have an instance where its generic `NameView` placeholder type is actually `Text`, give me the following extra stuff." We could put just about any computed properties[^1] or methods on this extension, including new initializers. 

It may seem a little bit backwards to say "Give me this initializer when `NameView` is `Text`" when what we want is to _make_ `NameView` equal to `Text`. Swift's language shephards must have agreed, because as of Xcode 12 beta/Swift 5.3, this...

```swift
struct ColorHeader<NameView: View>: View {
   let nameView: NameView
   let color: Color

   init(nameView: NameView, color: Color) {
      self.nameView = nameView
      self.color = color
   }

   init(_ name: String, color: Color) where NameView == Text {
      self.init(nameView: Text(name), color: color)
   }

   var body: some View { /*...*/ }
}
```

...now works! This makes much more sense to me, especially if we don't need that extension for anything other than this initializer.[^2] Once Xcode 12 and Swift 5.3 get official stable releases, I _believe_ that you should be able to use it on older versions of iOS/macOS/etc. So fortunately, most of us should be able to enjoy the simpler solution to this before long!

[^1]: Extensions in Swift cannot contain non-static stored properties; we can add a `static let blah = "blah"` to an extension of a class/struct/enum, but we could _not_ add a `let blep = "blep"`.
[^2]: Given the error message we got previously, I'm guessing the 5.3 compiler is doing some new magic here to essentially synthesize the same extension we wrote before if `where` is used on a non-generic initializer. Or something like that? I'm just spitballing here.
