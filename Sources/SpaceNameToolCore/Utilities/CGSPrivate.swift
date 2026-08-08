//
//  CGSPrivate.swift
//  SpaceNameToolCore
//
//  Read-only dlsym wrappers for CGS / SkyLight (tech spec §3, security §4).
//
//  HARD:
//  - Load symbols dynamically from SkyLight; no link-time private dependency.
//  - Prefer read-only calls. Optional Space switch via CGSSetActiveSpace is in-process only
//    (full SIP retained; fail closed if symbol missing or call fails).
//  - Fail closed: missing symbols → nil / error, graceful degrade.
//  - Never inject into Dock or WindowServer.
//

import CoreFoundation
import CoreGraphics
import Darwin
import Foundation

public enum CGSPrivate {
    public enum ResolveError: Error, Equatable, CustomStringConvertible {
        case libraryUnavailable(String)
        case symbolNotFound(String)
        case callFailed(String)

        public var description: String {
            switch self {
            case .libraryUnavailable(let name): return "Library unavailable: \(name)"
            case .symbolNotFound(let name): return "Symbol not found: \(name)"
            case .callFailed(let name): return "Call failed: \(name)"
            }
        }
    }

    public typealias ConnectionID = UInt32

    private static let skyLightPath =
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"

    private static let lock = NSLock()
    private static var libraryHandle: UnsafeMutableRawPointer?
    private static var didAttemptLoad = false
    private static var loadError: ResolveError?

    // Function pointer types (read-only).
    private typealias CGSMainConnectionID_t = @convention(c) () -> Int32
    private typealias CGSCopyManagedDisplaySpaces_t = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CGSGetActiveSpace_t = @convention(c) (Int32) -> UInt64
    /// CGSSetActiveSpace(connection, spaceID) — optional; often a no-op for third-party apps.
    private typealias CGSSetActiveSpace_t = @convention(c) (Int32, UInt64) -> Int32
    /// CGSManagedDisplaySetCurrentSpace(connection, displayUUID, spaceID)
    private typealias CGSManagedDisplaySetCurrentSpace_t = @convention(c) (Int32, CFString, UInt64) -> Int32

    private static var mainConnectionIDFn: CGSMainConnectionID_t?
    private static var copyManagedDisplaySpacesFn: CGSCopyManagedDisplaySpaces_t?
    private static var getActiveSpaceFn: CGSGetActiveSpace_t?
    private static var setActiveSpaceFn: CGSSetActiveSpace_t?
    private static var managedDisplaySetCurrentSpaceFn: CGSManagedDisplaySetCurrentSpace_t?

