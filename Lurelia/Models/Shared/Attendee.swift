//
//  Attendee.swift
//  Lurelia
//
//  A person's presence on a SharedEvent. Role is structural (host / cohost /
//  member / invited / pending). RSVP status lives on the `RSVP` model —
//  a member's RSVP can independently be "interested" without changing their
//  attendee role.
//

import Foundation
import SwiftData

@Model
final class Attendee {
    var id: UUID = UUID()
    var remoteID: String?

    var userID: String = ""
    var displayName: String = ""
    var avatarURL: String?

    /// Backing storage for `AttendeeRole`.
    var roleRaw: String = AttendeeRole.member.rawValue

    var joinedAt: Date?
    var removedAt: Date?
    var lastSeenAt: Date?

    /// Free-text moderator note, host-only. Kept out of any user-facing view.
    var moderatorNote: String?

    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(
        userID: String = "",
        displayName: String = "",
        role: AttendeeRole = .member,
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.userID = userID
        self.displayName = displayName
        self.roleRaw = role.rawValue
        self.event = event
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

extension Attendee {
    var role: AttendeeRole {
        get { AttendeeRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isActive: Bool { removedAt == nil }
}
