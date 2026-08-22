//
//  Host.swift
//  Lurelia
//
//  Host record on a SharedEvent. Held as a dedicated model — rather than
//  purely inferred from Attendee.role — so host history (transfers,
//  co-host promotions) can be audited without walking attendee mutations.
//  Exactly one Host row has `isPrimary == true` per event at any time; the
//  service layer enforces that invariant during ownership transfer.
//

import Foundation
import SwiftData

@Model
final class Host {
    var id: UUID = UUID()
    var remoteID: String?

    var userID: String = ""
    var displayName: String = ""
    var avatarURL: String?

    /// True only for the current primary host. Co-hosts have `isPrimary = false`.
    var isPrimary: Bool = false

    /// True when this row represents a past host who has transferred
    /// ownership. Kept for the audit trail.
    var isFormer: Bool = false

    var appointedAt: Date = Date()
    var relinquishedAt: Date?
    var transferredToUserID: String?

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(
        userID: String = "",
        displayName: String = "",
        isPrimary: Bool = true,
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.userID = userID
        self.displayName = displayName
        self.isPrimary = isPrimary
        self.event = event
        self.appointedAt = Date()
    }
}

extension Host {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}
