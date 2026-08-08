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
    private var degradedReason: String?

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

        // Distributed fallback used by some macOS builds.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(distributedSpaceSwitch(_:)),
            name: Notification.Name("com.apple.spaces.switch"),
            object: nil
        )

        // Initial scan.
        refresh(reason: "start")

        // If CGS unavailable, degrade and optionally poll index-only later.
        if !CGSPrivate.isAvailable {
            let reason = CGSPrivate.availabilityError?.description
                ?? "CGS read symbols unavailable"
            degradedReason = reason
            delegate?.spaceMonitorDegraded(reason: reason)
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Forces a topology + active refresh.
    public func refresh(reason: String = "manual") {
        _ = reason
        let liveResult = CGSPrivate.copyLiveSpaces()
        let live: [LiveSpaceNode]
        switch liveResult {
        case .success(let nodes):
            live = nodes
            if usingPollFallback {
                // Notifications may have recovered; keep poll as safety only if we started it.
            }
        case .failure(let error):
            let message = "Spaces API unavailable — names may shift until update. (\(error))"
            degradedReason = message
            delegate?.spaceMonitorDegraded(reason: message)
            // Index-only degradation: invent a single placeholder on main display if store empty.
            live = degradedPlaceholderLiveSpaces()
        }

        let diff = nameStore.applyLiveTopology(live)
        let activeManaged = CGSPrivate.activeSpaceID().value
        lastActiveManagedID = activeManaged

        let activeRecord: SpaceRecord?
        if let activeManaged {
            activeRecord = nameStore.record(managedSpaceID: activeManaged)
                ?? diff.activeRecords.first { $0.managedSpaceID == activeManaged }
        } else {
            // Fallback: first record with lastSeenIndex matching unknown — use lowest index on main.
            activeRecord = diff.activeRecords.first
        }

        delegate?.spaceMonitorDidUpdate(
            active: activeRecord,
            allActive: diff.activeRecords,
            diff: diff
        )
    }

    public func currentActiveRecord() -> SpaceRecord? {
        if let id = CGSPrivate.activeSpaceID().value {
            return nameStore.record(managedSpaceID: id)
        }
        return nameStore.allRecords().first
    }

    // MARK: - Notifications

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        refresh(reason: "activeSpaceDidChange")
    }

    @objc private func distributedSpaceSwitch(_ notification: Notification) {
        refresh(reason: "com.apple.spaces.switch")
    }

    /// Enables 1Hz poll only when notifications appear dead (caller policy).
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

    private func degradedPlaceholderLiveSpaces() -> [LiveSpaceNode] {
        // Keep existing actives' indices as synthetic live nodes so we do not wipe names.
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
