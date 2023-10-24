# ``OneWay``

A Swift library for state management with unidirectional data flow.

## Overview

OneWay is a remarkably simple and lightweight library designed for state management through unidirectional data flow. It is implemented based on [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/). The `Store` is implemented with an `Actor`, making it always thread-safe.

```swift
// Define a reducer
final class CountingReducer: Reducer {
    enum Action: Sendable {
        case increment
        case decrement
        case twice
    }

    struct State: Sendable & Equatable {
        var number: Int
    }

    // Implement the logic for each Action
    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .increment:
            state.number += 1
            return .none

        case .decrement:
            state.number -= 1
            return .none

        case .twice:
            return .concat(
                .just(.increment),
                .just(.increment)
            )
        }
    }
}
```

Whether you're using UIKit or SwiftUI, you can seamlessly apply it everywhere and utilize it in all places where you want to simplify complex logic in a one-way direction, not just in the presentation layer.

## Requirements

| OneWay | Swift | Xcode | Platforms                                     |
|--------|-------|-------|-----------------------------------------------|
| 2.0    | 5.9   | 15.0  | iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0 |
| 1.0    | 5.5   | 13.0  | iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0 |

## License

OneWay is released under the MIT license. See LICENSE for details.

## Topics

### Essentials

- ``Store``
- ``ViewStore``
- ``Reducer``
- ``Effect``

### Miscellaneous

- ``Effects``
- ``AnyEffect``
- ``DynamicSharedStream``

### PropertyWrappers

- ``Heap``
- ``Insensitive``
- ``Sensitive``

### Articles
