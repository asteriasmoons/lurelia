//
//  EventArtwork.swift
//  Lurelia
//
//  Cover art for a SharedEvent. Distinct from `Attachment` — an event can
//  have multiple artwork options (cropped square + wide banner), and
//  artwork rotates or overrides host post inline images. One "primary"
//  artwork per event, enforced by the service layer.
//

import Foundation
import SwiftData

@Model
final class EventArtwork {
    var id: UUID = UUID()
    var remoteID: String?

    var url: String = ""
    var thumbnailURL: String?
    var bannerURL: String?

    var width: Int = 0
    var height: Int = 0

    var uploaderUserID: String = ""
    var altText: String?

    var isPrimary: Bool = false
    var createdAt: Date = Date()

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(
        url: String = "",
        isPrimary: Bool = false,
        uploaderUserID: String = "",
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.isPrimary = isPrimary
        self.uploaderUserID = uploaderUserID
        self.event = event
        self.createdAt = Date()
    }
}

extension EventArtwork {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
