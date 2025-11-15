# Debugging

Using the `debug()` function to log actions and state changes.

## Overview

**OneWay** provides a `debug()` function on both `Store` and `ViewStore` to help you understand how data flows through your application. When enabled, it logs actions and state changes to the console, making it easier to trace the sequence of events and diagnose issues.

The `debug()` function takes a `LoggingOptions` parameter, which can be one of the following:

- `.action`: Logs only the actions that are sent.
- `.state`: Logs only the state changes that occur.
- `.all`: Logs both actions and state changes.
- `.none`: Disables all logging.

### Using with Store

You can configure logging for a `Store` instance either during initialization or by calling `debug()` later. This is useful when you are working with business logic outside of the UI layer.

**Configuring logging during initialization:**

```swift
let store = Store(
    reducer: CountingReducer(),
    state: CountingReducer.State(number: 0),
    loggingOptions: .all // Enable logging for all actions and state changes from the start
)

await store.send(.increment)
await store.send(.decrement)
```

**Configuring logging after initialization:**

```swift
let store = Store(
    reducer: CountingReducer(),
    state: CountingReducer.State(number: 0)
)

// Enable logging for all actions and state changes
await store.debug(.all)

await store.send(.increment)
await store.send(.decrement)

// Disable logging
await store.debug(.none)
```

When running the code above, you will see logs in the console similar to this:

```
[2025-11-15T12:34:56.789Z] Action: increment
[2025-11-15T12:34:56.790Z] State changed:
- State(number: 0)
+ State(number: 1)
[2025-11-15T12:34:56.791Z] Action: decrement
[2025-11-15T12:34:56.792Z] State changed:
- State(number: 1)
+ State(number: 0)
```

### Using with ViewStore

When working with SwiftUI, you can use the `debug()` modifier on a `ViewStore` to enable logging. This is particularly helpful for debugging UI-related state changes.

**Configuring logging during initialization:**

```swift
struct CounterView: View {
    @StateObject private var store = ViewStore(
        reducer: CountingReducer(),
        state: CountingReducer.State(number: 0)
    )
    .debug(.all) // Enable logging for this view's store

    var body: some View {
        VStack {
            Text("\(store.state.number)")
            Button("Increment") {
                store.send(.increment)
            }
        }
    }
}
```

**Configuring logging after initialization:**

```swift
struct AnotherCounterView: View {
    @StateObject private var store = ViewStore(
        reducer: CountingReducer(),
        state: CountingReducer.State(number: 0)
    )

    var body: some View {
        VStack {
            Text("\(store.state.number)")
            Button("Increment") {
                store.send(.increment)
            }
            Button("Toggle Logging") {
                // Dynamically enable or disable logging
                if store.loggingOptions.contains(.all) {
                    store.debug(.none)
                } else {
                    store.debug(.all)
                }
            }
        }
    }
}
```

With this setup, any interaction that triggers an action or a state change in `CounterView` will be logged to the console, providing a clear picture of what is happening in your UI.
