//
//  SharedEventNotificationManager.swift
//  Lurelia
//
//  Manages APNs registration for the shared event platform and
//  subscribe/unsubscribe on vox-api. Handles the launch race — if a view
//  calls `subscribe()` before the device token has arrived from the OS,
//  the request is queued and flushed the moment
//  `didRegisterForRemoteNotificationsWithDeviceToken` fires.
//

import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
final class SharedEventNotificationManager: ObservableObject {
    static let shared = SharedEventNotificationManager()

    @Published private(set) var deviceTokenHex: String?
    @Published private(set) var lastRegistrationError: String?
    @Published private(set) var lastSubscribeResult: String?

    private struct PendingSubscribe: Equatable {
        let eventID: String
        let userID: String
        let enabledKinds: [String]?

        static func == (lhs: PendingSubscribe, rhs: PendingSubscribe) -> Bool {
            lhs.eventID == rhs.eventID && lhs.userID == rhs.userID
        }
    }

    private var pendingSubscribes: [PendingSubscribe] = []

    // MARK: - AppDelegate callbacks

    func receivedDeviceToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        deviceTokenHex = hex
        #if DEBUG
        print("[SharedEventNotificationManager] device token: \(hex.prefix(16))…")
        #endif
        flushPending()
    }

    func registrationFailed(_ error: Error) {
        lastRegistrationError = String(describing: error)
        #if DEBUG
        print("[SharedEventNotificationManager] registration failed:", error)
        #endif
    }

    // MARK: - Permission + register

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            #if DEBUG
            print("[SharedEventNotificationManager] permission granted: \(granted)")
            #endif
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            lastRegistrationError = String(describing: error)
            return false
        }
    }

    // MARK: - Subscribe / unsubscribe

    /// Subscribe the current device to notifications for a shared event.
    /// If the device token isn't ready yet, the request is queued and
    /// flushed on `receivedDeviceToken`.
    func subscribe(
        eventID: String,
        userID: String,
        enabledKinds: [String]? = nil,
    ) async {
        guard let token = deviceTokenHex else {
            let pending = PendingSubscribe(
                eventID: eventID,
                userID: userID,
                enabledKinds: enabledKinds,
            )
            if !pendingSubscribes.contains(pending) {
                pendingSubscribes.append(pending)
            }
            #if DEBUG
            print("[SharedEventNotificationManager] no token yet, queued subscribe for \(eventID)")
            #endif
            return
        }
        await performSubscribe(
            eventID: eventID,
            userID: userID,
            deviceToken: token,
            enabledKinds: enabledKinds,
        )
    }

    func unsubscribe(eventID: String, userID: String) async {
        guard let token = deviceTokenHex else { return }
        do {
            try await SharedEventsService.shared.unsubscribeNotifications(
                eventID: eventID,
                userID: userID,
                deviceToken: token,
            )
        } catch {
            lastRegistrationError = String(describing: error)
        }
    }

    // MARK: - Foreground

    /// Called by AppDelegate for `didReceiveRemoteNotification`. Posts a
    /// local banner so the user sees it while the app is active. iOS
    /// still delivers the OS-level banner via `willPresent` if the app
    /// is foregrounded — this is a belt-and-braces path.
    func presentForeground(userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else { return }
        let title = (alert["title"] as? String) ?? "Lurelia"
        let body = (alert["body"] as? String) ?? ""

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let payload = userInfo["lurelia"] as? [String: Any] {
            content.userInfo = ["lurelia": payload]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil,
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private

    private func flushPending() {
        let items = pendingSubscribes
        pendingSubscribes.removeAll()
        guard let token = deviceTokenHex else { return }
        for item in items {
            Task { @MainActor in
                await self.performSubscribe(
                    eventID: item.eventID,
                    userID: item.userID,
                    deviceToken: token,
                    enabledKinds: item.enabledKinds,
                )
            }
        }
    }

    private func performSubscribe(
        eventID: String,
        userID: String,
        deviceToken: String,
        enabledKinds: [String]?,
    ) async {
        do {
            try await SharedEventsService.shared.subscribeNotifications(
                eventID: eventID,
                userID: userID,
                deviceToken: deviceToken,
                enabledKinds: enabledKinds,
            )
            lastSubscribeResult = "subscribed \(eventID)"
            #if DEBUG
            print("[SharedEventNotificationManager] subscribed to \(eventID) for user \(userID)")
            #endif
        } catch {
            lastRegistrationError = String(describing: error)
            #if DEBUG
            print("[SharedEventNotificationManager] subscribe failed:", error)
            #endif
        }
    }
}
