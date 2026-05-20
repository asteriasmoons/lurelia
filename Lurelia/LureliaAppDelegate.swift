//
//  LureliaAppDelegate.swift
//  Lurelia
//

import UIKit
import UserNotifications
import SwiftData

class LureliaAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static weak var shared: LureliaAppDelegate?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LureliaAppDelegate.shared = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        // Habit notification actions
        if userInfo["habitID"] != nil,
           let container = LureliaNotificationManager.shared.modelContainer {
            Task { @MainActor in
                await HabitManager.shared.handleResponse(response, container: container)
            }
        }

        if actionID == LureliaNotificationManager.snoozeActionID,
           let reminderIDStr = userInfo["reminderID"] as? String {
            Task { @MainActor in
                guard let container = LureliaNotificationManager.shared.modelContainer else { return }
                let context = container.mainContext
                let descriptor = FetchDescriptor<LureliaReminder>()
                if let reminders = try? context.fetch(descriptor),
                   let reminder = reminders.first(where: { $0.notificationID == reminderIDStr }) {
                    LureliaNotificationManager.shared.snoozeReminder(reminder)
                }
            }
        }

        completionHandler()
    }
}
