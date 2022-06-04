import Foundation

/// Determines which thread environment Way will be working on.
public enum ThreadOption {
    /// Run on current thread. It needs to ensure that all actions run on the same thread.
    case current

    /// It guarantees Way is thread-safe. Use only when absolutely necessary.
    case threadSafe
}
