---
title: Testing Code Challenge Solutions in Swift
date: 2020-07-29 14:09
categories:
  - Code
---

_(Note: This post uses Swift 5.3)_

Lately I've been doing a lot of "code challenges" as part of the conclusion of the computer science portion of my time at Lambda School. Testing my solutions using the often clunky web "IDE" interfaces of these code-challenge websites quickly becomes a subtle source of pain when I'm doing a lot of these every day.

So naturally, I wrote some code to solve this.<!--more-->

## Setting Up The Structure

Because these sites need to be able to easily test the code that users submit, the code we have to write is inherently easily testable, usually by virtue of being "pure functions"; that is, for any input, the function will return the same output without any side effects. Ergo, most code challenge solutions could be thought of as simply:

- An `Input` type (could be basically anything)
- An `Output` type (again could be anything)
- An `input` instance of type `Input`
- The `expected output` of type `Output`
- The code to be run, with signature `(Input) -> Output`
- The `actual output` of type `Output`, determined by the aforementioned code

We could probably use a subclass of `XCTestCase` for this, but I'd prefer to make something simple that's exactly what I need rather than co-opt something else into working how I'd prefer.

With this in mind, we can construct a basic structure that can act as a wrapper for this data.

```swift
struct CodeChallengeTestCases<Input, Output> {
   let expected: KeyValuePairs<Input, Output>
   let solution: (Input) -> Output
}
```

The `expected` collection contains matched pairs of an input (the key) and an expected output (the value). `KeyValuePairs` is a relatively uncommon type; it's similar to a dictionary, and can be initialized with a "dictionary literal" (i.e., `[0: "value0", 1: "value2"]`), but with some key differences:

