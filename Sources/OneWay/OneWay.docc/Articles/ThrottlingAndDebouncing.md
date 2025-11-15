# Throttling and Debouncing

Controlling the timing of events using `throttle` and `debounce`.

## Overview

**OneWay** provides `throttle` and `debounce` to control how frequently an effect can emit values. These are useful for managing events that can occur in rapid succession, such as user input or notifications.

### Throttling

Throttling limits the emission of values to a specified time interval. For example, if you throttle an effect to once per second, it will emit the first value and then ignore all subsequent values for the next second.

To use `throttle`, you first need to define a `Hashable` identifier for the effect.

```swift
enum ThrottleID {
    case button
}
```

Then, apply the `throttle` modifier to your effect.

```swift
func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
    switch action {
    case .perform:
        return .just(.increment)
            .throttle(id: ThrottleID.button, for: .seconds(1), latest: false)
    // ...
    }
}
```

### Debouncing

Debouncing delays the emission of values until a specified time has passed without any new values being emitted. This is useful for handling user input, such as in a search field, where you only want to perform a search after the user has stopped typing.

To use `debounce`, you also need a `Hashable` identifier.

```swift
enum DebounceID {
    case searchText
}
```

Then, apply the `debounce` modifier to your effect.

```swift
func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
    switch action {
    case let .search(text):
        return .single {
            let result = await api.request(text)
            return .setResult(result)
        }
        .debounce(id: DebounceID.searchText, for: .milliseconds(500))
    // ...
    }
}
```

By using `throttle` and `debounce`, you can effectively control the flow of events in your application, improving performance and user experience.
