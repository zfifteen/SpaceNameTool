//
//  NameStore.swift
//  SpaceNameToolCore
//
//  Persists custom Space names with robust topology keying (tech spec §2).
//  Storage: Application Support plist + JSON export copy.
//  SIP-safe: user domain only; no system process writes.
//

import Foundation

/// On-disk envelope for versioned persistence.
public struct NameStoreDocument: Codable, Equatable, Sendable {
    public var version: Int
    public var nextCreationOrder: Int
    public var records: [SpaceRecord]

    public init(version: Int = 1, nextCreationOrder: Int = 1, records: [SpaceRecord] = []) {
        self.version = version
        self.nextCreationOrder = nextCreationOrder
        self.records = records
    }
}

/// Loads and saves custom Space names; runs topology reconciliation.
public final class NameStore: @unchecked Sendable {
    public static let defaultDirectoryName = "SpaceNameTool"
    public static let plistFileName = "names.plist"
    public static let jsonFileName = "names.json"

    private let fileManager: FileManager
    private let directoryURL: URL
    private let queue = DispatchQueue(label: "com.velocityworks.SpaceNameTool.NameStore")

    private var document: NameStoreDocument
    private var lastDiff: TopologyDiffResult?

    public var supportDirectoryURL: URL { directoryURL }

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = base.appendingPathComponent(Self.defaultDirectoryName, isDirectory: true)
        }
        self.document = NameStoreDocument()
        loadFromDisk()
    }

    // MARK: - Queries

    public func allRecords(includeArchived: Bool = false) -> [SpaceRecord] {
        queue.sync {
            if includeArchived {
                return document.records
            }
            return document.records.filter { !$0.archived }
        }
    }

    public func record(persistentID: String) -> SpaceRecord? {
        queue.sync {
            document.records.first { $0.persistentID == persistentID }
        }
    }

    public func record(managedSpaceID: UInt64) -> SpaceRecord? {
        queue.sync {
            document.records.first {
                !$0.archived && $0.managedSpaceID == managedSpaceID
            }
        }
    }

    /// Resolves display name for the active managed space id, if known.
    public func displayName(forManagedSpaceID managedSpaceID: UInt64?) -> String? {
        guard let managedSpaceID else { return nil }
        return record(managedSpaceID: managedSpaceID)?.displayName
    }

    public func lastTopologyDiff() -> TopologyDiffResult? {
        queue.sync { lastDiff }
    }

    // MARK: - Mutations

    public func setCustomName(_ rawName: String, persistentID: String) {
        let name = NameSanitizer.sanitize(rawName)
        queue.sync {
            guard let index = document.records.firstIndex(where: { $0.persistentID == persistentID }) else {
                return
            }
            document.records[index].customName = name
            persistLocked()
        }
    }

    public func resetAllNames() {
        queue.sync {
            for i in document.records.indices {
                document.records[i].customName = ""
            }
            persistLocked()
        }
    }

    /// Reconcile live topology into durable storage. Returns the diff for UI prompts.
    @discardableResult
    public func applyLiveTopology(_ live: [LiveSpaceNode], now: Date = Date()) -> TopologyDiffResult {
        queue.sync {
            var nextOrder = document.nextCreationOrder
            let diff = TopologyReconciler.reconcile(
                live: live,
                stored: document.records,
                now: now,
                nextCreationOrder: &nextOrder
            )
            document.nextCreationOrder = nextOrder

            // Replace active + merge archives: actives from diff, archives from diff,
            // plus any archive that was not in the input set (already in diff.archivedRecords).
            var byID: [String: SpaceRecord] = [:]
            for record in diff.activeRecords {
                byID[record.persistentID] = record
            }
            for record in diff.archivedRecords {
                byID[record.persistentID] = record
            }
            // Preserve unmatchedPreviouslyActive (still active but not live).
            for record in diff.unmatchedPreviouslyActive {
                byID[record.persistentID] = record
            }

            document.records = Array(byID.values).sorted { lhs, rhs in
                if lhs.archived != rhs.archived { return !lhs.archived && rhs.archived }
                if lhs.display.cgDirectDisplayID != rhs.display.cgDirectDisplayID {
                    return lhs.display.cgDirectDisplayID < rhs.display.cgDirectDisplayID
                }
                return lhs.lastSeenIndex < rhs.lastSeenIndex
            }

            // Cap total records defensively (security: limit count).
            if document.records.count > NameSanitizer.maxSpaceCount * 2 {
                document.records = Array(document.records.prefix(NameSanitizer.maxSpaceCount * 2))
            }

            lastDiff = diff
            persistLocked()
            return diff
        }
    }

    // MARK: - Export / import (FR-9)

    public func exportJSON() throws -> Data {
        try queue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(document)
        }
    }

    public func importJSON(_ data: Data, replace: Bool) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let incoming = try decoder.decode(NameStoreDocument.self, from: data)
        queue.sync {
            if replace {
                document = sanitizeDocument(incoming)
            } else {
                var byID = Dictionary(uniqueKeysWithValues: document.records.map { ($0.persistentID, $0) })
                for record in incoming.records {
                    byID[record.persistentID] = sanitizeRecord(record)
                }
                document.records = Array(byID.values)
                document.nextCreationOrder = max(document.nextCreationOrder, incoming.nextCreationOrder)
            }
            persistLocked()
        }
    }

    // MARK: - Disk

    private func loadFromDisk() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let plistURL = directoryURL.appendingPathComponent(Self.plistFileName)
        let jsonURL = directoryURL.appendingPathComponent(Self.jsonFileName)

        if let data = try? Data(contentsOf: plistURL),
           let doc = try? PropertyListDecoder().decode(NameStoreDocument.self, from: data) {
            document = sanitizeDocument(doc)
            return
        }
        if let data = try? Data(contentsOf: jsonURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let doc = try? decoder.decode(NameStoreDocument.self, from: data) {
                document = sanitizeDocument(doc)
            }
        }
    }

    private func persistLocked() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let plistURL = directoryURL.appendingPathComponent(Self.plistFileName)
        let jsonURL = directoryURL.appendingPathComponent(Self.jsonFileName)

        if let plistData = try? PropertyListEncoder().encode(document) {
            try? plistData.write(to: plistURL, options: [.atomic])
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let jsonData = try? encoder.encode(document) {
            try? jsonData.write(to: jsonURL, options: [.atomic])
        }
    }

    private func sanitizeDocument(_ doc: NameStoreDocument) -> NameStoreDocument {
        var copy = doc
        copy.records = doc.records.map(sanitizeRecord)
        if copy.nextCreationOrder < 1 {
            copy.nextCreationOrder = 1
        }
        return copy
    }

    private func sanitizeRecord(_ record: SpaceRecord) -> SpaceRecord {
        var copy = record
        copy.customName = NameSanitizer.sanitize(copy.customName)
        if copy.persistentID.isEmpty {
            copy.persistentID = UUID().uuidString
        }
        return copy
    }
}
