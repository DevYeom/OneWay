# Testing

Using OneWay for Unit Testing.

## Overview

**OneWay** provides the `expect` and `xctExpect` functions to help you write concise and clear tests. These functions work asynchronously, allowing you to verify if the state updates as expected.

### When using `Testing`

You can use the `expect` function to easily check the state value.

```swift
@Test
func incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2)
}
```

### When using `XCTest`

The `xctExpect` function is used within an XCTest environment to assert the state value.

```swift
func test_incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.xctExpect(\.count, 2)
}
```

## Specifying timeout if needed

Both functions include a `timeout` parameter, which specifies the maximum amount of time (in seconds) to wait for the state to finish processing before timing out. The default value is 2 seconds.

### When using `Testing`

```swift
@Test
func incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.expect(\.count, 2, timeout: 0.1)
}
```

### When using `XCTest`

```swift
func test_incrementTwice() async {
    await sut.send(.increment)
    await sut.send(.increment)

    await sut.xctExpect(\.count, 2, timeout: 5)
}
```

## Failed Tests

When a test fails, the output provides detailed information about the failure, making it easy to diagnose issues. Below are example screenshots showing how a failure appears for both `expect` and `xctExpect` functions.

### Failure with `expect`

![failure with expect](expect-failure.png)

### Failure with `xctExpect`

![failure with xctExpect](xct-expect-failure.png)
