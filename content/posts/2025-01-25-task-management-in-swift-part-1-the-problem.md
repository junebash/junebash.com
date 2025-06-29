+++
title = "Task Management in Swift — Part 1: The Problem"
date = "2025-01-25 01:38:00+00:00"

[taxonomies]
tags = [ 'ios', 'programming', 'swift',]

[extra]
comment = true
+++

### Task Management in Swift

1. [The Problem](/posts/task-management-in-swift-part-1-the-problem/)
2. [Introducing the Task Store](/posts/task-management-in-swift-part-2-introducing-the/)
3. [Duplicate Key Behavior](/posts/task-management-in-swift-part-3-duplicate-key/)

---

_note: this post uses Swift 6.0 and Xcode 16.2_

---

Concurrency is hard in any language. It was hard in Swift before modern tools like `async`/`await`/etc were introduced, and it’s still hard, sometimes harder in ways you might not expect. Over the past few years I’ve found a few somewhat novel solutions to some of the difficulties that arise out of working with Swift’s concurrency tools, and I’d like to share them with you.

## The Problem

You’re writing a SwiftUI app with an MVVM-ish architecture because you want to be able to separate your business logic from the UI because you’re very good smart programmer, yes you are. You’ve got something that looks a little like this.

```swift 
@Observable
final class MyModel {
  var someText = ""

  func hitSomeServerEndpoint() async {
    // get something from the server or something
    await Task.yield()
    someText += "!" // do something with the stuff you got from the server
  }
}

struct MyView: View {
  @Bindable var model: MyModel

  var body: some View {
    VStack {
      TextField("Some Text", text: $model.someText)
      
      Button("Do Thing") {

      }
    }
  }
}
```

(I mark all my classes as `final` unless I later decide I want to subclass (which is extremely rare), because inheritance is awful IMO.)

Unfortunately, that button can’t call the async function directly. So maybe you do something like this.

```swift
Button("Do Thing") {
  Task {
    await model.hitSomeServerEndpoint() // !!!
  }
}
```

Uh oh, a compiler error! `Sending 'self.model' risks causing data races`? What does that even mean? The short version is, because `MyModel` is a reference type and is not isolated to any concurrency domain, there’s a chance that some mutable state on there could be simultaneously accessed by multiple threads, which could be bad for several reasons I won’t get into here because other folks have talked about it at great length much better than I could. One solution is fairly simple: just make your model isolated to the main thread by annotating it with `@MainActor`.

```swift 
@Observable
@MainActor
final class MyModel {
  //...
}
```

Problems solved! The end!

Not so fast. Soon, maybe 5 seconds later, maybe years later, you decide you want to be able to cancel that server call for one reason or another. Er. Well, you can’t because you’re throwing the handle to the task away as soon as you start it, because `Task`’s initializer is marked `@discardableResult`, meaning you can initialize a task without holding onto it. So if we want to cancel that task, we have to hang onto it somewhere. The model seems like a good place to do that! Let’s do a bit of refactoring to make this all work together nicely.

```swift 
@Observable
@MainActor
final class MyModel {
  var someText = ""

  private var doThingTask: Task<Void, Never>?

  func doThingButtonTapped() {
    doThingTask = Task {
      // get something from the server or something
      await Task.yield()
      guard !Task.isCancelled else { return }
      someText += "!" // do something with the stuff you got from the server
    }
  }

  func cancelButtonTapped() {
    doThingTask?.cancel()
  }
}

struct MyView: View {
  @Bindable var model: MyModel

  var body: some View {
    VStack {
      TextField("Some Text", text: $model.someText)

      Button("Do Thing") {
        model.doThingButtonTapped()
      }

      Button("Cancel") {
        model.cancelButtonTapped()
      }
    }
  }
}
```

Note that now we check in that task whether it’s been cancelled, and if so, we don’t finish modifying the model state. That’s looking pretty good! But now we’ve got this cancel button there when there might not be anything to cancel, and they can potentially tap the “Do Thing” button a bunch of times and run a bunch of tasks, and only the last tap will actually be held onto. We could add state as to whether to show the cancel button and whether to allow tapping the “Do Thing” button…

```swift 
@Observable
@MainActor
final class MyModel {
  var someText = ""

  private var doThingTask: Task<Void, Never>?

  private(set) var doThingButtonEnabled = true
  private(set) var showCancelButton = false

  func doThingButtonTapped() {
    doThingButtonEnabled = false
    showCancelButton = true
    doThingTask = Task {
      // get something from the server or something
      await Task.yield()
      someText += "!" // do something with the stuff you got from the server
      doThingButtonEnabled = true
      showCancelButton = false
    }
  }

  func cancelButtonTapped() {
    doThingTask?.cancel()
  }
}
```

Sure, that works. But now you need to remember to change those variables every time you use this kind of pattern. Not a big deal, but if a programmer needs to remember to do something, there’s a good chance that at some point they’re going to forget, and that’s going to lead to bugs.

Luckily, there is another way! We are already holding onto some state that can determine whether we should show the cancel button and disable the first button; the `Task`! Instead of separate `Bool`s for every condition in the UI, we can use computed properties based on whether there’s a `Task` currently being held onto.

```swift 
@Observable
@MainActor
final class MyModel {
  var someText = ""

  private var doThingTask: Task<Void, Never>?

  var doThingButtonEnabled: Bool {
    doThingTask == nil
  }
  var showCancelButton: Bool {
    doThingTask != nil
  }

  func doThingButtonTapped() {
    doThingTask = Task {
      // get something from the server or something
      await Task.yield()
      guard !Task.isCancelled else { return }
      someText += "!" // do something with the stuff you got from the server
      doThingTask = nil
    }
  }

  func cancelButtonTapped() {
    doThingTask?.cancel()
  }
}
```

Nice! Unfortunately though, we _still_ need to remember to `nil` out the `Task` here. And guess what? There’s a bug here! Can you spot it? I almost didn’t. I’ll give you a second.

…That’s right, nice find! If the task is cancelled and we hit the early exit, the task will never be `nil`’d out. Case in point! If things _can_ be forgotten, then at some point, they will be. (Hopefully you’ll have a decent test suite where you would have caught that, but that’s a pretty big “hopefully”.) In any case, the solution is to put a `defer` block at the start of the task that nils it out whenever the task is finished, triggering our view update.

```swift 
  func doThingButtonTapped() {
    doThingTask = Task {
      defer {
        doThingTask = nil
      }
      // get something from the server or something
      await Task.yield()
      guard !Task.isCancelled else { return }
      someText += "!" // do something with the stuff you got from the server
    }
  }
```

Cool! So we’ve gotten there, but we still need to remember to do this all correctly next time we write this kind of feature. If only there was a one-stop solution to this sort of problem where this and other behaviors were more explicit and configurable, and we could just have something else worry about having to remember stuff.

…Next time we’ll come up with something that does just that.

_[read part 2](/posts/task-management-in-swift-part-2-introducing-the/)_
