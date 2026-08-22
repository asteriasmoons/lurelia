//
//  SharedEventAppleMirror.swift
//  Lurelia
//
//  Local, per-device tracking of the Apple Calendar mirror for a shared
//  event. Kept out of the server DTOs because the mapping is device-
//  specific — each device that mirrors a given shared event may map it
//  to a different EKEvent under a different EKCalendar.
//
//  One row per (sharedEventRemoteID, deviceID). CloudKit-compatible
//  defaults so the row is safe to have in the same store as the rest
//  of the shared event models.
//

import Foundation
import SwiftData

@Model
final class SharedEventAppleMirror {
    var id: UUID = UUID()

    /// Server-side ID of the SharedEvent this mirror row represents.
    var sharedEventRemoteID: String = ""

    /// The EKEvent.eventIdentifier this shared event is mirrored as, on
    /// this device. Empty when the mirror is enabled but the first push
    /// hasn't run yet.
    var appleEventIdentifier: String = ""

    /// The EKCalendar.calendarIdentifier the mirrored event was written
    /// into. Nil when the user hasn't picked a target calendar.
    var appleCalendarIdentifier: String?

    /// Backing storage for `SharedEventCalendarSyncMode`.
    var syncModeRaw: String = SharedEventCalendarSyncMode.off.rawValue

    /// The event's `modifiedAt` value on the server at the last sync.
    /// Used together with `lastAppleModifiedAt` for two-way conflict
    /// detection.
    var lastServerModifiedAt: Date?

    /// The EKEvent.lastModifiedDate we last observed. Two-way conflict
    /// resolver compares this against the current EKEvent to decide if
    /// Apple has changes we haven't reflected yet.
    var lastAppleModifiedAt: Date?

    var lastSyncedAt: Date?
    var lastSyncError: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        sharedEventRemoteID: String = "",
        appleEventIdentifier: String = "",
        appleCalendarIdentifier: String? = nil,
        syncMode: SharedEventCalendarSyncMode = .off,
    ) {
        self.id = UUID()
        self.sharedEventRemoteID = sharedEventRemoteID
        self.appleEventIdentifier = appleEventIdentifier
        self.appleCalendarIdentifier = appleCalendarIdentifier
        self.syncModeRaw = syncMode.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension SharedEventAppleMirror {
    var syncMode: SharedEventCalendarSyncMode {
        get {
            SharedEventCalendarSyncMode(rawValue: syncModeRaw) ?? .off
        }
        set {
            syncModeRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var isEnabled: Bool { syncMode != .off }
}
