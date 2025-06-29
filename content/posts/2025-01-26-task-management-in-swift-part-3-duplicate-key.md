+++
title = "Task Management in Swift — Part 3: Duplicate Key Behavior"
date = "2025-01-26 03:02:00+00:00"

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

Let’s recap the different behaviors we want to allow when duplicate keys come up in our task store[^1]:

- Cancel the previous task if it’s there, and run the new task immediately
- Cancel the previous task and wait for it to finish, then run the new task
- Wait for the previous task to finish without cancelling before running the new one
- Run the previous task concurrently with the new one
- If there’s a previous task, don’t run a new task

When we need to _enumerate_ different possibilities, what do we reach for? That’s right, an `enum`!

```swift 
enum TaskStoreDuplicateKeyBehavior: Hashable, Sendable {
  case cancelAndWait
  case cancelAndRunImmediately
  case wait
  case runConcurrently
  case preferPrevious
}
```

If you wanted to get fancy you could make it look like this:

```swift 
enum AlternateDuplicateKeyBehavior: Hashable, Sendable {
  case preferNew(cancelPrevious: Bool, waitForPrevious: Bool)
  case preferPrevious
}
```

Or even this: 

```swift 
struct AlternateAlternateDuplicateKeyBehavior: Hashable, Sendable {
  struct PreferNewOptions: Hashable, Sendable {
    var cancelPrevious: Bool
    var waitForPrevious: Bool
  }

  var preferNewOptions: PreferNewOptions?
}
```

Logically, those are all equivalent.[^3] Which option we go with comes down to weighing 1.) what we want the public-facing interface to look like, and 2.) the ease and readability of the implementation details.

I’m going to go with the last option and add some convenience properties that clarify things for us so that we can have the best of both worlds.

```swift 
struct TaskStoreDuplicateKeyBehavior: Hashable, Sendable {
  fileprivate struct PreferNewOptions: Hashable, Sendable {
    var cancelPrevious: Bool
    var waitForPrevious: Bool
  }

  fileprivate var preferNewOptions: PreferNewOptions?

  var preferPrevious: Bool {
    preferNewOptions == nil
  }
  var cancelPrevious: Bool {
    preferNewOptions?.cancelPrevious ?? false
  }
  var waitForPrevious: Bool {
    preferNewOptions?.waitForPrevious ?? true
  }
  var runNewTask: Bool {
    preferNewOptions != nil
  }

  static var wait: Self {
    Self(preferNewOptions: .init(cancelPrevious: false, waitForPrevious: true))
  }

  static func cancelPrevious(wait: Bool) -> Self {
    Self(preferNewOptions: .init(cancelPrevious: true, waitForPrevious: wait))
  }

  static var runConcurrently: Self {
    Self(preferNewOptions: .init(cancelPrevious: false, waitForPrevious: false))
  }
  
  static var preferPrevious: Self { Self() }
}
```

Let’s add this as a parameter to our `addTask` method.

```swift
  func addTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    isolation: isolated (any Actor)? = #isolation,
    operation: @escaping @Sendable () async -> Void
  )
```

I think that cancelling the previous task and not waiting is a good default behavior, personally, but it’s definitely up for debate.

Now, implementing the behavior based on what’s encoded in the `duplicateKeyBehavior` becomes fairly trivial.

```swift 
  func addTask(/*...*/) {
    let preferNewOptions = duplicateKeyBehavior.preferNewOptions
    let previousTask = self.currentTasks[key]?.task
    if let previousTask {
      guard let preferNewOptions else { return }
      if preferNewOptions.cancelPrevious {
        previousTask.cancel()
      }
    }
    let newTaskID = UUID()
    let newTask = Task(
      priority: priority,
      operation: {
        await withTaskCancellationHandler {
          if let previousTask, let preferNewOptions, preferNewOptions.waitForPrevious {
            await previousTask.value
          }
          await operation()
          self.taskFinished(key: key, id: newTaskID, isolation: isolation)
        } onCancel: {
          previousTask?.cancel()
        }
      }
    )
    self.currentTasks[key] = TaskData(id: newTaskID, task: newTask)
  }
```

Let’s break this down bit by bit.

