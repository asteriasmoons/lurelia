//
//  NotificationManager.swift
//  Lurelia
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
import SwiftData
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
                self.rescheduleAll(from: container)
            }
        }

        if let container = modelContainer {
            rescheduleAll(from: container)
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

        print("🔔 [Lurelia] Scheduling reminder '\(reminder.title)'")
        print("   • baseID: \(baseID)")
        print("   • nextFireAt: \(String(describing: reminder.nextFireAt))")
        print("   • timesOfDay: \(times)")
        print("   • repeatUnit: \(reminder.repeatUnit.rawValue)")

        if reminder.repeatUnit == .none {
            scheduleOnce(reminder: reminder, content: content, baseID: baseID)
        } else {
            scheduleNextOccurrences(reminder: reminder, times: times, content: content, baseID: baseID)
        }
    }

    // MARK: - Cancel

    func cancelReminder(_ reminder: LureliaReminder) {
        ensureStableNotificationID(for: reminder)
        let baseID = notificationBaseID(for: reminder)
        let center = UNUserNotificationCenter.current()

        var ids: [String] = [baseID]
        for i in 0..<20 { ids.append("\(baseID).\(i)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        // Snooze IDs can't be predicted — async scan
        center.getPendingNotificationRequests { requests in
            let snoozeIDs = requests.map(\.identifier)
                .filter { $0.hasPrefix(baseID + ".snooze.") }
            if !snoozeIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: snoozeIDs)
            }
        }

        print("🧹 [Lurelia] Cancelled notifications for '\(reminder.title)'")
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("lurelia.reminder.") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

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
                    .filter { $0.isEnabled && !$0.isCompleted }

                let center  = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let oldIDs  = pending.map(\.identifier).filter { $0.hasPrefix("lurelia.reminder.") }
                if !oldIDs.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: oldIDs)
                }

                print("🔁 [Lurelia] Rebuilding \(reminders.count) reminder notifications")
                for reminder in reminders { scheduleReminder(reminder) }
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
        let now      = Date()
        let delta    = fireDate.timeIntervalSince(now)

        if delta < -90 {
            print("⏭ [Lurelia] Skipping past one-shot (\(Int(-delta))s ago): \(reminder.title)")
            return
        }

        if delta <= 3 {
            let fireIn  = max(delta, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            addRequest(id: baseID, content: content, trigger: trigger)
        } else {
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            comps.second = comps.second ?? 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            addRequest(id: baseID, content: content, trigger: trigger)
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

        // nextFireAt is the computed next fire for the primary time.
        // For each timesOfDay entry, compute the next occurrence >= now.
        for (index, timeStr) in times.enumerated() {
            let (h, m) = parseTime(timeStr)
            guard let fireDate = nextOccurrence(
                hour: h, minute: m,
                after: now,
                reminder: reminder,
                calendar: cal
            ) else {
                print("⚠️ [Lurelia] Could not compute next occurrence for '\(reminder.title)' time \(timeStr)")
                continue
            }

            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            comps.second = comps.second ?? 0
            let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id       = index == 0 ? baseID : "\(baseID).\(index)"
            addRequest(id: id, content: content, trigger: trigger)

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
            reminder.notificationID = UUID().uuidString
        }
    }

    private func notificationBaseID(for reminder: LureliaReminder) -> String {
        let id = reminder.notificationID.trimmingCharacters(in: .whitespacesAndNewlines)
        return "lurelia.reminder.\(id)"
    }

    private func addRequest(id: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ [Lurelia] Failed to schedule '\(id)': \(error)") }
            else { print("✅ [Lurelia] Scheduled: \(id)") }
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

// MARK: - String helper

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
}
