---
title: "Super Countdown Tracker: Sorting and Filtering Objects in Swift"
date: 2020-01-02 11:50
image:
categories:
  - Code
---

Happy New Year! I realized recently that I haven't written in awhile and I never really wrote about [Super Countdown Tracker][app website], so I'm now taking care of both of those things.

<!--more-->

From the [App Store description][app store link]:

> Add the dates/times of important events in the near or distant future, and Super Countdown Tracker will tell you how much time is left.
>
> - Super Countdown Tracker is *super simple*!
> - Add and edit events
> - Add tags to your events
> - Sort & filter events by date and/or tag
> - Add notes to your events
> - Notifications inform you when your countdowns end
> - Completed events are automatically archived
> - Automatic, adaptive dark/light themes

Even in the two months since initially writing the app, I've learned a ton, so not everything in the app follows best practices or even kinda-okay practices. Still, it gets the job done pretty well as far as I'm concerned, and I'm very proud of what I was able to accomplish after only a few weeks of iOS Development.

## Inception

At Lambda School, the first 16 weeks follow a pattern of:

- 3 weeks of instruction;
- 1 week of building an app ("Build Week").

In the iOS track, the first Build Week is (optionally) a solo endeavor. We were given a few different ideas of apps to build, and we chose our favorite. I'm a sucker for simple "tracker" style apps, and at various points in my life I've recalled wanting to have a handy spot where I could count down the days to various events. (If a habit or to-do tracker had been an option, I probably would have picked that.)

So it's really as simple as that; it was just the option that appealed to me most.

As for the title? Well, "Countdowns" wasn't available. Adding a "super" in front of things seemed silly and fun. So I did it.

## Writing the Code

I don't want to go through the entire app, so I'll highlight a couple of things I was excited about, that I think or interesting, or that I think I should have done better.

### EventController Singleton

At the center of the app is the `EventController` class, which, as you might imagine, controls the handling of events throughout the app. Since at the time I didn't know any better, I implemented it as a singleton in a kinda weird way I learned from some C# tutorials I'd been watching for Unity.

```swift
private static var _shared: EventController?

/// Returns the current shared instance of EventController if already existing.
/// If not existing, creates instance.
static var shared: EventController {
    if let sharedInstance = _shared {
        return sharedInstance
    } else {
        _shared = EventController()
        _shared?.loadEventsFromPersistenceStore()

        return _shared!
    }
}
```

