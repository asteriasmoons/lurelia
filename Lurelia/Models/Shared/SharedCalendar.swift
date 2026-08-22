//
//  SharedCalendar.swift
//  Lurelia
//
//  A named grouping of SharedEvents — the shared-space analog of
//  `LureliaCalendar`. One event can appear in multiple shared calendars
//  (many-to-many), matching the "Multiple calendars shared event support"
//  requirement.
//

import Foundation
import SwiftData

@Model
final class SharedCalendar {
    var id: UUID = UUID()
    var remoteID: String?
    var name: String = ""
    var calendarDescription: String?
    var colorHex: String = "#03dbfc"
    var iconName: String?

    var ownerUserID: String = ""
    var memberUserIDs: [String] = []

    /// See `ShareVisibility`. Determines who can discover the calendar itself.
    var visibilityRaw: String = ShareVisibility.privateEvent.rawValue

    var isHidden: Bool = false
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    /// Inverse of `SharedEvent.calendars`.
    var events: [SharedEvent]?

    init(
        name: String = "",
        ownerUserID: String = "",
        colorHex: String = "#03dbfc",
        visibility: ShareVisibility = .privateEvent
    ) {
        self.id = UUID()
        self.name = name
        self.ownerUserID = ownerUserID
        self.colorHex = colorHex
        self.visibilityRaw = visibility.rawValue
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

extension SharedCalendar {
    var visibility: ShareVisibility {
        get { ShareVisibility(rawValue: visibilityRaw) ?? .privateEvent }
        set { visibilityRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
