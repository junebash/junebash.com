+++
title = "Task Management in Swift — Part 2: Introducing the TaskStore"
date = "2025-01-25 22:27:00+00:00"

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

Let’s set up some goals before we get into the weeds. We want to:
- Be able to run async work and not have the end user need to worry about managing task state
- Explicitly support a variety of behaviors when multiple tasks come into play
- Handle several different tasks at once
- Support testability

Let’s get to work!

---

The centralized location that will handle our tasks will be called the `TaskStore`. (Spoiler alert: right off the bat, we’re going to run into what seem to be limitations of Swift’s current ability to model isolation generically, but it shouldn’t actually be that big of a problem for our purposes.)

In order to handle several different tasks at once (say, loading initial data, saving data, loading additional pages of data, deleting data, etc), we should have some kind of _key_ for each asynchronous chunk of work we want to do. (Another spoiler alert: we’re going to use a `Dictionary` to hold this state, so the key will need to be `Hashable`.)

The public interface will look something like this:

```swift
final class TaskStore<Key: Hashable> {
  func addTask(
    forKey key: Key,
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async -> Void
  )
  func cancelTask(forKey key: Key)
  func taskIsRunning(forKey key: Key) -> Bool
}
```

Note that `addTask` mirrors the signature of `Task`’s initializer, with the addition of the `key` parameter so we can run multiple tasks at once from our store.

The latter two functions are pretty easy to implement once we add some storage for our tasks.

```swift 
final class TaskStore<Key: Hashable> {
  private var currentTasks: [Key: Task<Void, Never>] = [:]

  func cancelTask(forKey key: Key) {
    currentTasks[key]?.cancel()
  }

  func taskIsRunning(forKey key: Key) -> Bool {
    currentTasks.keys.contains(key)
  }
}
```

Nice, so far so good! Remember that task cancellation is cooperative in Swift, meaning that the task itself is responsible for checking if it’s been cancelled and responding adequately. It might still have some work to do, so we can’t just remove it when it’s been cancelled. That logic will happen in the `addTask` method.

However, implementing adding the task is when things get a little tricky. If we just do it like this…

```swift 
  func addTask(
    forKey key: Key,
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async -> Void
  ) {
    let task = Task(
      priority: priority,
      operation: { // !!!
        await operation()
        self.currentTasks.removeValue(forKey: key)
      }
    )
    self.currentTasks[key] = task
  }
```

We get another one of those gnarly warnings: `Passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure`, along with the slightly more helpful note: `Closure captures 'self' which is accessible to code in the current task`.

We’re running into the same issue we did with the model class previously; it’s not isolated to any domain and concurrent tasks can potentially modify state at the same time as each other, which is bad!

The way around this is… a little bit arcane and strange, if I’m being honest. Essentially, we need to give the compiler enough information to be able to tell that any given instance of this type can only possibly be isolated to a single domain. First of all, it needs to not conform to `Sendable`; it can’t, being a class with mutable state, but if it did, it could cross concurrent boundaries, and we don’t want that.

What I would _love_ to do is have something like this:
```swift 
@Isolation
final class TaskStore<Key: Hashable, Isolation: Actor = MainActor> {
  //...
}
```

Unfortunately this is not valid Swift code. Instead, we have to add an extra special parameter to our methods that can possibly concurrently access the mutable state of this class. At the end, it will look like this:

```swift 
  func addTask(
    forKey key: Key,
    priority: TaskPriority? = nil,
    isolation: isolated (any Actor)? = #isolation,
    operation: @escaping @Sendable () async -> Void
  ) {
    let task = Task(
      priority: priority,
      operation: {
        _ = isolation
        await operation()
        self.currentTasks.removeValue(forKey: key)
      }
    )
    self.currentTasks[key] = task
  }
```
That `#isolation` gets the current isolation domain (ie, whatever actor this is running on, be it the `MainActor` or some other actor, global or otherwise). `_ = isolation` lets the task closure know that it should run on the same actor as the one passed into the function. With that, the compiler can figure out, “Oh, these two tasks can never actually run at the same time, because they’re happening on the same actor.” Success![^caveat]

In our model, we now need to add a `Key` to enumerate the different kinds of tasks we’re going to run. For us, for now, it’ll only be one, but we might add more in the future. It still makes the most sense to use an `enum` to model this.