Of course there are much simpler ways to do this, even if I did want to utilize the singleton pattern (which I now know can be somewhat problematic, but I'll avoid that topic for now):

```swift
static var shared = EventController()

private init() {
    loadEventsFromPersistenceStore()
}
```

Not only is this a *lot* simpler, but by using a private initializer, we ensure that only the `EventController` class can access the initializer, thus ensuring that there will only ever be one instance of it.

An even better solution would probably be to use dependency injection and pass an `EventController` instance around the app as needed.

### Sort/Filter Enums

For sorting and filtering the list of countdowns, I wanted the user to have a set number of ways they could sort and/or filter. This is a perfect use case for `enum`s.

```swift
enum SortStyle: String, CaseIterable {
    case soonToLate = "End date ↓"
    case lateToSoon = "End date ↑"
    case creationDate = "Date created ↓"
    case creationDateReversed = "Date created ↑"
    case modifiedDate = "Date modified ↓"
    case modifiedDateReversed = "Date modified ↑"
    case numberOfTags = "Number of tags ↓"
    case numberOfTagsReversed = "Number of tags ↑"
}

enum FilterStyle: String, CaseIterable {
    case none = "(none)"
    case noLaterThanDate = "Now → ..."
    case noSoonerThanDate = "... → ∞"
    case tag = "Tag..."
}
```

The strings here are displayed to the user on the pickers of the sort/filter screen. The `CaseIterable` protocol is adopted for counting and indexing the different styles for use in setting up the `UIPickerViews`.

It would probably have been "better" (in terms of modularity, separation of concerns, and simplicity of types) to separate the enums' logical cases from the UI text that the user sees. We could instead instead simply adopt `Int` as the enums' raw value type, which would also mean we don't necessarily have to use the `CaseIterable` protocol. I'll come back to that idea later...

### Sort Logic

The sorting and filtering of events happens in the `EventController`. First, `sort`:

```swift
/// Sort the lists of active & archived events by the given style.
func sort(_ events: [Event], by style: SortStyle) -> [Event] {
    return events.sorted {
        switch style {
        case .soonToLate: return $0.dateTime < $1.dateTime
        case .lateToSoon: return $0.dateTime > $1.dateTime
        case .numberOfTags: return $0.tags.count < $1.tags.count
        case .numberOfTagsReversed: return $0.tags.count > $1.tags.count
        case .creationDate: return $0.creationDate < $1.creationDate
        case .creationDateReversed: return $0.creationDate > $1.creationDate
        case .modifiedDate: return $0.modifiedDate < $1.modifiedDate
        case .modifiedDateReversed: return $0.modifiedDate > $1.modifiedDate
        }
    }
}
```

As you might be able to tell, this simply takes in a list of events and a sort style, switches on that enum, sorts it in one of a few different ways depending on that style, and returns the newly sorted array. I think I'm pretty happy with the simplicity of this, but since there's essentially twice as many cases as we actually need (every other one is just the opposite of the previous one), there are ways we could restructure this.

```swift
enum SortStyle {
    // bool for ascending or descending
    case endDate(Bool)
    case creationDate(Bool)
    case modifiedDate(Bool)
    case numberOfTags(Bool)
}
```

Unfortunately doing this means refactoring a number of other spots of the app (since the enum can no longer have a raw value or easily conform to `CaseIterable`), but for this specific use case it works quite nicely.

To make it even more clear, we could also implement a second enum:

```swift
enum SortDirection {
    case ascending, descending
}
```

...and use that as the argument of the `SortStyle`, so one doesn't have to look at the type's declaration to figure out what that Bool is supposed to be for.

Or, we could even make a struct that takes a `SortStyle` and `SortDirection`:

```swift
struct Sorter {
    var sortStyle: SortStyle
    var sortDirection: SortDirection
}
```

...and perhaps a helper function in our SortStyle enum:

```swift
enum SortStyle {
    case endDate
    case creationDate
    case modifiedDate
    case numberOfTags

    func eventOrderShouldRemain(for lhs: Event, _ rhs: Event) -> Bool {
        switch self {
        case .endDate: return lhs.dateTime < rhs.dateTime
        case .creationDate: return lhs.tags.count < rhs.tags.count
        case .modifiedDate: return lhs.creationDate < rhs.creationDate
        case .numberOfTags: return lhs.modifiedDate < rhs.modifiedDate
        }
    }
}
```

...And so by abstracting at the different elements of the sorting, we repeat ourselves less and simplify the sort method:

```swift
func sort(_ events: [Event], with sorter: Sorter) -> [Event] {
    let isAscending = (sorter.sortDirection == .ascending)
    return events.sorted {
        let shouldRemain = sorter.sortStyle.eventOrderShouldRemain(for: $0, $1)
        return isAscending ? shouldRemain : !shouldRemain
    }
}
```

Again, though, this means refactoring other parts of the app, and the initial version really wasn't *that* bad to begin with. Lessons learned for the future perhaps?

### Filter Logic

The filter method is a tad more complicated:

```swift
/// Returns an array of events filtered by the provided filter settings
/// from the provided events array.
func filter(
    _ events: [Event],
    by style: FilterStyle,
    with filterInfo: (date: Date?, tag: Tag?)?
) -> [Event] {
    return events.filter {
        switch style {
        case .none:
            return true
        case .tag:
            if let tag = filterInfo?.tag, tags.contains(tag) {
                if tag == "" {
                    return $0.tags.isEmpty
                } else {
                    return $0.tags.contains(tag)
                }
            } else {
                return false
            }
        case .noLaterThanDate:
            guard let date = filterInfo?.date else { return true }
            return $0.dateTime < date
        case .noSoonerThanDate:
            guard let date = filterInfo?.date else { return true }
            return $0.dateTime > date
        }
    }
}
```

This method is actually very similar in basic structure to the `sort` function; it takes in an array of `Event`s, filters them using an array method and a switch, and spits the new array out.

Again, there are some things we can do to improve it:

1. That `filterInfo` tuple is pretty ugly. One way to fix it would be to make it its own type (probably a struct). There's arguably an even better alternative, though...
2. Again, a shift in the enum could simplify things a bit. Along with that, we can, again, pass what *was* in our `filterInfo` as arguments *of* the enum!
3. We don't actually need to check if `tags` (that is, `eventController.tags`) `.contains(tag)`; `eventController.tags` is a computed property that returns all tags used by all events. Therefore, if *any* events have that tag, then it'll be there. And we're already checking all these events. It's a redundant check, so we can get rid of it.
4. With that out of the way, we can drastically simplify the `.tag` case. In fact, it's a perfect spot for another ternary operator (which, despite how weird they look, I really quite love).

```swift
enum FilterStyle {
    case none
    case endDate(Date, Bool) // isBefore
    case tag(Tag)
}

//...

func filter(
    _ events: [Event],
    by style: FilterStyle
) -> [Event] {
    return events.filter {
        switch style {
        case .none:
            return true
        case .tag(let tag):
            return tag == "" ? $0.tags.isEmpty : $0.tags.contains(tag)
        case .endDate(let referenceDate, let showingDatesBeforeReference):
            return $0.dateTime < referenceDate && showingDatesBeforeReference
        }
    }
}
```

Much simpler! Again, we could also add a second enum in place of the `.endDate` bool so it's clearer to the caller what it's actually doing.

### Filter UI Text

You might remember that previously, `FilterStyle` had a raw value that was used in the pickers. Well, we can't use both associated values and raw values, and like I said, UI text probably doesn't really belong with the logic anyways.

We could, like with the `Sorter` previously, make a separate struct that holds our possible reference date and possible tag.

```swift
enum FilterStyle: Hashable {
    case none, endDateIsBeforeReference(Bool), includesTag
}

struct Filter: Hashable {
    var style: FilterStyle

    var referenceDate: Date?
    var tag: Tag?
}
```

...And then put a dictionary like this with the UI code.

```swift
var filterText: [FilterStyle: String] = [
    .none: "(none)",
    .endDateIsBeforeReference(true): "Now → ...",
    .endDateIsBeforeReference(false): "... → ∞",
    .includesTag: "Tag..."
]
```

Although if we want it to stay in order, it might be better to use an array of info.

```swift
typealias FilterUIInfo = (style: FilterStyle, text: String)

let filterUIInfo: [FilterUIInfo] = [
    (style: .none, text: "(none)"),
    (style: .endDateIsBeforeReference(true), text: "Now → ..."),
    (style: .endDateIsBeforeReference(false), text: "... → ∞"),
    (style: .includesTag, text: "Tag...")
]
```

Using a tuple can be a little quick and dirty, but it could lead to annoying problems down the line, so a small struct might work a little better.

```swift
struct FilterUIInfo {
    var style: FilterStyle
    var text: String
}

var filterUIInfo: [FilterUIInfo] = [
    FilterUIInfo(style: .none, text: "(none)"),
    FilterUIInfo(style: .endDateIsBeforeReference(true), text: "Now → ..."),
    FilterUIInfo(style: .endDateIsBeforeReference(false), text: "... → ∞"),
    FilterUIInfo(style: .includesTag, text: "Tag...")
]
```

...but I think the best, simplest, and clearest way to go might just be to make a function that takes in a filter style and returns a string for the filter text.

```swift
func filterUIText(for style: FilterStyle) -> String {
    switch style {
    case .none:
        return "(none)"
    case .endDateIsBeforeReference(let isBeforeReference):
        return isBeforeReference ? "Now → ..." : "... → ∞"
    case .includesTag:
        return "Tag..."
    }
}
```

### Sort/Filter Pickers

Let's take a look at the UI for sorting and filtering.

Here's the setup for the sort-style picker:

```swift
class SortPickerDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(
        _ pickerView: UIPickerView,
        numberOfRowsInComponent component: Int
    ) -> Int {
        return EventController.SortStyle.allCases.count
    }

    func pickerView(
        _ pickerView: UIPickerView,
        titleForRow row: Int,
        forComponent component: Int
    ) -> String? {
        return EventController.SortStyle.allCases[row].rawValue
    }
}
```

There are then two more similar classes for filtering and tags (if the user chooses to filter by tag).

Conforming to NSObject is required for [reasons you'll discover if you try to not do that and implement these protocols](https://twitter.com/peres/status/1201904431207456769). (From what I understand it's part of the long, bloated line of inheritance of UIKit that goes way back to macOS's ancestor, NeXTSTEP.)

As a brief aside: `UIPickerView`s are... weird. In fact I'm still a bit baffled by how Apple has chosen to separate various `UIKit` objects from their -`Delegate` and -`DataSource` protocols, and which methods belong where, and what kind of should adapt each (as using the UIViewController can quickly lead to Massive-View-Controller syndrome).

From my very (*very*) brief research, it seems like Combine and SwiftUI are both attempting to begin addressing this weirdness. Since we're still working with UIKit for now, though (which I hear is advisable for the time-being, as SwiftUI sounds like it's still got a ways to go before it's ready for total adoption), we've got to figure out a way to deal with the weirdness.

Here's part of how I implemented the `FilterPickerDelegate`:

```swift
class FilterPickerDelegate: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    let delegate: SortFilterViewController

    init(delegate: SortFilterViewController) {
        self.delegate = delegate
    }

    // ...some other methods...

    func pickerView(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
    ) {
        let filterStyle = EventController.FilterStyle.allCases[row]
        delegate.showHideFilterComponents(for: filterStyle)
    }
}
```

A couple of issues here:

1. The `delegate` should probably be a `weak var` to avoid memory leaks.
2. ...`FilterPickerDelegate.delegate`. A delegate of a delegate. That's, uhh... funky.
3. The delegate has a specific type, so if I decide to change the structure of this app, I might have some major refactoring to do. Additionally, the `FilterPickerDelegate` shouldn't care that the delegate is going to use the `filterStyle` to show and hide various components; it just wants to hand over the data, and then the delegate can do what it wants with it.

There are a couple of ways to fix all of this. The most simple would just be to put all of this in the `SortFilterViewController` and avoid it altogether, but that means that view controller code gets pretty big and unwieldy, as I mentioned before.

We could also just do some minor adjustments for now:

```swift
protocol FilterPickerDelegate {
    func filterPicker(
        _ filterPicker: UIPickerView,
        didSelectFilterStyle filterStyle: FilterStyle)
}

class FilterPickerDataSource: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    weak var delegate: FilterPickerDelegate?

    init(delegate: SortFilterViewController) {
        self.delegate = delegate
    }

    // ...

    func pickerView(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
    ) {
        let filterStyle = FilterStyle.allCases[row]
        delegate?.filterPicker(
            pickerView,
            didSelectFilterStyle: filterStyle)
    }
}
```

Problem #1 was a fairly easy fix. Problem #2 is still there, but it's made a *little* better by renaming the class.

Problem #3 was the big one; here, we can follow Apple's example and create a protocol that follows their naming conventions. That protocol has a single method, into which the the pickerView is passed (further following Apple's example, in case later we want to do something with that specific picker), along with the new filter style.

Now the only thing that would remain is for the `SortFilterViewController` to adopt the `FilterPickerDelegate` protocol and implement that method.

```swift
extension SortFilterViewController: FilterPickerDelegate {
    func filterPicker(
        _ filterPicker: UIPickerView,
        didSelectFilterStyle filterStyle: FilterStyle
    ) {
        showHideFilterComponents(for: filterStyle)
    }
}
```

In this case we don't even need the `filterPicker` argument at all, but in the future we might want to, in turn, modify that picker depending on some factor of the `FilterPickerDelegate`.

I'm sure there are other, better ways to fix this as well.

---

Okay, I'd say that's more than enough for now. Be sure to [check out Super Countdown Tracker on the iOS App Store][app store link], free to download (no in-app purchases or anything)! You can also check out [the complete source code on Github][source code].

- [App website][app website]
- [iOS App Store page][app store link]
- [Github page][source code]

[app website]: http://Junebash.com/apps/supercountdowntracker/
[app store link]: https://apps.apple.com/us/app/super-countdown-tracker/id1484864299?ls=1
[source code]: https://github.com/junebash/CountdownTracker
