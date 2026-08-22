//
//  SharedEvent.swift
//  Lurelia
//
//  A socially-shared event. Distinct from `LureliaEvent` (personal calendar
//  entry) — a SharedEvent has a host, attendees, an invitation surface, a
//  discussion thread, host posts, and syncs with vox-api.
//
//  All properties use CloudKit-compatible defaults / optionals so this can
//  live in the same ModelContainer as the existing personal event schema.
//

import Foundation
import SwiftData

@Model
final class SharedEvent {
    // MARK: Identity
    var id: UUID = UUID()
    /// Server-side ID from vox-api. Nil until the first successful sync.
    var remoteID: String?
    var inviteToken: String?
    var shareCode: String?

    // MARK: Content
    var title: String = ""
    var eventDescription: String?
    var iconName: String?
    var colorHex: String = "#03dbfc"
    var timezoneIdentifier: String = TimeZone.current.identifier

    // MARK: Timing
    var startDate: Date = Date()
    var endDate: Date?
    var isAllDay: Bool = false

    // MARK: Location
    var locationName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?

    // MARK: Visibility
    /// Backing storage for `ShareVisibility`.
    var visibilityRaw: String = ShareVisibility.privateEvent.rawValue

    // MARK: Host
    var hostUserID: String = ""
    var hostDisplayName: String = ""
    var hostAvatarURL: String?

    // MARK: Lifecycle
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var cancelledAt: Date?
    var cancellationReason: String?

    // MARK: Sync
    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    // MARK: Relationships
    @Relationship(deleteRule: .cascade, inverse: \Attendee.event)
    var attendees: [Attendee]?

    @Relationship(deleteRule: .cascade, inverse: \RSVP.event)
    var rsvps: [RSVP]?

    @Relationship(deleteRule: .cascade, inverse: \Invitation.event)
    var invitations: [Invitation]?

    @Relationship(deleteRule: .cascade, inverse: \Comment.event)
    var comments: [Comment]?

    @Relationship(deleteRule: .cascade, inverse: \EventPost.event)
    var posts: [EventPost]?

    @Relationship(deleteRule: .cascade, inverse: \Announcement.event)
    var announcements: [Announcement]?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.event)
    var attachments: [Attachment]?

    @Relationship(deleteRule: .cascade, inverse: \EventArtwork.event)
    var artwork: [EventArtwork]?

    @Relationship(deleteRule: .cascade, inverse: \Host.event)
    var hosts: [Host]?

    @Relationship(deleteRule: .cascade, inverse: \Permissions.event)
    var permissions: Permissions?

    @Relationship(deleteRule: .cascade, inverse: \NotificationSubscription.event)
    var notificationSubscriptions: [NotificationSubscription]?

    @Relationship(deleteRule: .nullify, inverse: \SharedCalendar.events)
    var calendars: [SharedCalendar]?

    // MARK: Init
    init(
        title: String = "",
        hostUserID: String = "",
        hostDisplayName: String = "",
        startDate: Date = Date(),
        visibility: ShareVisibility = .privateEvent,
        colorHex: String = "#03dbfc"
    ) {
        self.id = UUID()
        self.title = title
        self.hostUserID = hostUserID
        self.hostDisplayName = hostDisplayName
        self.startDate = startDate
        self.visibilityRaw = visibility.rawValue
        self.colorHex = colorHex
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

extension SharedEvent {
    var visibility: ShareVisibility {
        get { ShareVisibility(rawValue: visibilityRaw) ?? .privateEvent }
        set { visibilityRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isCancelled: Bool { cancelledAt != nil }
}
