+++
title = "Swift Task Store"
description = "A Swift 6 library for managing concurrent async tasks by key with configurable duplicate handling"
weight = 4

[extra]
source = "https://github.com/junebash/swift-task-store"
features = [
    "Key-based task management",
    "Configurable duplicate request behavior",
    "Swift 6 strict concurrency support",
    "Actor isolation enforcement",
    "Track running task state"
]
+++

**Swift Task Store** provides a clean API for managing unstructured async tasks in Swift applications. Store tasks by key, query their running state, and configure what happens when you add a task for a key that's already running—cancel the old one, ignore the new one, or let them run in parallel.

I wrote a [three-part series](/posts/task-management-in-swift-part-1-the-problem/) exploring the problems this library solves and how it works under the hood.
