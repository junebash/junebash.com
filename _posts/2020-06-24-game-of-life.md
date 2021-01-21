---
title: Creating Conway's Game of Life in Swift
date: 2020-06-24 08:15
image:
categories:
  - Code
---

_(Note: This post uses Swift 5.2)_

[Conway's Game of Life][GoL wiki] is a classic programming concept that I was tasked with implementing as part of the computer science curriculum at Lambda School recently. This is the sort of task I really enjoy; not a ton of practical use, but a lot of fun! <!--more-->

## The Rules

The game takes places on a rectangular, integer-based grid and operates on the following rules:

- Any cell on the grid can be either dead or alive
- If a cell is alive in one generation and has either 2 or 3 immediate neighbors (horizontally, vertically, or diagonally), it will live on to the next generation
- If a cell has less than 2 neighbors, it dies.
- If a cell has more than 3 neighbors, it dies.
- If a dead cell has exactly 2 neighbors, it springs to life.

These rules can be demonstrated simply with the following function:

```swift
func cell(_ cell: Cell, willLivegiven neighborCount: Int) -> Bool {
    if cell.isAlive {
        return neighborCount == 2 || neighborCount == 3
    } else {
        return neighborCount == 2
    }
}
```

We could remove some redundancy and simplify this even more to:

```swift
func cell(_ cell: Cell, willLivegiven neighborCount: Int) -> Bool {
    return neighborCount == 2 || (cell.isAlive && neighborCount == 3)
}
```

The question now is how to get neighbors, whether a cell has a position or a position contains a cell, and other implementation details.

## The Data Structures

I went through a few different iterations, but my data structures ended up looking like this when all was said and done:

```swift
struct Tilemap {
   private var tiles = [Point: Tile]()
   private(set) var width: Int = 1
   private(set) var height: Int = 1

   private(set) var population: Int = 0

   var gridWraps = true

   init(width: Int = 1, height: Int = 1) {
      self.width = width
      self.height = height
   }
}

enum Tile: UInt8, CaseIterable {
   case dead
   case alive

   init<I: BinaryInteger>(safe rawValue: I) {
      if let tile = Tile(rawValue: UInt8(rawValue)) {
         self = tile
      } else {
         self = Tile(safe: abs(Int(rawValue)) % Self.allCases.count)
      }
   }
}

typealias Point = Vector

struct Vector {
   var x: Int = 0
   var y: Int = 0
}
```

(I chose `Tilemap` because I had recently been going through [Nick Lockwood][]'s excellent [Retro Rampage][] game engine tutorial series, which I took a lot of cues from. Check out [objc.io][]'s [excellent video series][RR videos] on the first few steps of the tutorial as well.)

In Swift, structs often end up being more performant than classes in many circumstances, and it came in handy for a couple of specific reasons here, which we'll see later.

My first version of the `Tilemap` used an array of `Tile` objects and a `width` property, with `height` and `population` being computed based on those properties. Although `height` wasn't terribly expensive computationally (`tiles.count / width`), `population` needed to loop through the entire array every time it was calculated. Making it a stored property and incrementing it every time a tile is changed makes it so values are only recalculated as they need to be, and reducing the need for additional loops.

The dictionary mains makes resizing the map more efficient; for most purposes, an array would probably work just as well (if not better). Overall this is likely a little more complicated than it needs to be, but as I was working through various implementations, this one ended up being the most performant and useful. I also have a tendency at times to get caught up in details before I get something working, so I leaned a little further towards "just get something working." I could likely improve it further with some adjustments, but this gets the job done for now. With more time I'd love to do more detailed testing.

`Tile` could probably just have been a `Bool`, but when I started, I had planned to possibly make other types of tiles ("walls" that couldn't become alive, for example, or coloring tiles differently if they were _about_ to become alive or had _just_ died).

`Point`s and `Vector`s are essentially the same thing for our purposes, in that they consist of an `x` and `y` coordinate, so it makes sense to use a single type to represent them both, making arithmetic with them easier (which helps with finding neighbors).

```swift
extension Vector {
   static var zero: Vector { Vector(x: 0, y: 0) }

   static var up: Vector { Vector(x: 0, y: -1) }
   static var down: Vector { Vector(x: 0, y: 1) }
   static var left: Vector { Vector(x: -1, y: 0) }
   static var right: Vector { Vector(x: 1, y: 0) }

   static var upLeft: Vector { Vector(x: -1, y: -1) }
   static var upRight: Vector { Vector(x: 1, y: -1) }
   static var downLeft: Vector { Vector(x: -1, y: 1) }
   static var downRight: Vector { Vector(x: 1, y: 1) }

   static var neighborVectors: Set<Vector> {
      [.up, .upRight, .right, .downRight, .down, .downLeft, .left, .upLeft]
   }

   var neighbors: Set<Vector> {
      Set(Self.neighborVectors.map { self + $0 })
   }
}
```

With that, I can now call `point.neighbors` to get the set of all points adjacent to that point.

## Updating the Map

The requirements for this assignment required that I use a buffer map on which to map changes. So although my initial instinct was to write an `update` method that updates the map in place, the buffer method ended up having some benefits.

First, we need to generate the new changes to apply to the buffer:

```swift
extension Tilemap {
   //...
   func newGenerationChanges() -> Set<Point> {
      self.compactMapToSet { point in
         let tileIsAlive = self[point].isAlive
         var count = 0
         var tileWillLive: Bool = false
         for neighbor in point.neighbors {
            if self[neighbor].isAlive == true {
               count += 1
            } else { continue }

            if count == 3 || (tileIsAlive && count == 2) {
               tileWillLive = true
            } else if count >= 4 || (tileIsAlive && count >= 3) {
               tileWillLive = false
               break
            }
         }
         return tileIsAlive != tileWillLive ? point : nil
      }
   }
   //...
}
```

_(Check out the [source code][] to get a look at some of the helper methods used here and elsewhere.)_

Essentially, for every point on the map, we'll check whether its status should change, and if it does, we'll add that point to the `Set` of changes. When we're done, we'll have a subset of the entire map that contains only what will change rather than an entirely new map.

Notice that in the for-loop in `newGenerationChanges`, I didn't end up using the function we wrote earlier; using that, I needed to go through every neighbor every time, but doing it this way, we can skip the remaining neighbors if we hit our "overpopulated" threshold, saving some time.

After this, the changes are then applied to the buffer map by the `GameEngine` object (which we'll look at later).

```swift
mutating func apply(_ changes: Set<Point>) {
   changes.forEach { point in
      population += self[point].isDead ? 1 : -1
      tiles[point].toggle()
   }
}
```

For each point that needs to be changed:

- The `population` is incremented or decremented based on whether the tile is about to become `alive` or `dead`.
- The tile is toggled.

## The Engine

The `GameEngine` takes a lot of credit for keeping things relatively efficient, using Grand Central Dispatch to run as many operations as possible on background threads, letting the main thread do the work of updating the UI.

```swift
class GameEngine: ObservableObject {
   @Published var tilemap: Tilemap {
      didSet { bufferMap = tilemap }
   }

   private var bufferMap: Tilemap
   private let updateThread = DispatchQueue.global()

   private var lastUpdateTime = CFAbsoluteTimeGetCurrent()

   init(
      tilemap: Tilemap = .init(width: Tilemap.defaultSize,
                               height: Tilemap.defaultSize)
   ) {
      self.tilemap = tilemap
      self.bufferMap = tilemap
      self.gridWraps = tilemap.gridWraps
   }
}
```

_(Note: I'm leaving out some stored properties in the interest of keeping this post shorter.)_

Because I used SwiftUI for the UI, the class conforms to `ObservableObject` and contains several `@Published` properties to properly keep the UI up-to-date. More on that later.

The real magic happens in the `main` method.

```swift
extension GameEngine {
   func toggleRunning() {
      isRunning ? stop() : start()
   }

   func start() {
      guard !isRunning else { return }
      isRunning = true
      main()
   }

   private func main() {
      updateThread.async { [weak self] in
         while self?.isRunning == true {
            guard let self = self else { return }
            let currentTime = CFAbsoluteTimeGetCurrent()
            let deltaTime = currentTime - self.lastUpdateTime
            if deltaTime < self.frameFrequency {
               continue
            }
            self.lastUpdateTime = currentTime
            let computedFramerate = 1 / deltaTime
            DispatchQueue.main.async {
               self.actualFrameRate = computedFramerate
            }
            DispatchQueue.global().sync {
               self.update()
            }
         }
      }
   }

   private func update() {
      let changes = self.bufferMap.newGenerationChanges()
      DispatchQueue.main.sync {
         self.tilemap.apply(changes)
         self.generation += 1
      }
   }

   func stop() {
      isRunning = false
   }
}
```

As soon as `start` is called, the engine begins running through the main run loop repeatedly until `isRunning` is switched to `false` (i.e., until either `stop` is called or the object is deallocated).[^1] Every run through the loop, we check whether enough time has passed for our requested framerate; if not, we wait (`continue`).

If we're ready, we calculate the current framerate in case it's slower than we'd like, so we can display that in the UI (this is why _setting_ the `actualFrameRate` happens on the main queue; since it's a `@Published` property, it directly updates the UI as a result, so that all needs to be dealt with on the main thread). Then, we run the `update` method on a new queue. Calling it on this same background thread seemed to, strangely, cause some UI issues. I believe this has to do with the way the framerate/delta time is calculated, but again, I ran out of time to do much thorough testing.

The `update` method then generates the new changes on the new background thread, and applies them on the main thread (again, because this directly affects the UI[^2]). Then, back in `main`, the loop continues for every generation until we stop.

## The UI

Most of the UI was implemented using SwiftUI. I first attempted to implement the `TilemapView` using a nested `HStack` and `VStack`, but this ended up being _incredibly_ inefficient, so I ended up using custom path-drawing. Again, I wanted to use SwiftUI, but their touch APIs don't yet allow one to get the position of a single touch, so using a UIKit `UIView` subclass (wrapped in a `UIViewRepresentable`) ended up being simpler.

Here's the `draw` method of that view, which is called whenever the view needs to be redrawn:

```swift
   override func draw(_ rect: CGRect) {
      let liveColor = UIColor { traits in
         switch traits.userInterfaceStyle {
            case .dark: return .white
            default: return .black
         }
      }
      let deadColor = UIColor { traits in
         switch traits.userInterfaceStyle {
            case .dark: return .black
            default: return .white
         }
      }
      let tileSize = getTileSize(tilemapSize: tilemapSize, rect: rect)

      deadColor.set()
      UIRectFill(rect)
      if showGrid {
         gridColor.setStroke()
      }

      for column in 0..<tilemap.width {
         for row in 0..<tilemap.height {
            let point = Point(x: column, y: row)
            guard let tile = tilemap.tile(at: point) else { continue }
            let origin = getTileOrigin(point: point, tileSize: tileSize)
            let tileColor = tile.isAlive ? liveColor : deadColor

            if showGrid {
               tileColor.setFill()
            } else {
               tileColor.set()
            }
            let tileRect = CGRect(origin: origin, size: tileSize)
            UIRectFill(tileRect)
            UIRectFrame(tileRect)
         }
      }
   }
```

As you might expect, it loops through every possible tile and colors it on the screen based on whether it is dead or alive (and on whether dark mode is on!). It may also draw a visual grid if that option is enabled (this would probably better be factored out into a separate view that could be drawn on top of this one).

The rest of the views are fairly straightforward SwiftUI; having not worked much with it, I quite enjoyed learning it more thoroughly and making an adaptive, relatively-pretty interface.

<iframe width="560" height="315" src="https://www.youtube.com/embed/ZbarV135a4Y" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

-----

In the end, for a 25x25 grid (the minimum required by the assignment), the simulation easily runs at 20 generations per second, which is already too fast to really keep track of. It starts to lag a bit around 50x50, but it's still quite usable even at 100x100.

I'm certain that there are many, many ways I could improve upon this (I wanted to implement the [HashLife][] algorithm, but that's going to take a bit more research than I have time for). I'm happy with how it turned out, though, as it gave me an excuse to practice working with these sorts of custom structures and algorithms and game-dev-like concepts in a very encapsulated way. I'm excited to take these lessons into future projects.


[^1]: Because external references to the engine could theoretically be `nil`'d while the loop is still running, we capture `[weak self]` to hold a weak reference to the `GameEngine` within the `main` loop. This way, if that does happen, we won't get a reference cycle where the loop continues running and we don't have access to it to do anything about it. Instead, the reference count will go to zero, the object will be deallocated, and the loop will cease running.
[^2]: I experimented with using `ObservableObject`'s `objectWillChange` publisher directly, but because the UI will modify the tilemap directly at times, this didn't work.

[GoL wiki]: https://en.wikipedia.org/wiki/Conway's_Game_of_Life
[Nick Lockwood]: http://twitter.com/nicklockwood
[Retro Rampage]: https://github.com/nicklockwood/RetroRampage
[objc.io]: https://objc.io/
[RR videos]: https://talk.objc.io/collections/retro-rampage
[source code]: https://github.com/junebash/GameOfLife
[HashLife]: https://en.wikipedia.org/wiki/Hashlife
