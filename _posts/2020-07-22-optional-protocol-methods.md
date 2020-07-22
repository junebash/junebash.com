---
title: Optional Protocol Methods & Properties in Swift
date: 2020-07-22 13:29
categories:
  - Code
---

_(Note: this post uses Swift 5.2)_

I remember when I first learned about protocols, I often got annoyed that we couldn't make optional methods or properties without bridging to Objective-C, which came with its own set of limitations. However, it turns out there's a fun workaround for this! <!--more-->

Let's take the following example:

```swift
protocol DayViewControllerDelegate: AnyObject {
   var habitStore: HabitStore { get }

   func dayViewController(_ dayVC: DayViewController, didSelectHabit: Habit)
   func dayViewController(_ dayVC: DayViewController, shouldDeleteHabit: Habit) -> Bool
}
```

This is a delegate protocol for a `UIViewController` subclass called `DayViewController`. The conforming type could be any class (not a struct or enum, since it's restricted to `AnyObject`). It could be another `UIViewController` subclass that presents an instance of `DayViewController`, or some other object that conforms to the protocol.

So what if I want to reuse this view controller in several different contexts, but in some of these places, the implementations for some methods should be exactly the same? I could make a whole new object to solely act as the delegate, but it'd be nice if I could just make some of these methods optional or provide some default behavior or something.

Well, it turns out you can! The secret, as often seems to be the case, is to use an _extension_ of the protocol.

```swift
extension DayViewControllerDelegate {
   var habitStore: HabitStore { .shared }
   func dayViewController(_ dayVC: DayViewController, didSelectHabit: Habit) {
      // do nothing
   }

   func dayViewController(_ dayVC: DayViewController, shouldDeleteHabit: Habit) -> Bool {
      return true
   }
}
```

By using this extension, whatever conforms to this protocol now doesn't need to implement those methods; they've effectively become "optional," in a sense. If I want to "override" any of these methods, I can easily do so: 

```swift
extension PresentingViewController: DayViewControllerDelegate {
   var habitStore: HabitStore { self.temporaryStorage }
   
   func dayViewController(_ dayVC: DayViewController, didSelectHabit: Habit) {
      showHabitDetails()
   }
}
```

Sadly, this doesn't seem to work with `{ get set }` protocol properties, though I can't imagine a scenario where I'd particularly want that anyways.
