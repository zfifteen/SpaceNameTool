//
//  NameSanitizer.swift
//  SpaceNameToolCore
//
//  Validates custom names (security analysis §4 / §6).
//

import Foundation

public enum NameSanitizer {
    public static let maxLength = 50
    public static let maxSpaceCount = 16 * 6 // FR-10 upper bound

    /// Trims, strips control characters, normalizes, enforces max length.
    public static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let strippedScalars = trimmed.unicodeScalars.filter { scalar in
            let v = scalar.value
            // Keep tab out; strip C0 controls and DEL; strip most C1.
            if v < 0x20 { return false }
            if v == 0x7F { return false }
            if v >= 0x80 && v < 0xA0 { return false }
            return true
        }
        let stripped = String(String.UnicodeScalarView(strippedScalars))
        let normalized = stripped.precomposedStringWithCanonicalMapping
        if normalized.count <= maxLength {
            return normalized
        }
        let end = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return String(normalized[..<end])
    }
}
