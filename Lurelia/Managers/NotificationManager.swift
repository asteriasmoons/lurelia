//
//  NotificationManager.swift
//  Lurelia
//  Desktop Commander connection test — hello from ChatGPT! ✨
//
//  Adapted from Lystaria's NotificationManager.
//  Handles all local notification scheduling for LureliaReminder.
//
//  HOW IT WORKS:
//  ─────────────
//  1. Call scheduleReminder(_:) when a reminder is created or edited.
//     This cancels any existing notifications and creates new ones.
//
//  2. Each reminder has a stable notificationID. That ID is used as the
//     base identifier so notifications can be cancelled and rebuilt safely.
//
//  3. All fire times live in reminder.timesOfDay (["HH:mm", ...]).
//     reminder.nextFireAt tracks the next occurrence to fire.
//
//  4. Call cancelReminder(_:) when a reminder is deleted, paused, or completed.
//
//  NOTIFICATION IDENTIFIERS:
//  ─────────────────────────
//  Base ID = "lurelia.reminder.<reminder.notificationID>"
//  Multiple times use suffix: baseID.0, baseID.1, etc.
//  Snooze uses suffix: baseID.snooze.<timestamp>

import Foundation
import ActivityKit
import AlarmKit
import SwiftData
import SwiftUI
import UserNotifications
import Combine
import UIKit

@MainActor
final class LureliaNotificationManager: ObservableObject {

    static let shared = LureliaNotificationManager()

    static let reminderCategoryID = "LURELIA_REMINDER"
    static let doneActionID       = "DONE"
    static let snoozeActionID     = "SNOOZE"

    @Published var isAuthorized = false

    var modelContainer: ModelContainer?

    private var isRescheduling = false
    private var lastRescheduleAt: Date?
    private let rescheduleDebounce: TimeInterval = 5

    // MARK: - Setup

