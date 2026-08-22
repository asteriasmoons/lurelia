//
//  CommentReaction.swift
//  Lurelia
//
//  A single user's reaction on a Comment or a CommentReply. One or the
//  other relationship is set; never both. Enforced by the service layer
//  since SwiftData doesn't express xor constraints natively.
//

import Foundation
import SwiftData

@Model
final class CommentReaction {
    var id: UUID = UUID()
    var remoteID: String?

    var userID: String = ""
    var userDisplayName: String = ""

    /// Backing storage for `ReactionKind`.
    var kindRaw: String = ReactionKind.like.rawValue

    var createdAt: Date = Date()

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var comment: Comment?
    var reply: CommentReply?

    init(
        userID: String = "",
        userDisplayName: String = "",
        kind: ReactionKind = .like,
        comment: Comment? = nil,
        reply: CommentReply? = nil
    ) {
        self.id = UUID()
        self.userID = userID
        self.userDisplayName = userDisplayName
        self.kindRaw = kind.rawValue
        self.comment = comment
        self.reply = reply
        self.createdAt = Date()
    }
}

extension CommentReaction {
    var kind: ReactionKind {
        get { ReactionKind(rawValue: kindRaw) ?? .like }
        set { kindRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
