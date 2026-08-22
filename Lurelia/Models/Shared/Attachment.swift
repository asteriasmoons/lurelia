//
//  Attachment.swift
//  Lurelia
//
//  A photo or file attached to a SharedEvent, an EventPost, or an
//  Announcement. Uploaded via vox-api → Cloudinary; the `url` field is the
//  CDN URL. Local uploads set `syncStatus == .pending` until the server
//  confirms.
//

import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID = UUID()
    var remoteID: String?

    /// Backing storage for `AttachmentKind`.
    var kindRaw: String = AttachmentKind.image.rawValue

    var url: String = ""
    var thumbnailURL: String?
    var mimeType: String = ""
    var filename: String = ""
    var sizeBytes: Int = 0

    /// Dimensions for images / videos. `0` for non-visual attachments.
    var width: Int = 0
    var height: Int = 0

    var uploaderUserID: String = ""
    var caption: String?
    var createdAt: Date = Date()

    /// Whether this attachment renders inline (embedded in editor content)
    /// vs. as an attachment strip below the post body.
    var isInline: Bool = false

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?
    var post: EventPost?
    var announcement: Announcement?

    init(
        kind: AttachmentKind = .image,
        url: String = "",
        mimeType: String = "",
        filename: String = "",
        uploaderUserID: String = ""
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.url = url
        self.mimeType = mimeType
        self.filename = filename
        self.uploaderUserID = uploaderUserID
        self.createdAt = Date()
    }
}

extension Attachment {
    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRaw) ?? .image }
        set { kindRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