    func setup() {
        let center = UNUserNotificationCenter.current()
        
        let doneAction = UNNotificationAction(
            identifier: Self.doneActionID,
            title: "Done ✓",
            options: [.destructive]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze 10 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.reminderCategoryID,
            actions: [doneAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
        center.delegate = LureliaAppDelegate.shared
        
        refreshAuthorizationStatus()
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let container = self.modelContainer else { return }
                self.dumpAllNotificationCenterState(source: "willEnterForeground BEFORE rescheduleAll")
                self.rescheduleAll(from: container)
                self.dumpAllNotificationCenterState(source: "willEnterForeground AFTER rescheduleAll")
                self.dumpLureliaPendingNotifications(source: "willEnterForeground")
            }
        }
        
        print("🧪 setup() reached reschedule block")
        print("🧪 modelContainer is nil? \(modelContainer == nil)")
        
        if let container = modelContainer {
            print("🧪 setup() calling rescheduleAll(from:)")
            rescheduleAll(from: container)
        } else {
            print("🚨 setup() did NOT call rescheduleAll because modelContainer is nil")
        }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            print("❌ Lurelia notification permission error: \(error)")
            return false
        }
    }

    func currentPermissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Schedule

    func scheduleReminder(_ reminder: LureliaReminder) {
        print("🚨 SCHEDULE REMINDER CALLED")
        print("Object Identifier: \(ObjectIdentifier(reminder))")
        print("   • Title: \(reminder.title)")
        print("   • Reminder UUID: \(reminder.id)")
        print("   • Notification ID BEFORE stable check: \(reminder.notificationID)")
        print("   • isEnabled: \(reminder.isEnabled)")
        print("   • isCompleted: \(reminder.isCompleted)")
        print("   • scheduledDate: \(reminder.scheduledDate)")
        print("   • nextFireAt: \(String(describing: reminder.nextFireAt))")
        Thread.callStackSymbols.prefix(8).forEach { print($0) }
        cancelReminder(reminder)

        guard reminder.isEnabled && !reminder.isCompleted else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body  = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                        .nonEmptyOrNil ?? reminder.title
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.userInfo = ["reminderID": reminder.notificationID]

        ensureStableNotificationID(for: reminder)
        let baseID = notificationBaseID(for: reminder)
        let times  = resolvedTimesOfDay(for: reminder)

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔔 REMINDER SCHEDULE REQUEST")
        print("   • Title: \(reminder.title)")
        print("   • Reminder ID: \(reminder.id)")
        print("   • Notification ID: \(reminder.notificationID)")
        print("   • Base ID: \(baseID)")
        print("   • Source: scheduleReminder(_:)")

        if reminder.repeatUnit == .none {
            scheduleOnce(reminder: reminder, content: content, baseID: baseID)
        } else {
            scheduleNextOccurrences(reminder: reminder, times: times, content: content, baseID: baseID)
        }

        scheduleAlarmIfNeeded(for: reminder)

        dumpLureliaPendingNotifications(source: "after scheduleReminder for \(reminder.title)")
    }

    // MARK: - Cancel

    func cancelReminder(_ reminder: LureliaReminder) {
        ensureStableNotificationID(for: reminder)
        let baseID = notificationBaseID(for: reminder)
        let center = UNUserNotificationCenter.current()
        print("🚨 CANCEL REMINDER CALLED")
        print("Object Identifier: \(ObjectIdentifier(reminder))")
        print("   • Title: \(reminder.title)")
        print("   • Reminder UUID: \(reminder.id)")
        print("   • Notification ID: \(reminder.notificationID)")
        print("   • Base ID: \(baseID)")
        print("   • Stack:")
        Thread.callStackSymbols.prefix(10).forEach { print("     \($0)") }

        var ids: [String] = [baseID]
        for i in 0..<20 { ids.append("\(baseID).\(i)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        cancelAlarmIfNeeded(for: reminder)
        print("🧹 Attempted removal IDs:")
        ids.forEach { print("   • \($0)") }

        // Snooze IDs can't be predicted — async scan
        center.getPendingNotificationRequests { requests in
            let snoozeIDs = requests.map(\.identifier)
                .filter { $0.hasPrefix(baseID + ".snooze.") }
            print("🔎 Snooze scan for baseID: \(baseID)")
            print("   • Found snooze IDs: \(snoozeIDs)")
            if !snoozeIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: snoozeIDs)
                center.removeDeliveredNotifications(withIdentifiers: snoozeIDs)
            }
        }

        print("🧹 [Lurelia] Cancelled notifications for '\(reminder.title)'")
        dumpLureliaPendingNotifications(source: "after cancelReminder for \(reminder.title)")
    }

    // MARK: - AlarmKit

    private func scheduleAlarmIfNeeded(for reminder: LureliaReminder) {
        guard reminder.alarmEnabled else { return }
        let selectedTimes = uniqueTimes(reminder.alarmFireTimes)
        let activeAlarmTimes = selectedTimes.isEmpty
            ? Array(resolvedTimesOfDay(for: reminder).prefix(1))
            : selectedTimes

        guard !activeAlarmTimes.isEmpty else { return }

        for fireTime in activeAlarmTimes {
            let (hour, minute) = parseTime(fireTime)
            guard let alarmDate = alarmFireDate(
                hour: hour,
                minute: minute,
                reminder: reminder
            ) else {
                print("⚠️ [Lurelia] Could not compute alarm date for '\(reminder.title)' at \(fireTime)")
                continue
            }

            guard alarmDate > Date() else {
                print("⏭ [Lurelia] Skipping past alarm for '\(reminder.title)' at \(fireTime)")
                continue
            }

            let alarmID = reminder.alarmUUID(forFireTime: fireTime)
            scheduleAlarm(
                reminder: reminder,
                alarmID: alarmID,
                alarmDate: alarmDate,
                fireTime: fireTime
            )
        }
    }

    private func scheduleAlarm(
        reminder: LureliaReminder,
        alarmID: UUID,
        alarmDate: Date,
        fireTime: String
    ) {
        Task { @MainActor in
            guard #available(iOS 26.0, *) else { return }

            do {
                switch AlarmManager.shared.authorizationState {
                case .authorized:
                    break
                case .notDetermined:
                    let state = try await AlarmManager.shared.requestAuthorization()
                    guard state == .authorized else {
                        print("⚠️ [Lurelia] Alarm authorization was not granted for '\(reminder.title)'")
                        return
                    }
                case .denied:
                    print("⚠️ [Lurelia] Alarm authorization denied for '\(reminder.title)'")
                    return
                }

                let alert = AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: reminder.title)
                )
                let metadata = LureliaReminderAlarmMetadata(
                    reminderID: reminder.id,
                    notificationID: reminder.notificationID,
                    title: reminder.title,
                    icon: reminder.icon
                )
                let attributes = AlarmAttributes(
                    presentation: AlarmPresentation(alert: alert),
                    metadata: metadata,
                    tintColor: LColors.gradientBlue
                )
                let soundName = reminder.alarmSoundName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let sound: AlertConfiguration.AlertSound = soundName?.isEmpty == false
                    ? .named(soundName!)
                    : .default
                let configuration = AlarmManager.AlarmConfiguration.alarm(
                    schedule: .fixed(alarmDate),
                    attributes: attributes,
                    sound: sound
                )

                try? AlarmManager.shared.cancel(id: alarmID)
                try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
                print("✅ [Lurelia] Scheduled AlarmKit alarm")
                print("   • Title: \(reminder.title)")
                print("   • Alarm ID: \(alarmID)")
                print("   • Fire Date: \(alarmDate)")
                print("   • Time Slot: \(fireTime)")
                print("   • Sound: \(soundName ?? "default")")
            } catch {
                print("❌ [Lurelia] AlarmKit schedule error for '\(reminder.title)': \(error)")
            }
        }
    }

    private func cancelAlarmIfNeeded(for reminder: LureliaReminder) {
        guard #available(iOS 26.0, *) else { return }

        var alarmIDs = reminder.alarmIdentifiers.map(\.id)
        if let rawID = reminder.alarmID,
           let legacyAlarmID = UUID(uuidString: rawID) {
            alarmIDs.append(legacyAlarmID)
        }

        for alarmID in Array(Set(alarmIDs)) {
            do {
                try AlarmManager.shared.cancel(id: alarmID)
                print("🧹 [Lurelia] Cancelled AlarmKit alarm for '\(reminder.title)'")
                print("   • Alarm ID: \(alarmID)")
            } catch {
                print("⚠️ [Lurelia] AlarmKit cancel skipped for '\(reminder.title)': \(error)")
            }
        }
    }

    private func alarmFireDate(
        hour: Int,
        minute: Int,
        reminder: LureliaReminder
    ) -> Date? {
        let calendar = Calendar.current

        if reminder.repeatUnit == .none {
            var components = calendar.dateComponents([.year, .month, .day], from: reminder.scheduledDate)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }

        let earliestAllowedFireDate = reminder.nextFireAt.map { max(Date(), $0) } ?? Date()
        return nextOccurrence(
            hour: hour,
            minute: minute,
            after: earliestAllowedFireDate.addingTimeInterval(-1),
            reminder: reminder,
            calendar: calendar
        )
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("lurelia.reminder.") }
            print("🚨 CANCEL ALL LURELIA REMINDERS")
            print("   • Count: \(ids.count)")
            ids.forEach { print("   • \($0)") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
    
    func cancelRoutine(_ routine: LureliaRoutine) {
        let center = UNUserNotificationCenter.current()

        let routineModelID = String(describing: routine.persistentModelID)

        var ids: [String] = []

        ids.append(contentsOf: routine.startReminderNotificationIDs)
        ids.append(contentsOf: routine.halfwayReminderNotificationIDs)
        ids.append(contentsOf: routine.endReminderNotificationIDs)

        ids.append("routine-\(routineModelID)-start")
        ids.append("routine-\(routineModelID)-halfway")
        ids.append("routine-\(routineModelID)-end")

        ids.append("lurelia.routine.\(routineModelID)")
        ids.append("lurelia.routine.\(routineModelID).start")
        ids.append("lurelia.routine.\(routineModelID).halfway")
        ids.append("lurelia.routine.\(routineModelID).end")

        let uniqueIDs = Array(Set(ids))

        print("🧹 CANCEL ROUTINE CALLED")
        print("   • Routine: \(routine.name)")
        print("   • Routine Model ID: \(routineModelID)")
        print("   • IDs Count: \(uniqueIDs.count)")
        uniqueIDs.forEach { print("   • \($0)") }

        center.removePendingNotificationRequests(withIdentifiers: uniqueIDs)
        center.removeDeliveredNotifications(withIdentifiers: uniqueIDs)

        center.getPendingNotificationRequests { requests in
            let routineIDs = requests
                .filter { request in
                    let identifier = request.identifier
                    let title = request.content.title

                    return identifier.localizedCaseInsensitiveContains(routineModelID)
                        || identifier.localizedCaseInsensitiveContains(routine.name)
                        || title.localizedCaseInsensitiveContains(routine.name)
                        || identifier.localizedCaseInsensitiveContains("routine")
                }
                .map { $0.identifier }

            if !routineIDs.isEmpty {
                print("🧹 CANCEL ROUTINE ASYNC SCAN FOUND MORE IDS")
                routineIDs.forEach { print("   • \($0)") }
                center.removePendingNotificationRequests(withIdentifiers: routineIDs)
                center.removeDeliveredNotifications(withIdentifiers: routineIDs)
            }
        }
    }
    
    // MARK: - HARD RESET ALL NOTIFS FOR DEBUG
    // func hardResetAllNotificationsForDebug() {
        // let center = UNUserNotificationCenter.current()

        // print("")
        // print("🧨🧨🧨 HARD RESETTING ALL NOTIFICATIONS 🧨🧨🧨")
        // print("This removes ALL pending and delivered notifications for this app.")

        // center.getPendingNotificationRequests { requests in
            // print("📌 Pending before hard reset: \(requests.count)")
            // requests.forEach {
                // print("   • \($0.identifier) | \($0.content.title)")
            // }

            // center.removeAllPendingNotificationRequests()

            // center.getPendingNotificationRequests { afterRequests in
                // print("📌 Pending after hard reset: \(afterRequests.count)")
            // }
        // }

        // center.getDeliveredNotifications { notifications in
            // print("📬 Delivered before hard reset: \(notifications.count)")
            // notifications.forEach {
                // print("   • \($0.request.identifier) | \($0.request.content.title) | \($0.date)")
            // }

            // center.removeAllDeliveredNotifications()

            // center.getDeliveredNotifications { afterNotifications in
                // print("📬 Delivered after hard reset: \(afterNotifications.count)")
            // }
        // }
    // }

    // MARK: - Reschedule All

    func rescheduleAll(from container: ModelContainer) {
        guard !isRescheduling else { return }
        if let last = lastRescheduleAt, Date().timeIntervalSince(last) < rescheduleDebounce { return }

        isRescheduling    = true
        lastRescheduleAt  = Date()
        defer { isRescheduling = false }

        Task { @MainActor in
            let context    = container.mainContext
            let descriptor = FetchDescriptor<LureliaReminder>()
            do {
                let reminders = try context.fetch(descriptor)
                    .filter {
                        $0.kind == .standalone &&
                        $0.isEnabled &&
                        !$0.isCompleted
                    }
                print("🔁 RESCHEDULE ALL — STANDALONE ONLY")
                print("   • Count: \(reminders.count)")
                for reminder in reminders {
                    print("   • \(reminder.title) | kind=\(reminder.kind.rawValue) | notificationID=\(reminder.notificationID)")
                }
                print("")
                print("══════════════════════════════════════")
                print("📦 FETCHED REMINDERS FROM SWIFTDATA")
                print("Count: \(reminders.count)")

                for reminder in reminders {
                    print("--------------------------------------")
                    print("Title: \(reminder.title)")
                    print("UUID: \(reminder.id)")
                    print("Notification ID: \(reminder.notificationID)")
                    print("Enabled: \(reminder.isEnabled)")
                    print("Completed: \(reminder.isCompleted)")
                    print("Scheduled: \(reminder.scheduledDate)")
                }

                print("══════════════════════════════════════")
                print("")
                print("🔁 RESCHEDULE FETCHED ACTIVE REMINDERS")
                for reminder in reminders {
                    print("   • \(reminder.title)")
                    print("     UUID: \(reminder.id)")
                    print("     notificationID: \(reminder.notificationID)")
                    print("     enabled: \(reminder.isEnabled)")
                    print("     completed: \(reminder.isCompleted)")
                    print("     scheduledDate: \(reminder.scheduledDate)")
                    print("     nextFireAt: \(String(describing: reminder.nextFireAt))")
                }

                let center  = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let oldIDs  = pending.map(\.identifier).filter { $0.hasPrefix("lurelia.reminder.") }
                if !oldIDs.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: oldIDs)
                    center.removeDeliveredNotifications(withIdentifiers: oldIDs)
                }

                let uniqueReminders = reminders.reduce(into: [String: LureliaReminder]()) { result, reminder in
                    self.ensureStableNotificationID(for: reminder)
                    let key = reminder.duplicatePreventionKey
                    if result[key] == nil {
                        result[key] = reminder
                    } else {
                        print("⚠️ [Lurelia] Skipping duplicate reminder during reschedule: \(reminder.title)")
                        self.cancelReminder(reminder)
                    }
                }
                .values
                .sorted { $0.scheduledDate < $1.scheduledDate }
                
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("🔁 RESCHEDULE ALL")
                print("   • Reminder Count: \(reminders.count)")
                print("   • Unique Count: \(uniqueReminders.count)")
                print("   • Pending Removed: \(oldIDs.count)")
                print("   • Source: rescheduleAll(from:)")

                print("🔁 [Lurelia] Rebuilding \(uniqueReminders.count) reminder notifications")
                for reminder in uniqueReminders { scheduleReminder(reminder) }
            } catch {
                print("❌ [Lurelia] rescheduleAll fetch error: \(error)")
            }
        }
    }

    // MARK: - Snooze

    func snoozeReminder(_ reminder: LureliaReminder, minutes: Int = 10) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body  = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                        .nonEmptyOrNil ?? reminder.title
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryID
        content.userInfo = ["reminderID": reminder.notificationID]

        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let snoozeID = "\(notificationBaseID(for: reminder)).snooze.\(Date().timeIntervalSince1970)"
        let request  = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ Snooze error: \(error)") }
            else { print("💤 Snoozed \(minutes) min: \(reminder.title)") }
        }
    }

    // MARK: - Private: One-shot

    private func scheduleOnce(
        reminder: LureliaReminder,
        content: UNMutableNotificationContent,
        baseID: String
    ) {
        let fireDate = reminder.nextFireAt ?? reminder.scheduledDate
        print("📅 One-Shot Reminder")
        print("   • Title: \(reminder.title)")
        print("   • Reminder ID: \(reminder.id)")
        print("   • Notification ID: \(reminder.notificationID)")
        print("   • Fire Date: \(fireDate)")
        print("   • Source: scheduleOnce(_:)")
        let now      = Date()
        let delta    = fireDate.timeIntervalSince(now)

        if delta < -90 {
            print("⏭ [Lurelia] Skipping past one-shot (\(Int(-delta))s ago): \(reminder.title)")
            return
        }

        if delta <= 3 {
            let fireIn  = max(delta, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            addRequest(
                id: baseID,
                content: content,
                trigger: trigger,
                reminder: reminder,
                fireDate: fireDate,
                source: "scheduleOnce(_:timeInterval)"
            )
        } else {
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            comps.second = comps.second ?? 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            addRequest(
                id: baseID,
                content: content,
                trigger: trigger,
                reminder: reminder,
                fireDate: fireDate,
                source: "scheduleOnce(_:calendar)"
            )
        }
    }

    // MARK: - Private: Recurring — schedule each time-of-day as its own next occurrence

    private func scheduleNextOccurrences(
        reminder: LureliaReminder,
        times: [String],
        content: UNMutableNotificationContent,
        baseID: String
    ) {
        let now = Date()
        let cal = Calendar.current
        let earliestAllowedFireDate = reminder.nextFireAt.map { max(now, $0) } ?? now

        // nextFireAt is the computed next fire for the primary time.
        // For each timesOfDay entry, compute the next occurrence >= now.
        for (index, timeStr) in times.enumerated() {
            let (h, m) = parseTime(timeStr)
            guard let fireDate = nextOccurrence(
                hour: h, minute: m,
                after: earliestAllowedFireDate.addingTimeInterval(-1),
                reminder: reminder,
                calendar: cal
            ) else {
                print("⚠️ [Lurelia] Could not compute next occurrence for '\(reminder.title)' time \(timeStr)")
                continue
            }

            guard fireDate >= earliestAllowedFireDate else {
                print("⏭ [Lurelia] Skipping occurrence before nextFireAt")
                print("   • Title: \(reminder.title)")
                print("   • Time Slot: \(timeStr)")
                print("   • Fire Date: \(fireDate)")
                print("   • Earliest Allowed: \(earliestAllowedFireDate)")
                continue
            }

            let requestID = index == 0 ? baseID : "\(baseID).\(index)"

            print("📅 Recurring Reminder Occurrence")
            print("   • Title: \(reminder.title)")
            print("   • Reminder ID: \(reminder.id)")
            print("   • Notification ID: \(reminder.notificationID)")
            print("   • Request ID: \(requestID)")
            print("   • Time Slot: \(timeStr)")
            print("   • Fire Date: \(fireDate)")
            print("   • Source: scheduleNextOccurrences(_:)")

            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            comps.second = comps.second ?? 0
            let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = requestID
            addRequest(
                id: id,
                content: content,
                trigger: trigger,
                reminder: reminder,
                fireDate: fireDate,
                source: "scheduleNextOccurrences(_:) timeSlot=\(timeStr)"
            )

            print("⏰ [Lurelia] Scheduled '\(reminder.title)' [\(timeStr)] → \(fireDate)")
        }
    }

    // Compute the next fire date for a given hour:minute after `now`,
    // respecting the reminder's repeat unit and interval.
    private func nextOccurrence(
        hour: Int, minute: Int,
        after now: Date,
        reminder: LureliaReminder,
        calendar: Calendar
    ) -> Date? {
        // Build a candidate on today
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour; comps.minute = minute; comps.second = 0
        guard var candidate = calendar.date(from: comps) else { return nil }

        // If today's time is already past, advance by one interval
        if candidate <= now {
            candidate = advanceByInterval(candidate, reminder: reminder, calendar: calendar) ?? candidate
        }

        return candidate
    }

    private func advanceByInterval(_ date: Date, reminder: LureliaReminder, calendar: Calendar) -> Date? {
        let interval = max(1, reminder.repeatInterval)
        switch reminder.repeatUnit {
        case .days:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weeks:
            if reminder.repeatWeekdays.isEmpty {
                return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }
            // Find next matching weekday
            let wds = Set(reminder.repeatWeekdays)
            for offset in 1...14 {
                guard let next = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
                let wd = calendar.component(.weekday, from: next)
                if wds.contains(wd) { return next }
            }
            return nil
        case .months:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .years:
            return calendar.date(byAdding: .year, value: interval, to: date)
        case .hours:
            return calendar.date(byAdding: .hour, value: interval, to: date)
        case .minutes:
            return calendar.date(byAdding: .minute, value: interval, to: date)
        case .none:
            return nil
        }
    }

    // MARK: - Helpers

    private func ensureStableNotificationID(for reminder: LureliaReminder) {
        let currentID = reminder.notificationID.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentID.isEmpty {
            let newID = UUID().uuidString
            print("🆔 EMPTY notificationID FOUND — assigning new one")
            print("   • Title: \(reminder.title)")
            print("   • Reminder UUID: \(reminder.id)")
            print("   • New Notification ID: \(newID)")
            reminder.notificationID = newID
        } else {
            print("🆔 Stable notificationID OK")
            print("   • Title: \(reminder.title)")
            print("   • Reminder UUID: \(reminder.id)")
            print("   • Notification ID: \(currentID)")
        }
    }

    private func notificationBaseID(for reminder: LureliaReminder) -> String {
        let id = reminder.notificationID.trimmingCharacters(in: .whitespacesAndNewlines)
        return "lurelia.reminder.\(id)"
    }

    private func addRequest(
        id: String,
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger,
        reminder: LureliaReminder,
        fireDate: Date,
        source: String
    ) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        print("📌 ADD REQUEST ABOUT TO RUN")
        print("   • Title: \(reminder.title)")
        print("   • Reminder UUID: \(reminder.id)")
        print("   • Notification ID: \(reminder.notificationID)")
        print("   • Request ID: \(id)")
        print("   • Fire Date: \(fireDate)")
        print("   • Source: \(source)")
        print("")
        print("➡️ ABOUT TO REGISTER NOTIFICATION")
        print("Identifier: \(id)")
        print("Reminder Title: \(reminder.title)")
        print("Reminder UUID: \(reminder.id)")
        print("Notification ID: \(reminder.notificationID)")
        print("Fire Date: \(fireDate)")
        print("")
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ [Lurelia] Failed to schedule notification")
                print("   • Title: \(reminder.title)")
                print("   • Reminder ID: \(reminder.id)")
                print("   • Notification ID: \(reminder.notificationID)")
                print("   • Request ID: \(id)")
                print("   • Fire Date: \(fireDate)")
                print("   • Source: \(source)")
                print("   • Error: \(error)")
            } else {
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("✅ [Lurelia] Scheduled notification")
                print("   • Title: \(reminder.title)")
                print("   • Reminder ID: \(reminder.id)")
                print("   • Notification ID: \(reminder.notificationID)")
                print("   • Request ID: \(id)")
                print("   • Fire Date: \(fireDate)")
                print("   • Source: \(source)")
            }
        }
    }

    /// Returns timesOfDay if populated, otherwise falls back to primaryHour/Minute,
    /// otherwise falls back to scheduledDate's hour/minute. Always de-dupes so the
    /// same reminder cannot schedule multiple notifications for the exact same time.
    private func resolvedTimesOfDay(for reminder: LureliaReminder) -> [String] {
        let stored = uniqueTimes(reminder.timesOfDay)
        if !stored.isEmpty { return stored }

        // Backfill from primaryHour/primaryMinute or scheduledDate
        let cal = Calendar.current
        let h: Int
        let m: Int
        if reminder.primaryHour != -1 {
            h = reminder.primaryHour
            m = reminder.primaryMinute
        } else {
            h = cal.component(.hour, from: reminder.scheduledDate)
            m = cal.component(.minute, from: reminder.scheduledDate)
        }
        var times = [String(format: "%02d:%02d", h, m)]

        // Also include additional fire times
        for ft in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", ft.hour, ft.minute))
        }
        return uniqueTimes(times)
    }

    private func uniqueTimes(_ times: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawTime in times {
            let trimmed = rawTime.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parsed = parseTime(trimmed)
            let normalized = String(format: "%02d:%02d", parsed.0, parsed.1)
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }

        return result
    }

    private func parseTime(_ str: String) -> (Int, Int) {
        let parts = str.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        if parts.count == 2,
           let h = Int(parts[0]), let m = Int(parts[1]),
           (0...23).contains(h), (0...59).contains(m) {
            return (h, m)
        }
        return (9, 0)
    }
}