    /// True when core read symbols resolved.
    public static var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        ensureLoadedLocked()
        return mainConnectionIDFn != nil && copyManagedDisplaySpacesFn != nil
    }

    /// Last library load failure, if any.
    public static var availabilityError: ResolveError? {
        lock.lock()
        defer { lock.unlock() }
        ensureLoadedLocked()
        return loadError
    }

    /// Resets cached function pointers (for tests).
    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        if let handle = libraryHandle {
            dlclose(handle)
        }
        libraryHandle = nil
        didAttemptLoad = false
        loadError = nil
        mainConnectionIDFn = nil
        copyManagedDisplaySpacesFn = nil
        getActiveSpaceFn = nil
        setActiveSpaceFn = nil
        managedDisplaySetCurrentSpaceFn = nil
    }

    /// True when at least one in-process Space switch symbol resolved (still runs under full SIP).
    public static var isSetActiveSpaceAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        ensureLoadedLocked()
        return setActiveSpaceFn != nil || managedDisplaySetCurrentSpaceFn != nil
    }

    public static func mainConnectionID() -> Result<ConnectionID, ResolveError> {
        lock.lock()
        ensureLoadedLocked()
        let fn = mainConnectionIDFn
        lock.unlock()

        guard let fn else {
            return .failure(loadError ?? .symbolNotFound("CGSMainConnectionID"))
        }
        let value = fn()
        if value < 0 {
            return .failure(.callFailed("CGSMainConnectionID"))
        }
        return .success(ConnectionID(bitPattern: value))
    }

    public static func activeSpaceID(connection: ConnectionID? = nil) -> Result<UInt64, ResolveError> {
        let conn: ConnectionID
        if let connection {
            conn = connection
        } else {
            switch mainConnectionID() {
            case .success(let c): conn = c
            case .failure(let e): return .failure(e)
            }
        }

        lock.lock()
        ensureLoadedLocked()
        let fn = getActiveSpaceFn
        lock.unlock()

        guard let fn else {
            return .failure(loadError ?? .symbolNotFound("CGSGetActiveSpace"))
        }
        let space = fn(Int32(bitPattern: conn))
        return .success(space)
    }

    /// Attempts to activate a Space by managed id in this process only (tech spec §4.4 step 1).
    ///
    /// Success means the active Space id actually changed (or already matched).
    /// A zero CGError with no effect is treated as failure so callers can fall back.
    public static func setActiveSpace(
        _ spaceID: UInt64,
        displayUUID: String? = nil,
        connection: ConnectionID? = nil
    ) -> Result<Void, ResolveError> {
        let conn: ConnectionID
        if let connection {
            conn = connection
        } else {
            switch mainConnectionID() {
            case .success(let c): conn = c
            case .failure(let e): return .failure(e)
            }
        }

        // Already there.
        if case .success(let current) = activeSpaceID(connection: conn), current == spaceID {
            return .success(())
        }

        lock.lock()
        ensureLoadedLocked()
        let setFn = setActiveSpaceFn
        let managedFn = managedDisplaySetCurrentSpaceFn
        lock.unlock()

        var attempted = false

        // Prefer display-scoped switch when we have a UUID (more reliable on multi-display).
        if let managedFn, let uuid = displayUUID, !uuid.isEmpty {
            attempted = true
            _ = managedFn(Int32(bitPattern: conn), uuid as CFString, spaceID)
            if case .success(let current) = activeSpaceID(connection: conn), current == spaceID {
                return .success(())
            }
        }

        if let setFn {
            attempted = true
            _ = setFn(Int32(bitPattern: conn), spaceID)
            // Brief settle — WindowServer updates are not always synchronous.
            usleep(30_000)
            if case .success(let current) = activeSpaceID(connection: conn), current == spaceID {
                return .success(())
            }
        }

        // Retry managed with "Main" identifier when UUID path was skipped/failed.
        if let managedFn {
            attempted = true
            for token in [displayUUID, "Main"].compactMap({ $0 }) where !token.isEmpty {
                _ = managedFn(Int32(bitPattern: conn), token as CFString, spaceID)
                usleep(30_000)
                if case .success(let current) = activeSpaceID(connection: conn), current == spaceID {
                    return .success(())
                }
            }
        }

        if !attempted {
            return .failure(.symbolNotFound("CGSSetActiveSpace / CGSManagedDisplaySetCurrentSpace"))
        }
        return .failure(.callFailed("Space switch symbols present but active Space did not change"))
    }

    /// Parses `CGSCopyManagedDisplaySpaces` into live nodes.
    public static func copyLiveSpaces() -> Result<[LiveSpaceNode], ResolveError> {
        let connection: ConnectionID
        switch mainConnectionID() {
        case .success(let c): connection = c
        case .failure(let e): return .failure(e)
        }

        lock.lock()
        ensureLoadedLocked()
        let fn = copyManagedDisplaySpacesFn
        lock.unlock()

        guard let fn else {
            return .failure(loadError ?? .symbolNotFound("CGSCopyManagedDisplaySpaces"))
        }

        guard let unmanaged = fn(Int32(bitPattern: connection)) else {
            return .failure(.callFailed("CGSCopyManagedDisplaySpaces returned nil"))
        }
        let array = unmanaged.takeRetainedValue() as [AnyObject]
        let nodes = parseManagedDisplaySpaces(array)
        return .success(nodes)
    }

    // MARK: - Parsing (pure; testable)

    /// Parses the CFArray dictionary shape used by CGS managed display spaces.
    public static func parseManagedDisplaySpaces(_ displays: [AnyObject]) -> [LiveSpaceNode] {
        var nodes: [LiveSpaceNode] = []

        for displayEntry in displays {
            guard let dict = displayEntry as? [String: Any] else { continue }

            let display = resolveDisplay(from: dict)
            let spaces = extractSpacesArray(from: dict)

            for (index, spaceEntry) in spaces.enumerated() {
                guard let spaceDict = spaceEntry as? [String: Any] else { continue }
                let managed = extractManagedSpaceID(from: spaceDict)
                let spaceUUID = spaceDict["uuid"] as? String
                    ?? spaceDict["UUID"] as? String
                nodes.append(
                    LiveSpaceNode(
                        managedSpaceID: managed,
                        index: index,
                        display: display,
                        spaceUUID: spaceUUID
                    )
                )
            }
        }
        return nodes
    }

    private static func extractSpacesArray(from dict: [String: Any]) -> [Any] {
        if let spaces = dict["Spaces"] as? [Any] {
            return spaces
        }
        if let spaces = dict["spaces"] as? [Any] {
            return spaces
        }
        return []
    }

    private static func extractManagedSpaceID(from spaceDict: [String: Any]) -> UInt64? {
        let keys = ["ManagedSpaceID", "id64", "SpaceID", "id"]
        for key in keys {
            if let value = spaceDict[key] as? UInt64 {
                return value
            }
            if let value = spaceDict[key] as? Int {
                return UInt64(value)
            }
            if let value = spaceDict[key] as? NSNumber {
                return value.uint64Value
            }
        }
        return nil
    }

    private static func resolveDisplay(from dict: [String: Any]) -> DisplayID {
        // "Display Identifier" is often a UUID string or "Main".
        let identifier = dict["Display Identifier"] as? String
            ?? dict["DisplayIdentifier"] as? String

        var cgID: UInt32 = CGMainDisplayID()
        var uuidString: String?
        var name = "Display"

        if let identifier {
            if identifier == "Main" {
                cgID = CGMainDisplayID()
                name = "Main"
                uuidString = DisplayID.from(cgDisplayID: cgID).uuidString
            } else {
                uuidString = identifier
                // Best-effort map UUID → CGDirectDisplayID.
                if let mapped = cgDisplayID(forUUIDString: identifier) {
                    cgID = mapped
                }
                name = identifier
            }
        }

        return DisplayID(cgDirectDisplayID: cgID, uuidString: uuidString, localizedName: name)
    }

    private static func cgDisplayID(forUUIDString uuidString: String) -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return nil
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else {
            return nil
        }
        for display in displays.prefix(Int(displayCount)) {
            let info = DisplayID.from(cgDisplayID: display)
            if info.uuidString == uuidString {
                return display
            }
        }
        return nil
    }

    // MARK: - dlsym load

    private static func ensureLoadedLocked() {
        if didAttemptLoad { return }
        didAttemptLoad = true

        guard let handle = dlopen(skyLightPath, RTLD_LAZY) else {
            let err = String(cString: dlerror())
            loadError = .libraryUnavailable("\(skyLightPath) (\(err))")
            return
        }
        libraryHandle = handle

        mainConnectionIDFn = symbol(handle, "CGSMainConnectionID")
        copyManagedDisplaySpacesFn = symbol(handle, "CGSCopyManagedDisplaySpaces")
        getActiveSpaceFn = symbol(handle, "CGSGetActiveSpace")
        setActiveSpaceFn = symbol(handle, "CGSSetActiveSpace")
        managedDisplaySetCurrentSpaceFn = symbol(handle, "CGSManagedDisplaySetCurrentSpace")

        if mainConnectionIDFn == nil {
            loadError = .symbolNotFound("CGSMainConnectionID")
        } else if copyManagedDisplaySpacesFn == nil {
            loadError = .symbolNotFound("CGSCopyManagedDisplaySpaces")
        }
        // getActiveSpace / set symbols are optional; callers degrade gracefully.
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}
