+++
title = "Swift Fun"
description = "A collection of functional programming utilities and ergonomic extensions for Swift 6"
weight = 5

[extra]
source = "https://github.com/junebash/swift-fun"
features = [
    "Either type with non-copyable support",
    "Result builder for sequence construction",
    "Standard library extensions",
    "Box types for reference semantics",
    "Async utilities"
]
+++

**Swift Fun** is a grab-bag of micro-libraries I kept rewriting across projects. It includes an `Either` sum type with full non-copyable support, a `SequenceBuilder` for declarative collection construction, extensions to the standard library, and various async utilities.

Each module is independent—import only what you need.