// MARK: - Notification Audit Debugging

extension LureliaNotificationManager {
    
    func dumpAllNotificationCenterState(source: String) {
        let center = UNUserNotificationCenter.current()

        print("")
        print("👻👻👻👻👻👻👻👻👻👻👻👻👻👻👻")
        print("👻 FULL NOTIFICATION CENTER AUDIT")
        print("   • Source: \(source)")
        print("👻👻👻👻👻👻👻👻👻👻👻👻👻👻👻")

        center.getPendingNotificationRequests { requests in
            print("")
            print("📌 ALL PENDING NOTIFICATION REQUESTS")
            print("   • Count: \(requests.count)")

            for request in requests.sorted(by: { $0.identifier < $1.identifier }) {
                let content = request.content

                print("────────────────────────────")
                print("📌 PENDING")
                print("   • ID: \(request.identifier)")
                print("   • Title: \(content.title)")
                print("   • Body: \(content.body)")
                print("   • Category: \(content.categoryIdentifier)")
                print("   • Thread: \(content.threadIdentifier)")
                print("   • UserInfo: \(content.userInfo)")
                print("   • Trigger: \(self.fireDateDescription(for: request.trigger))")
            }
        }

        center.getDeliveredNotifications { notifications in
            print("")
            print("📬 ALL DELIVERED NOTIFICATIONS")
            print("   • Count: \(notifications.count)")

            for notification in notifications.sorted(by: { $0.date < $1.date }) {
                let request = notification.request
                let content = request.content

                print("────────────────────────────")
                print("📬 DELIVERED")
                print("   • Delivered Date: \(notification.date)")
                print("   • ID: \(request.identifier)")
                print("   • Title: \(content.title)")
                print("   • Body: \(content.body)")
                print("   • Category: \(content.categoryIdentifier)")
                print("   • Thread: \(content.threadIdentifier)")
                print("   • UserInfo: \(content.userInfo)")
                print("   • Trigger: \(self.fireDateDescription(for: request.trigger))")
            }
        }
    }

