//
//  Invitation.swift
//  Lurelia
//
//  A pending or completed invitation to join a SharedEvent. Distinct from
//  Attendee — a person may have multiple invitations across events, and an
//  invitation may exist for an email address that isn't yet a user.
//

import Foundation
import SwiftData

@Model
final class Invitation {
    var id: UUID = UUID()
    var remoteID: String?
    var inviteToken: String = ""

    var senderUserID: String = ""
    var senderDisplayName: String = ""

    /// Recipient identity. userID is set when the invite is directed at an
    /// existing user; email is set when the invite is sent by address; both
    /// can be present for known users invited by email as well.
    var recipientUserID: String?
    var recipientDisplayName: String?
    var recipientEmail: String?

    /// Backing storage for `InvitationStatus`.
    var statusRaw: String = InvitationStatus.pending.rawValue

    /// Backing storage for `InvitationChannel` — how the invite was sent.
    var channelRaw: String = InvitationChannel.inApp.rawValue

    var message: String?
    var sentAt: Date = Date()
    var respondedAt: Date?
    var expiresAt: Date?

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(
        inviteToken: String = UUID().uuidString,
        senderUserID: String = "",
        senderDisplayName: String = "",
        recipientUserID: String? = nil,
        recipientEmail: String? = nil,
        channel: InvitationChannel = .inApp,
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.inviteToken = inviteToken
        self.senderUserID = senderUserID
        self.senderDisplayName = senderDisplayName
        self.recipientUserID = recipientUserID
        self.recipientEmail = recipientEmail
        self.channelRaw = channel.rawValue
        self.event = event
        self.sentAt = Date()
    }
}

extension Invitation {
    var status: InvitationStatus {
        get { InvitationStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var channel: InvitationChannel {
        get { InvitationChannel(rawValue: channelRaw) ?? .inApp }
        set { channelRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }
}
