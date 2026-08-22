//
//  Comment.swift
//  Lurelia
//
//  Top-level comment on the SharedEvent discussion tab. Threaded replies
//  live in `CommentReply`. Reactions live in `CommentReaction`. Deletion is
//  soft (deletedAt) so replies remain readable in context.
//

import Foundation
import SwiftData

@Model
final class Comment {
    var id: UUID = UUID()
    var remoteID: String?

    var authorUserID: String = ""
    var authorDisplayName: String = ""
    var authorAvatarURL: String?

    var body: String = ""
    /// Cached user IDs mentioned via @handle in `body`. Server-authoritative.
    var mentionedUserIDs: [String] = []

    var createdAt: Date = Date()
    var editedAt: Date?
    var deletedAt: Date?

    var isPinned: Bool = false
    var likesCount: Int = 0
    var replyCount: Int = 0

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    /// Optional attach point when the discussion is scoped to a specific
    /// host post rather than the event overall. Nil for event-level threads.
    var post: EventPost?

    @Relationship(deleteRule: .cascade, inverse: \CommentReply.parent)
    var replies: [CommentReply]?

    @Relationship(deleteRule: .cascade, inverse: \CommentReaction.comment)
    var reactions: [CommentReaction]?

    init(
        authorUserID: String = "",
        authorDisplayName: String = "",
        body: String = "",
        event: SharedEvent? = nil,
        post: EventPost? = nil
    ) {
        self.id = UUID()
        self.authorUserID = authorUserID
        self.authorDisplayName = authorDisplayName
        self.body = body
        self.event = event
        self.post = post
        self.createdAt = Date()
    }
}

extension Comment {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isDeleted: Bool { deletedAt != nil }
    var isEdited: Bool { editedAt != nil }
}