```swift
    let preferNewOptions = duplicateKeyBehavior.preferNewOptions
    let previousTask = self.currentTasks[key]?.task
    if let previousTask {
      guard let preferNewOptions else { return }
      if preferNewOptions.cancelPrevious {
        previousTask.cancel()
      }
    }
```

If a previous task exists, we want to check if we are preferring the new task over the previous task, otherwise we want to early exit and just keep running the original task. If we do want to prefer the new task, then we’ll cancel it (or not) based on the preferred behavior.

Finishing off this synchronous context outside the async task:

```swift 
    let newTaskID = UUID()
    let newTask = Task(
      priority: priority,
      operation: { /*...*/ }
    )
    self.currentTasks[key] = TaskData(id: newTaskID, task: newTask)
```

Probably pretty self-explanatory; we make our new ID, we make the task with the provided priority, and we store it in our store’s current tasks. (Remember that at this point we’ve checked to make sure we are indeed preferring the new task over the old one (or there is no old task).)

Lastly, inside the async task:

```swift 
        await withTaskCancellationHandler {
          if let previousTask, let preferNewOptions, preferNewOptions.waitForPrevious {
            await previousTask.value
          }
          await operation()
          self.taskFinished(key: key, id: newTaskID, isolation: isolation)
        } onCancel: {
          previousTask?.cancel()
        }
```

If the task is cancelled, we want to make sure the previous task is cancelled as well (if it exists), so we wrap it in the `withTaskCancellationHandler` block. Cancellation will automatically propagate to `operation`. If the previous task exists and we’ve indicated we want to wait for it, then we do that before starting the new work. Finally, we call the function we made last time to remove the task if this one is still being held by the store.

There’s one more thing we could add to make this even more awesome. Let’s say we want to run some `async` task when our view appears using the `task` view modifier. Maybe we even want to cancel it when the view disappears. With just a couple of small additions, we can make this really easy for the end user.

To start with, we’re going to adjust the signature of our `addTask` method.

```swift 
  @discardableResult
  func addTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    isolation: isolated (any Actor)? = #isolation,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never>
```

We’re returning a task now! But similar to `Task`’s built-in initializer, we don’t want to _require_ the end user to use the task that’s returned. It’s already being managed by the `TaskStore`, we’re just also handing it off if they want a handle to cancel it… such as in the view layer.

Let’s add add a new task to our model.

```swift 
@Observable
final class MyModel {
  private enum TaskKey: Hashable {
    case doThing
    case viewTask
  }

  // ...existing stuff...

  func viewTask() -> Task<Void, Never> {
    taskStore.addTask(forKey: .viewTask) {
      // some async work
    }
  }
}
```

Now, in the view, all we need to do is call that and await the task that’s returned.

```swift 
struct MyView: View {
  @Bindable var model: MyModel

  var body: some View {
    VStack {
	  // ...existing stuff...
    }
    .task {
      await model.viewTask().cancellableValue
    }
  }
}
```

And that’s it![^2] This also makes it much easier to test; you can assert on what the state looks like while it’s loading, and then await its result, and assert on its state again (of course mocking out your dependencies along the way, becaue you are a very good smart programmer yes you are).

There are of course more extensions you can write on this type, but I leave that as an exercise to the viewer. I’ve thought of making this type an open-source package, but honestly, I don’t want to deal with the maintenance cost of that. Just use this in your projects and see if it works for you. Give me a shout-out if it does! Or doesn’t. Whatever you feel like!

You can find the complete code for what we made in this series of posts [here](https://gist.github.com/junebash/396ddd158becd1001fd9e4da3887620c).

[^1]: It’s possible there are other possibilities, but these are the ones that have been relevant to me.
[^3]: We probably don’t _need_ this to be `Hashable` or `Sendable`, but I like to add those conformances where it makes sense and there’s no reason not to.
[^2]: `cancellableValue` is a very useful and simple `Task` extension that can be found in [PointFree’s handy `swift-concurrency-extras` library](https://github.com/pointfreeco/swift-concurrency-extras/blob/0a250bb1029e1e439b9523e61e2bef65842072b2/Sources/ConcurrencyExtras/Task.swift#L52).