```swift 
@Observable
@MainActor
final class MyModel {
  private enum TaskKey: Hashable {
    case doThing
  }

  //...
}
```

The rest of the implementation ends up being pretty straightforward.

```swift 
final class MyModel {
  //...

  var someText = ""

  private let taskStore: TaskStore<TaskKey> = .init()

  var doThingButtonEnabled: Bool {
    !taskStore.taskIsRunning(forKey: .doThing)
  }
  var showCancelButton: Bool {
    taskStore.taskIsRunning(forKey: .doThing)
  }

  func doThingButtonTapped() {
    taskStore.addTask(forKey: .doThing) {
      // get something from the server or something
      await Task.yield()
      await self.doThingResponse()
    }
  }

  func cancelButtonTapped() {
	taskStore.cancelTask(forKey: .doThing)
  }

  private func doThingResponse() {
    guard !Task.isCancelled else { return }
    someText += "!"
  }
}
```

However, if you run this, you’ll realize that the view is no longer updating. What gives?! 

Well, `Observable` only registers changes to value types and to other observable reference types, so we’re going to need to add observation to our `TaskStore`. This is easy as adding `@Observable` to the type. That’s it!

This also has the knock-on benefit that we no longer necessarily need to isolate our model to the `MainActor`. Since SwiftUI’s views will already be `MainActor`-isolated, this model will as well, and hence our task store will be. Huzzah!

We’ve got another problem, though. The behavior is still not quite right. What happens if another task comes in while the previous one is running, with the same key? When Task 1 finishes, it will remove the current task for that key, even if in the meantime, Task 2 has started and replaced it. Meaning Task 2 might be running still, but it’s been removed from the store, and the store will report it as _not_ running. 

So, in addition to task keys, we need another way to check if it’s actually the same task still running as when we started the task. We could try to do some dancing using `Task`’s built-in `Equatable` conformance, but I’ve found the simpler way is to just use a separate `UUID`.[^performance note] Let’s store this new identifier together with the associated task using a new lightweight struct.

```swift 
private struct TaskData {
  var id: UUID
  var task: Task<Void, Never>
}
```

And now we can replace our existing storage in the `TaskStore`:

```swift
private var currentTasks: [Key: TaskData] = [:]
```

We can also separate out the “completion” into a separate function, which will have the knock-on effect of getting to remove the awkward `_ = isolation` line, since we’ll need to pass on the isolation anyways to give the compiler enough info to know that we’re not breaking any rules here.

```swift 
  func addTask(
    forKey key: Key,
    priority: TaskPriority? = nil,
    isolation: isolated (any Actor)? = #isolation,
    operation: @escaping @Sendable () async -> Void
  ) {
    let id = UUID()
    let task = Task(
      priority: priority,
      operation: {
        await operation()
        self.taskFinished(key: key, id: id, isolation: isolation)
      }
    )
    self.currentTasks[key] = TaskData(id: id, task: task)
  }

  private func taskFinished(key: Key, id: UUID, isolation: (any Actor)?)  {
    if currentTasks[key]?.id == id {
      currentTasks.removeValue(forKey: key)
    }
  }
```

What do we do about the previous task, though? We’re still overwriting it without checking. There’s a few things we could do:
- We could cancel any previous task
  - We could either wait for the previous task to finish, or we could just overwrite it and let the previous one finish in its own time
- We could wait for the previous task to finish without cancelling it before starting the new one
- We could run the new work concurrently with the previous task
- We could even decide that, if there’s currently a task running, we don’t run any new work at all

Which behavior should we adapt? Well, there’s a way we can let the caller decide what to do with every single task! We’ll cover that in the next part.

[^caveat]: There is a caveat here: don’t try to use the task store in a nonisolated domain. This seems to be a hole in Swift’s concurrency checking, and it may result in a runtime crash (or worse, undefined behavior). Be careful! (You could also just mark the `TaskStore` as `@MainActor` if that suits your needs; that’s what I’ve mostly done up to this point, and although in principle I don’t really like that, it hasn’t really proven to be a problem.)
[^performance note]: If you want to eke out more performance, you could use a `UInt` or something, but I haven’t found the need so far.

