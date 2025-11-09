//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// A set of options that determines what information is logged by a ``Store``.
public struct LoggingOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Logs all actions sent to the store.
    public static let action = LoggingOptions(rawValue: 1 << 0)

    /// Logs all state changes in the store.
    public static let state = LoggingOptions(rawValue: 1 << 1)

    /// Logs all actions and state changes.
    public static let all: LoggingOptions = [.action, .state]

    /// Disables all logging.
    public static let none: LoggingOptions = []
}