    func dumpLureliaPendingNotifications(source: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let lureliaRequests = requests
                .filter { $0.identifier.hasPrefix("lurelia.reminder.") }
                .sorted { $0.identifier < $1.identifier }

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🧾 LURELIA PENDING NOTIFICATION AUDIT")
            print("   • Source: \(source)")
            print("   • Total Pending Lurelia Requests: \(lureliaRequests.count)")

            if lureliaRequests.isEmpty {
                print("   • No pending Lurelia reminder notifications")
                return
            }

            var grouped: [String: [UNNotificationRequest]] = [:]

            for request in lureliaRequests {
                let title = request.content.title
                let body = request.content.body
                let fireDescription = self.fireDateDescription(for: request.trigger)

                print("────────────────────────────")
                print("   • Request ID: \(request.identifier)")
                print("   • Title: \(title)")
                print("   • Body: \(body)")
                print("   • Fire: \(fireDescription)")

                let duplicateKey = "\(title)|\(fireDescription)"
                grouped[duplicateKey, default: []].append(request)
            }

            let duplicates = grouped.filter { $0.value.count > 1 }

            if duplicates.isEmpty {
                print("✅ No duplicate title/fire-date pending requests found")
            } else {
                print("🚨 POSSIBLE DUPLICATE PENDING REQUESTS")
                for (_, duplicateRequests) in duplicates {
                    print("────────────────────────────")
                    print("   • Duplicate Count: \(duplicateRequests.count)")
                    for request in duplicateRequests {
                        print("     - \(request.identifier) | \(request.content.title) | \(self.fireDateDescription(for: request.trigger))")
                    }
                }
            }
        }
    }

    private func fireDateDescription(for trigger: UNNotificationTrigger?) -> String {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            let c = calendarTrigger.dateComponents
            return "calendar y=\(c.year ?? -1) m=\(c.month ?? -1) d=\(c.day ?? -1) h=\(c.hour ?? -1) min=\(c.minute ?? -1) s=\(c.second ?? -1) repeats=\(calendarTrigger.repeats)"
        }

        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return "interval \(intervalTrigger.timeInterval)s repeats=\(intervalTrigger.repeats)"
        }

        return "unknown trigger"
    }
}

// MARK: - String helper

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
}
