//
//  Permissions.swift
//  Lurelia
//
//  Per-event permission grant. One-to-one with SharedEvent. Fine-grained
//  booleans here; coarse role level lives on `AttendeeRole`.
//

import Foundation
import SwiftData

@Model
final class Permissions {
    var id: UUID = UUID()
    var remoteID: String?

    /// Guests can create posts on the event timeline. Off by default.
    var allowGuestPosts: Bool = false

    /// Guests can invite new attendees. Off by default.
    var allowGuestInvites: Bool = false

    /// Guests can add or remove comments. On by default.
    var allowComments: Bool = true

    /// Guests can change their RSVP after joining. On by default.
    var allowRSVPChanges: Bool = true

    /// Join requests require host approval before becoming Members.
    var requireApprovalToJoin: Bool = false

    /// Whether attendee list is visible to non-hosts.
    var showAttendeeList: Bool = true

    /// Whether comments can be posted by attendees whose RSVP is Declined.
    var allowDeclinedComments: Bool = false

    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(event: SharedEvent? = nil) {
        self.id = UUID()
        self.event = event
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

extension Permissions {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
