# OneWay

<p align="left">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.5-orange.svg">
  <a href="https://github.com/DevYeom/OneWay/releases/latest">
    <img alt="release" src="https://img.shields.io/github/v/release/DevYeom/OneWay.svg">
  </a>
  <a href="https://github.com/DevYeom/OneWay/actions" target="_blank">
    <img alt="CI" src="https://github.com/DevYeom/OneWay/workflows/CI/badge.svg">
  </a>
  <a href="LICENSE">
    <img alt="license" src="https://img.shields.io/badge/license-MIT-black.svg">
  </a>
</p>

A super simple library for state management with unidirectional data flow.

> 🚧 OneWay is still experimental. As such, expect things to break and change in the coming months.

## Data Flow

<img src="https://github.com/DevYeom/OneWay/blob/assets/flow_description.png" alt="flow_description"/>

## Usage

### Implementing a Way

It is easy to think of a `Way` as a path through which data passes. You can inherit a `Way` and should implement as below. It is also freely customizable and encapsulatable, since `Way` is a class.

```swift
final class CounterWay: Way<CounterWay.Action, CounterWay.State> {

    enum Action {
        case increment
        case decrement
        case twice
    }

    struct State: Hashable {
        var number: Int
    }

    override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
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

### Sending Actions

Sending an action to a `Way` causes changes in the `state` via `reduce()`.

```swift
let way = CounterWay(initialState: .init(number: 0))

way.send(.increment)
way.send(.decrement)
way.send(.twice)

print(way.currentState.number) // 2
```

### Subscribing a Way

When a value changes, it can receive a new value. It guarantees that the same value does not come down consecutively.

```swift
way.publisher.number
    .sink { number in
        print(number)
    }
    .store(in: &cancellables)
```

### Global States

You can easily subscribe to global states by overriding `bind()`.

```swift
let globalTextSubject = PassthroughSubject<String, Never>()
let globalNumberSubject = PassthroughSubject<Int, Never>()

final class CustomWay: Way<CustomWay.Action, CustomWay.State> {
// ...
    override func bind() -> SideWay<Action, Never> {
        return .merge(
            globalTextSubject
                .map({ Action.saveText($0) })
                .eraseToSideWay(),
            globalNumberSubject
                .map({ Action.saveNumber($0) })
                .eraseToSideWay()
        )
    }
// ...
}
```

## Installation

**OneWay** is only supported by Swift Package Manager.

To integrate **OneWay** into your Xcode project using Swift Package Manager, add it to the dependencies value of your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/DevYeom/OneWay", from: "0.1.0"),
]
```
