//
//  Announcement.swift
//  Lurelia
//
//  A host-only broadcast on a SharedEvent. Differs from EventPost in that
//  announcements always trigger notifications and always pin above posts.
//  Body is Markdown (Tiptap-exported).
//

import Foundation
import SwiftData

@Model
final class Announcement {
    var id: UUID = UUID()
    var remoteID: String?

    var authorUserID: String = ""
    var authorDisplayName: String = ""
    var authorAvatarURL: String?

    var title: String = ""
    /// Markdown-formatted body, exported from the Tiptap editor.
    var bodyMarkdown: String = ""
    /// Optional pre-rendered HTML — kept so timeline reads don't have to
    /// invoke a markdown parser on the client for every impression.
    var bodyHTML: String?

    var isPinned: Bool = true
    var createdAt: Date = Date()
    var editedAt: Date?
    var deletedAt: Date?

    /// Timestamp when the fan-out notification job was dispatched.
    var notificationSentAt: Date?

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.announcement)
    var attachments: [Attachment]?

    init(
        authorUserID: String = "",
        authorDisplayName: String = "",
        title: String = "",
        bodyMarkdown: String = "",
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.authorUserID = authorUserID
        self.authorDisplayName = authorDisplayName
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.event = event
        self.createdAt = Date()
    }
}

extension Announcement {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isDeleted: Bool { deletedAt != nil }
    var isEdited: Bool { editedAt != nil }
}
