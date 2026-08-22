//
//  RSVP.swift
//  Lurelia
//
//  A user's RSVP state on a SharedEvent. One RSVP per (event, user). Kept
//  separate from Attendee so the aggregate counts (going / interested /
//  declined) can be computed without walking the attendee list, and so a
//  user's RSVP state can change without touching their attendee row.
//

import Foundation
import SwiftData

@Model
final class RSVP {
    var id: UUID = UUID()
    var remoteID: String?

    var userID: String = ""
    var displayName: String = ""
    var avatarURL: String?

    /// Backing storage for `RSVPStatus`.
    var statusRaw: String = RSVPStatus.pending.rawValue

    /// Free-text note attached to the RSVP — used e.g. to say "bringing +1".
    var note: String?
    var plusOneCount: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(
        userID: String = "",
        displayName: String = "",
        status: RSVPStatus = .pending,
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.userID = userID
        self.displayName = displayName
        self.statusRaw = status.rawValue
        self.event = event
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension RSVP {
    var status: RSVPStatus {
        get { RSVPStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
