# ``OneWay``

A Swift library for state management with unidirectional data flow.

## Overview

**OneWay** is a simple, lightweight library for state management using a unidirectional data flow, fully compatiable with Swift 6 and built on [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/). Its structure makes it easier to maintain thread safety at all times.

```swift
// Define a reducer
struct CountingReducer: Reducer {
    enum Action: Sendable {
        case increment
        case decrement
        case twice
        case setIsLoading(Bool)
    }

    struct State: Sendable, Equatable {
        var number: Int
        var isLoading: Bool
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
                .just(.setIsLoading(true)),
                .merge(
                    .just(.increment),
                    .just(.increment)
                ),
                .just(.setIsLoading(false))
            )
        case .setIsLoading(let isLoading):
            state.isLoading = isLoading
            return .none
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

- ``CopyOnWrite``
- ``Ignored``
- ``Triggered``

### Articles

- doc:Testing
