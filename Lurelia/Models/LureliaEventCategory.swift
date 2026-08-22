//
//  LureliaEventCategory.swift
//  Lurelia
//
//  Predefined categories used by the event editor's category dropdown.
//  Not a @Model — the underlying LureliaEvent still stores the value as
//  `categoryName: String?` so old free-text values continue to load.
//

import Foundation

enum LureliaEventCategory: String, CaseIterable, Identifiable {
    case personal   = "Personal"
    case work       = "Work"
    case family     = "Family"
    case health     = "Health"
    case fitness    = "Fitness"
    case social     = "Social"
    case travel     = "Travel"
    case education  = "Education"
    case finance    = "Finance"
    case home       = "Home"
    case hobby      = "Hobby"
    case other      = "Other"

    var id: String { rawValue }

    /// Match a stored string against the enum case-insensitively. Returns nil
    /// for unknown values so old free-text categories don't silently drop.
    static func matching(_ rawValue: String?) -> LureliaEventCategory? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return allCases.first { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
}
