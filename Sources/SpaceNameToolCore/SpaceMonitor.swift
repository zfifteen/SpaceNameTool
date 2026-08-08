//
//  SpaceMonitor.swift
//  SpaceNameToolCore
//
//  Notification-first Space detection (tech spec §3).
//  SIP-safe: observes only; no injection.
//

import AppKit
import Foundation

public protocol SpaceMonitorDelegate: AnyObject {
    func spaceMonitorDidUpdate(active: SpaceRecord?, allActive: [SpaceRecord], diff: TopologyDiffResult)
    func spaceMonitorDegraded(reason: String)
}

/// Observes Space topology and active Space changes.
public final class SpaceMonitor {
    public weak var delegate: SpaceMonitorDelegate?

    private let nameStore: NameStore
    private let notificationCenter: NotificationCenter
    private let workspace: NSWorkspace

    private var isRunning = false
    private var pollTimer: Timer?
    private var usingPollFallback = false
    private var lastActiveManagedID: UInt64?
    private var lastActivePersistentID: String?
    private var degradedReason: String?
    private var notificationEventCount = 0

    /// After this many seconds without a notification-driven change while CGS active id drifts, enable 1Hz poll.
    public var pollWatchdogSeconds: TimeInterval = 30

    public init(
        nameStore: NameStore,
        workspace: NSWorkspace = .shared,
        notificationCenter: NotificationCenter? = nil
    ) {
        self.nameStore = nameStore
        self.workspace = workspace
        self.notificationCenter = notificationCenter ?? workspace.notificationCenter
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(distributedSpaceSwitch(_:)),
            name: Notification.Name("com.apple.spaces.switch"),
            object: nil
        )

        refresh(reason: "start")

        if !CGSPrivate.isAvailable {
            let reason = CGSPrivate.availabilityError?.description
                ?? "CGS read symbols unavailable"
            degradedReason = reason
            delegate?.spaceMonitorDegraded(reason: reason)
            enablePollFallbackIfNeeded(force: true)
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
        usingPollFallback = false
    }

    /// Forces a topology + active refresh.
    public func refresh(reason: String = "manual") {
        if reason == "activeSpaceDidChange" || reason == "com.apple.spaces.switch" {
            notificationEventCount += 1
        }

        let liveResult = CGSPrivate.copyLiveSpaces()
        let live: [LiveSpaceNode]
        switch liveResult {
        case .success(let nodes):
            live = nodes
        case .failure(let error):
            let message = "Spaces API unavailable — names may shift until update. (\(error))"
            degradedReason = message
            delegate?.spaceMonitorDegraded(reason: message)
            live = degradedPlaceholderLiveSpaces()
        }

        let diff = nameStore.applyLiveTopology(live)
        let activeManaged = CGSPrivate.activeSpaceID().value
        lastActiveManagedID = activeManaged

        let activeRecord = resolveActiveRecord(
            activeManaged: activeManaged,
            activeRecords: diff.activeRecords
        )
        lastActivePersistentID = activeRecord?.persistentID

        delegate?.spaceMonitorDidUpdate(
            active: activeRecord,
            allActive: diff.activeRecords,
            diff: diff
        )
    }

    public func currentActiveRecord() -> SpaceRecord? {
        let activeManaged = CGSPrivate.activeSpaceID().value
        return resolveActiveRecord(
            activeManaged: activeManaged,
            activeRecords: nameStore.allRecords(includeArchived: false)
        )
    }

    /// Resolves the active SpaceRecord from managed id, with index fallback.
    public static func resolveActiveRecord(
        activeManaged: UInt64?,
        activeRecords: [SpaceRecord]
    ) -> SpaceRecord? {
        if let activeManaged {
            if let match = activeRecords.first(where: { $0.managedSpaceID == activeManaged }) {
                return match
            }
        }
        // Degraded: prefer lowest index on main-ish display (first in sorted list).
        return activeRecords.sorted { $0.lastSeenIndex < $1.lastSeenIndex }.first
    }

    // MARK: - Notifications

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        refresh(reason: "activeSpaceDidChange")
    }

    @objc private func distributedSpaceSwitch(_ notification: Notification) {
        refresh(reason: "com.apple.spaces.switch")
    }

    /// Enables 1Hz poll only when notifications appear dead or CGS degraded.
    public func enablePollFallbackIfNeeded(force: Bool = false) {
        guard force || degradedReason != nil else { return }
        guard pollTimer == nil else { return }
        usingPollFallback = true
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func pollTick() {
        let current = CGSPrivate.activeSpaceID().value
        if current != lastActiveManagedID {
            refresh(reason: "poll")
        }
    }

    private func resolveActiveRecord(
        activeManaged: UInt64?,
        activeRecords: [SpaceRecord]
    ) -> SpaceRecord? {
        Self.resolveActiveRecord(activeManaged: activeManaged, activeRecords: activeRecords)
    }

    private func degradedPlaceholderLiveSpaces() -> [LiveSpaceNode] {
        let existing = nameStore.allRecords(includeArchived: false)
        if existing.isEmpty {
            return [
                LiveSpaceNode(
                    managedSpaceID: nil,
                    index: 0,
                    display: .main,
                    spaceUUID: nil
                )
            ]
        }
        return existing.map { record in
            LiveSpaceNode(
                managedSpaceID: record.managedSpaceID,
                index: record.lastSeenIndex,
                display: record.display,
                spaceUUID: nil
            )
        }
    }
}

private extension Result where Failure == CGSPrivate.ResolveError {
    var value: Success? {
        switch self {
        case .success(let v): return v
        case .failure: return nil
        }
    }
}
