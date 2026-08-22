//
//  NotificationSubscription.swift
//  Lurelia
//
//  A user's push notification subscription for a SharedEvent. One row per
//  (event, user, device). Server side uses these to fan notifications out
//  when host posts, RSVP changes, edits, cancellations, etc. happen.
//

import Foundation
import SwiftData

@Model
final class NotificationSubscription {
    var id: UUID = UUID()
    var remoteID: String?

    var userID: String = ""
    var deviceToken: String = ""
    var platform: String = "ios"

    /// Which notification kinds this subscription is opted into. Stored as
    /// an array of `NotificationKind.rawValue`s for CloudKit friendliness.
    var enabledKindsRaw: [String] = NotificationKind.allCases.map(\.rawValue)

    var subscribedAt: Date = Date()
    var unsubscribedAt: Date?
    var lastPingedAt: Date?

    var syncStatusRaw: String = SyncStatus.idle.rawValue
    var lastSyncedAt: Date?

    var event: SharedEvent?

    init(
        userID: String = "",
        deviceToken: String = "",
        platform: String = "ios",
        event: SharedEvent? = nil
    ) {
        self.id = UUID()
        self.userID = userID
        self.deviceToken = deviceToken
        self.platform = platform
        self.event = event
        self.subscribedAt = Date()
    }
}

extension NotificationSubscription {
    var enabledKinds: Set<NotificationKind> {
        get { Set(enabledKindsRaw.compactMap { NotificationKind(rawValue: $0) }) }
        set { enabledKindsRaw = newValue.map(\.rawValue) }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isActive: Bool { unsubscribedAt == nil }
}
