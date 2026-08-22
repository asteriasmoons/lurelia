//
//  EventPost.swift
//  Lurelia
//
//  A host post on a SharedEvent's timeline. Body is Markdown exported from
//  the in-app Tiptap editor. Supports photo and file attachments (see
//  `Attachment` with `post = self`) and comments (see `Comment` scoped to
//  the post). Pinned posts appear above the chronological timeline.
//

import Foundation
import SwiftData

@Model
final class EventPost {
    var id: UUID = UUID()
    var remoteID: String?

    var authorUserID: String = ""
    var authorDisplayName: String = ""
    var authorAvatarURL: String?

    var title: String = ""
    /// Markdown-formatted body, exported from the Tiptap editor.
    var bodyMarkdown: String = ""
    /// Optional pre-rendered HTML for fast timeline rendering.
    var bodyHTML: String?

    var isPinned: Bool = false
    var likesCount: Int = 0
    var commentsCount: Int = 0

    var createdAt: Date = Date()
    var editedAt: Date?
    var deletedAt: Date?

    /// Timestamp when the fan-out notification job was dispatched to
    /// attendees registered for hostPost notifications.
    var notificationSentAt: Date?

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.post)
    var attachments: [Attachment]?

    @Relationship(deleteRule: .cascade, inverse: \Comment.post)
    var comments: [Comment]?

    init(
        authorUserID: String = "",
        authorDisplayName: String = "",
        title: String = "",
        bodyMarkdown: String = "",
        isPinned: Bool = false,
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.authorUserID = authorUserID
        self.authorDisplayName = authorDisplayName
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.isPinned = isPinned
        self.event = event
        self.createdAt = Date()
    }
}

extension EventPost {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isDeleted: Bool { deletedAt != nil }
    var isEdited: Bool { editedAt != nil }
}