- The `Key` type (`Input` here) doesn't need to conform to `Hashable` (giving us more flexibility)
- Lookup is slower, as no hash table is used behind the scenes (shouldn't be a problem for us here)
- Each `key` is not necessarily unique (though for us it will be)
- May be "lighter" than a `Dictionary`

(You can read more about in [Apple's documentation](https://developer.apple.com/documentation/swift/keyvaluepairs).)

## Providing Output Data

From here, there's all sorts of directions we could go. Obviously it would be nice if we could feed the struct our test data and solution, call a function, and get a "read-out" of sorts of how our solution performed. We could just use a tuple for this `read-out` data, but let's just make a lightweight struct to make things simpler for us.

```swift
extension CodeChallengeTestCases {
   struct Failure {
      let input: Input
      let expectedOutput: Output
      let actualOutput: Output
   }

   func evaluate() -> [Failure] {
      expected.compactMap { ioPair -> Failure? in
         let o = output(for: ioPair.key)
         let e = ioPair.value

         if o == e {
            return nil
         } else {
            return Failure(input: ioPair.key, expectedOutput: e, actualOutput: o)
         }
      }
   }
}
```

Here we define a basic `Failure` struct (nested within the `CodeChallengeTestCases` struct) which gives us information about any failure cases for our solution (what the input was, what was expected, and what our solution spat out).

However, you'll notice that if you tried to run this, you'll get an error: `Binary operator '==' cannot be applied to two 'Output' operands`. What's going on there?

It turns out, our `Output` type needs to conform to `Equatable` if we want to test equality. Most types in Swift's standard library already do, but our type has no way of knowing that by default. We could make `Output` be _required_ to conform to `Equatable`, but in the heat of working on a code challenge, I don't want to have to worry about this.

Instead, we could have `evaluate` take in a closure that evaluates equality for us, and then use that in an overloaded version of this method for the cases `where Output: Equatable`.

```swift
extension CodeChallengeTestCases {
   func evaluate(_ outputEqualsExpected: (Output, Output) -> Bool) -> [Failure] {
      expected.compactMap { ioPair -> Failure? in
         let o = output(for: ioPair.key)
         let e = ioPair.value

         if outputEqualsExpected(o, e) {
            return nil
         } else {
            return Failure(input: ioPair.key, expectedOutput: e, actualOutput: o)
         }
      }
   }
}

extension CodeChallengeTestCases where Output: Equatable {
    func evaluate() -> [Failure] {
      evaluate { $0 == $1 }
   }
}
```

Now we're getting somewhere!

The `outputEqualsExpected` closure also ends up being useful with some code challenges even when the `Output` _does_ conform to equatable. For example, some problems will expect you to return an array, but its order won't matter. If you just tested for basic equality, our test would think it failed. Instead, we can pass in a closure that checks if the expected output simply contains the same _members_ as the actual output, without checking if they're each at the "correct" index.

## Printing Output

We can still go a bit further with our automation here. We currently get a list of data where our solution failed, but it'd be nice if we could just print that to the console with one method call.

```swift
extension CodeChallengeTestCases {
   func printFailures(_ outputEqualsExpected: (Output, Output) -> Bool) {
      printFailures(evaluate(outputEqualsExpected))
   }

   func printFailures(_ failures: [Failure]) {
      let titleText = title ?? "\(Input.self) -> \(Output.self)"

      if failures.isEmpty {
         print("All tests passed for '\(titleText)'!\n")
         return
      }

      print("Tests failed for '\(titleText)':")
      for f in failures {
         printEvaluation(for: f.input,
                         expected: f.expectedOutput,
                         actual: f.actualOutput)
      }
      print("\n----------------\n")
   }

   private func printEvaluation(
      for input: Input,
      expected: Output,
      actual: Output)
   {
      print("Input:        \t\(input)\n"
         +  "Expected:     \t\(expected)\n"
         +  "Actual output:\t\(actual)"
      )
   }
}
```

This code is fairly self-explanatory, checking if any failures exist and, if so, looping through them and printing the data contained therein.

I wrote two variants of this method; one takes in an array of `Failure`s that would be spat out by `evaluate(_:)`, while the other simply takes in the same closure that `evaluate(_:)` does, so we can accomplish everything in one go.

We could also have put this method directly on the `Failure` type:

```swift
extension CodeChallengeTestCases.Failure {
   func print() {
      Swift.print("Input:        \t\(input)\n"
               +  "Expected:     \t\(expected)\n"
               +  "Actual output:\t\(actual)"
      )
   }
}
```

...As well as an extension on `Array`!

```swift
extension Array {
   func print<I, O>() where Element == CodeChallengeTestCases<I, O>.Failure {
      let titleText = "\(I.self) -> \(O.self)"

      if self.isEmpty {
         Swift.print("All tests passed for '\(titleText)'!\n")
         return
      }

      Swift.print("Tests failed for '\(titleText)':")
      self.forEach { $0.print() }
      Swift.print("\n----------------\n")
   }
}
```

This allows us to write code either declaratively or imperatively depending on our preference. Here's some of the code in action for some very, very simple "challenges":

```swift
// Write a method that increments the input number by 1
func increment(_ num: Int) -> Int {
   num + 1
}

let incrementTest = CodeChallengeTestCases(
   expected: [
      1: 2,
      3: 4,
      1231: 1232
   ],
   solution: increment(_:)
)
incrementTest.printFailures()


// Write a method that adds an Int to a Double
func add(_ int: Int, to double: Double) -> Double {
   double + Double(int)
}

CodeChallengeTestCases(
   expected: [
      (3, 4.0): 7.0,
      (8, 9.5): 17.5
   ],
   solution: add(_:to:)
).evaluate { expected, actual -> Bool in
   // accounts for potential precision errors
   abs(expected - actual) < .ulpOfOne
}.print()
```

There are of course more improvements we could make (giving a title to our test cases, measuring time and space used, comparing different solutions, etc), but at this point I've probably spent more time writing this "simple" helper than I have actually working on the code challenges, so let's get back to work on those!

p.s., Here's [a gist with the CodeChellengeTestCases code](https://gist.github.com/junebash/6da6efdd3a1bd9e62a994ef72bdcea67) for you to play with, use, and/or extend!
