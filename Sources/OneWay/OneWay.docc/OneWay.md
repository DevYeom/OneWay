# ``OneWay``

A Swift library for state management with a unidirectional data flow.

## Overview

**OneWay** is a simple, lightweight library for state management that uses a unidirectional data flow. It is fully compatible with Swift 6 and is built on [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/), which ensures thread safety at all times.

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

Whether you are using UIKit or SwiftUI, you can seamlessly apply it anywhere you want to simplify complex logic with a unidirectional data flow, not just in the presentation layer.

## Requirements

| OneWay | Swift | Xcode | Platforms                                                   |
|--------|-------|-------|-------------------------------------------------------------|
| 3.0    | 6.0   | 16.0  | iOS 16.0, macOS 13, tvOS 16.0, visionOS 1.0, watchOS 9.0    |
| 2.0    | 5.9   | 15.0  | iOS 13.0, macOS 10.15, tvOS 13.0, visionOS 1.0, watchOS 6.0 |
| 1.0    | 5.5   | 13.0  | iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0               |

## License

**OneWay** is released under the MIT license. See [LICENSE](LICENSE) for details.

## Topics

### Articles

- doc:Debugging
- doc:Testing
- doc:ThrottlingAndDebouncing

### Essentials

- ``Store``
- ``ViewStore``
- ``Reducer``
- ``Effect``

### Miscellaneous

- ``AsyncViewStateSequence``
- ``AnyEffect``
- ``Effects``
- ``EffectsBuilder``

### PropertyWrappers

- ``CopyOnWrite``
- ``Ignored``
- ``Triggered``
