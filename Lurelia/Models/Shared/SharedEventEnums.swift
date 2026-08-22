//
//  SharedEventEnums.swift
//  Lurelia
//
//  Value-type enums shared across every SharedEvent-related SwiftData model.
//  Enums are stored as raw String on their owning model (see e.g.
//  `SharedEvent.visibilityRaw`) and exposed as a computed `.visibility`
//  accessor so SwiftData / CloudKit sees a stable primitive.
//

import Foundation

// MARK: - Visibility

/// Who can discover / open a shared event.
enum ShareVisibility: String, Codable, CaseIterable {
    case privateEvent = "private"
    case linkOnly = "link"
    case publicEvent = "public"
}

// MARK: - Attendee Role

/// A person's structural role on the event, independent of RSVP.
enum AttendeeRole: String, Codable, CaseIterable {
    case host          // Primary owner. Exactly one per event unless transferred.
    case coHost        // Elevated permissions, appointed by host.
    case member        // Joined and confirmed.
    case invited       // Sent an invitation, has not joined.
    case pending       // Requested to join, awaiting host approval.
}

// MARK: - RSVP Status

enum RSVPStatus: String, Codable, CaseIterable {
    case going
    case interested
    case declined
    case pending
}

// MARK: - Invitation

enum InvitationStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
    case expired
    case revoked
}

enum InvitationChannel: String, Codable, CaseIterable {
    case inApp
    case email
    case link
    case shareSheet
    case qrCode
}

// MARK: - Reactions

/// Reaction kinds available on comments and replies.
enum ReactionKind: String, Codable, CaseIterable {
    case like
    case heart
    case celebrate
    case laugh
    case wow
    case sad
}

// MARK: - Attachments

enum AttachmentKind: String, Codable, CaseIterable {
    case image
    case file
    case video
    case audio
}

// MARK: - Sync

enum SyncOperationType: String, Codable, CaseIterable {
    case create
    case update
    case delete
}

enum SyncStatus: String, Codable, CaseIterable {
    case idle          // In sync with the server.
    case pending       // Local mutation waiting to be sent.
    case sending       // In flight to the server.
    case failed        // Retryable failure — will be replayed.
    case conflict      // Server rejected due to remote change. Needs merge.
}

// MARK: - Notifications

/// Which shared-event events a subscription is opted into.
/// Bit-mask-able via `Set<NotificationKind>` but stored as a string array
/// for CloudKit friendliness.
enum NotificationKind: String, Codable, CaseIterable {
    case invitation
    case join
    case hostPost
    case comment
    case reply
    case announcement
    case edit
    case cancellation
    case timeChanged
    case locationChanged
    case rsvpChanged
    case ownershipTransferred
}

// MARK: - Apple Calendar sync

enum SharedEventCalendarSyncMode: String, Codable, CaseIterable {
    case off
    case importOnly     // Pull remote → local only.
    case exportOnly     // Push local → remote only.
    case mirror         // One-shot copy in either direction.
    case oneWay         // Continuous one-directional.
    case twoWay         // Bidirectional with conflict handling.
}

// MARK: - Permission Level

/// A coarse per-event capability grant. Fine-grained booleans live on the
/// `Permissions` model — this enum is used for quick UI checks.
enum PermissionLevel: String, Codable, CaseIterable {
    case owner
    case moderator
    case member
    case viewer
}
