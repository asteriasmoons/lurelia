//
//  CommentReply.swift
//  Lurelia
//
//  A threaded reply to a top-level `Comment`. Kept as a separate model so
//  discussion queries can page top-level and reply threads independently.
//

import Foundation
import SwiftData

@Model
final class CommentReply {
    var id: UUID = UUID()
    var remoteID: String?

    var authorUserID: String = ""
    var authorDisplayName: String = ""
    var authorAvatarURL: String?

    var body: String = ""
    var mentionedUserIDs: [String] = []

    var createdAt: Date = Date()
    var editedAt: Date?
    var deletedAt: Date?

    var likesCount: Int = 0

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var parent: Comment?

    @Relationship(deleteRule: .cascade, inverse: \CommentReaction.reply)
    var reactions: [CommentReaction]?

    init(
        authorUserID: String = "",
        authorDisplayName: String = "",
        body: String = "",
        parent: Comment? = nil
    ) {
        self.id = UUID()
        self.authorUserID = authorUserID
        self.authorDisplayName = authorDisplayName
        self.body = body
        self.parent = parent
        self.createdAt = Date()
    }
}

extension CommentReply {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isDeleted: Bool { deletedAt != nil }
    var isEdited: Bool { editedAt != nil }
}
