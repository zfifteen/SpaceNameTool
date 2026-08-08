//
//  DebouncedAction.swift
//  SpaceNameToolCore
//
//  Debounces work (e.g. NameStore writes from config TextFields — tech spec §4.2, 200ms).
//

import Foundation

/// Coalesces rapid calls into a single delayed execution on a queue.
public final class DebouncedAction: @unchecked Sendable {
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var workItem: DispatchWorkItem?

    public init(delay: TimeInterval = 0.2, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    /// Schedules `action`, cancelling any previously scheduled run.
    public func schedule(_ action: @escaping () -> Void) {
        lock.lock()
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Cancels a pending action without running it.
    public func cancel() {
        lock.lock()
        workItem?.cancel()
        workItem = nil
        lock.unlock()
    }
}
