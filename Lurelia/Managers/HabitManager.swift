//
//  HabitManager.swift
//  Lurelia
//
//  Standalone manager for LureliaHabit notifications.
//  Completely separate from LureliaNotificationManager (reminders).
//
//  HOW IT WORKS:
//  ─────────────
//  1. Each habit has one notification per configured time-of-day.
//     Notifications are identified by "lurelia.habit.<habit.id>.<timeIndex>"
//
//  2. Call schedule(_:) after creating or editing a habit.
//     It cancels all existing notifications for that habit before rescheduling.
//
//  3. Call cancel(_:) when a habit is deleted or archived.
//
//  4. Call rescheduleAll(from:) on app foreground to keep everything fresh.
//     This only touches "lurelia.habit." prefixed identifiers.
//
//  NOTIFICATION IDENTIFIERS:
//  ─────────────────────────
//  "lurelia.habit.<habit.id.uuidString>.<timeIndex>"
//  e.g. "lurelia.habit.A1B2C3D4-....0"
//       "lurelia.habit.A1B2C3D4-....1"

import Foundation
import ActivityKit
import AlarmKit
import SwiftData
import SwiftUI
import UserNotifications
import Combine
import UIKit

@MainActor
final class HabitManager: ObservableObject {

    static let shared = HabitManager()

    private static let idPrefix = "lurelia.habit."
    static let categoryID       = "LURELIA_HABIT"
    static let logActionID      = "HABIT_LOG"
    static let skipActionID     = "HABIT_SKIP"

    @Published var isAuthorized = false

    var modelContainer: ModelContainer?

    private var isRescheduling = false
    private var lastRescheduleAt: Date?
    private let rescheduleDebounce: TimeInterval = 5

    private init() {}

    // MARK: - Setup

    /// Call once from LureliaApp / AppDelegate after the modelContainer is available.
    func setup(container: ModelContainer) {
        modelContainer = container
        registerNotificationCategory()
        refreshAuthorizationStatus()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let c = self.modelContainer else { return }
                self.rescheduleAll(from: c)
            }
        }

        rescheduleAll(from: container)
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            print("❌ [HabitManager] Permission error: \(error)")
            return false
        }
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Schedule

    /// Schedule all pending daily notifications for a habit.
    /// Replaces any existing notifications for this habit.
    func schedule(_ habit: LureliaHabit) {
        cancel(habit)

        guard !habit.isArchived, !habit.timesOfDay.isEmpty else { return }

        let content = makeContent(for: habit)

        for (index, timeStr) in habit.timesOfDay.enumerated() {
            let (h, m) = parseHHMM(timeStr)
            guard let fireDate = nextDailyOccurrence(hour: h, minute: m, daysOfWeek: habit.reminderDaysOfWeek) else {
                print("⚠️ [HabitManager] Could not compute next occurrence for '\(habit.title)' time \(timeStr)")
                continue
            }

            let comps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id      = notificationID(for: habit, index: index)

            addRequest(id: id, content: content, trigger: trigger)
            print("⏰ [HabitManager] Scheduled '\(habit.title)' [\(timeStr)] → \(fireDate)")
        }

        scheduleAlarmIfNeeded(for: habit)
    }

    // MARK: - Cancel

    /// Cancel all pending notifications for a habit.
    func cancel(_ habit: LureliaHabit) {
        let ids = (0..<20).map { notificationID(for: habit, index: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        cancelAlarmIfNeeded(for: habit)
        print("🧹 [HabitManager] Cancelled notifications for '\(habit.title)'")
    }

    func cancelAll() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            print("🧹 [HabitManager] Cancelled all \(ids.count) habit notifications")
        }
    }

    // MARK: - Reschedule All

    /// Rebuild every active habit's notifications from the model store.
    /// Safe to call on foreground — debounced to avoid thrashing.
    func rescheduleAll(from container: ModelContainer) {
        guard !isRescheduling else { return }
        if let last = lastRescheduleAt, Date().timeIntervalSince(last) < rescheduleDebounce { return }

        isRescheduling   = true
        lastRescheduleAt = Date()
        defer { isRescheduling = false }

        Task { @MainActor in
            let context    = container.mainContext
            let descriptor = FetchDescriptor<LureliaHabit>()
            do {
                let habits = try context.fetch(descriptor)

                // Clear all existing habit notifications before rebuilding
                let center  = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let oldIDs  = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
                if !oldIDs.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: oldIDs)
                }

                let active = habits.filter { !$0.isArchived && !$0.timesOfDay.isEmpty }
                print("🔁 [HabitManager] Rebuilding notifications for \(active.count) habits")
                for habit in habits {
                    cancelAlarmIfNeeded(for: habit)
                }
                for habit in active { schedule(habit) }
            } catch {
                print("❌ [HabitManager] rescheduleAll fetch error: \(error)")
            }
        }
    }

    // MARK: - Action Handling

    /// Call from AppDelegate.userNotificationCenter(_:didReceive:).
    /// Returns true if the notification belonged to a habit and was handled.
    @discardableResult
    func handleResponse(_ response: UNNotificationResponse, container: ModelContainer) async -> Bool {
        let userInfo = response.notification.request.content.userInfo
        guard let habitIDStr = userInfo["habitID"] as? String,
              let habitID    = UUID(uuidString: habitIDStr) else { return false }

        let actionID = response.actionIdentifier
        let context  = container.mainContext

        guard let habit = try? context.fetch(FetchDescriptor<LureliaHabit>())
                .first(where: { $0.id == habitID }) else { return true }

        let todayStart = Calendar.current.startOfDay(for: Date())
        var didMutate = false

        switch actionID {
        case Self.logActionID, UNNotificationDefaultActionIdentifier:
            // Quick-log one completion directly from the notification
            let cap = habit.target
            if let existing = habit.todaysLog() {
                existing.habitIDString = habit.id.uuidString
                if existing.count < cap {
                    existing.count  += 1
                    existing.updatedAt = Date()
                    habit.updatedAt    = Date()
                    didMutate = true
                }
            } else {
                let log = LureliaHabitLog(habit: habit, dayStart: todayStart, count: 1)
                context.insert(log)
                habit.logs = (habit.logs ?? []) + [log]
                habit.updatedAt = Date()
                didMutate = true
            }
            try? context.save()
            print("✅ [HabitManager] Quick-logged '\(habit.title)' from notification")

        case Self.skipActionID:
            // Skip today directly from the notification
            if habit.todaysSkip() == nil, habit.todaysLog() == nil {
                let skip = LureliaHabitSkip(habit: habit, dayStart: todayStart)
                context.insert(skip)
                habit.skips = (habit.skips ?? []) + [skip]
                habit.updatedAt = Date()
                didMutate = true
                try? context.save()
                print("⏭ [HabitManager] Skipped '\(habit.title)' from notification")
            }

        default:
            break
        }

        // Reschedule so the next occurrence is queued
        schedule(habit)
        if didMutate {
            LureliaWidgetReloads.reloadHabits()
        }
        return true
    }

    // MARK: - Private Helpers

    private func registerNotificationCategory() {
        let logAction = UNNotificationAction(
            identifier: Self.logActionID,
            title: "Log It",
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: Self.skipActionID,
            title: "Skip Today",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [logAction, skipAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Merge with existing categories rather than replacing them
        UNUserNotificationCenter.current().getNotificationCategories { existing in
            var updated = existing.filter { $0.identifier != Self.categoryID }
            updated.insert(category)
            UNUserNotificationCenter.current().setNotificationCategories(updated)
        }
    }

    private func makeContent(for habit: LureliaHabit) -> UNMutableNotificationContent {
        let content        = UNMutableNotificationContent()
        content.title      = habit.title
        content.body       = habit.details?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
                             ?? "Time to log your habit."
        content.sound      = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo   = ["habitID": habit.id.uuidString]
        return content
    }

    private func notificationID(for habit: LureliaHabit, index: Int) -> String {
        "\(Self.idPrefix)\(habit.id.uuidString).\(index)"
    }

    private func addRequest(id: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ [HabitManager] Failed to schedule '\(id)': \(error)") }
            else { print("✅ [HabitManager] Scheduled: \(id)") }
        }
    }

    /// Returns the next calendar date for a given hour:minute >= now,
    /// restricted to `daysOfWeek` if non-empty (1=Sun … 7=Sat).
    private func nextDailyOccurrence(hour: Int, minute: Int, daysOfWeek: [Int]) -> Date? {
        let cal = Calendar.current
        let now = Date()

        var comps    = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        guard var candidate = cal.date(from: comps) else { return nil }

        // Advance until we land on an allowed weekday (or any day if unrestricted)
        for _ in 0..<14 {
            if candidate > now {
                if daysOfWeek.isEmpty { return candidate }
                let wd = cal.component(.weekday, from: candidate)
                if daysOfWeek.contains(wd) { return candidate }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: candidate) else { break }
            candidate = next
        }
        return nil
    }

    private func parseHHMM(_ str: String) -> (Int, Int) {
        let parts = str.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        if parts.count == 2,
           let h = Int(parts[0]), let m = Int(parts[1]),
           (0...23).contains(h), (0...59).contains(m) {
            return (h, m)
        }
        return (9, 0)
    }

    // MARK: - AlarmKit

    private func scheduleAlarmIfNeeded(for habit: LureliaHabit) {
        guard habit.alarmEnabled, !habit.isArchived else { return }
        let selectedTimes = uniqueTimes(habit.alarmFireTimes)
        let activeAlarmTimes = selectedTimes.isEmpty
            ? Array(uniqueTimes(habit.timesOfDay).prefix(1))
            : selectedTimes

        guard !activeAlarmTimes.isEmpty else { return }

        for fireTime in activeAlarmTimes {
            let (hour, minute) = parseHHMM(fireTime)
            guard let alarmDate = nextDailyOccurrence(
                hour: hour,
                minute: minute,
                daysOfWeek: habit.reminderDaysOfWeek
            ) else {
                print("⚠️ [HabitManager] Could not compute alarm date for '\(habit.title)' at \(fireTime)")
                continue
            }

            let alarmID = habit.alarmUUID(forFireTime: fireTime)
            scheduleAlarm(
                habit: habit,
                alarmID: alarmID,
                alarmDate: alarmDate,
                fireTime: fireTime
            )
        }
    }

    private func scheduleAlarm(
        habit: LureliaHabit,
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
                        print("⚠️ [HabitManager] Alarm authorization was not granted for '\(habit.title)'")
                        return
                    }
                case .denied:
                    print("⚠️ [HabitManager] Alarm authorization denied for '\(habit.title)'")
                    return
                }

                let alert = AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: habit.title)
                )
                let metadata = LureliaHabitAlarmMetadata(
                    habitID: habit.id,
                    title: habit.title,
                    icon: habit.iconName ?? "flame"
                )
                let attributes = AlarmAttributes(
                    presentation: AlarmPresentation(alert: alert),
                    metadata: metadata,
                    tintColor: LColors.gradientBlue
                )
                let soundName = habit.alarmSoundName?.trimmingCharacters(in: .whitespacesAndNewlines)
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
                print("✅ [HabitManager] Scheduled AlarmKit alarm")
                print("   • Title: \(habit.title)")
                print("   • Alarm ID: \(alarmID)")
                print("   • Fire Date: \(alarmDate)")
                print("   • Time Slot: \(fireTime)")
                print("   • Sound: \(soundName ?? "default")")
            } catch {
                print("❌ [HabitManager] AlarmKit schedule error for '\(habit.title)': \(error)")
            }
        }
    }

    private func cancelAlarmIfNeeded(for habit: LureliaHabit) {
        guard #available(iOS 26.0, *) else { return }

        var alarmIDs = habit.alarmIdentifiers.map(\.id)
        if let rawID = habit.alarmID,
           let legacyAlarmID = UUID(uuidString: rawID) {
            alarmIDs.append(legacyAlarmID)
        }

        for alarmID in Array(Set(alarmIDs)) {
            do {
                try AlarmManager.shared.cancel(id: alarmID)
                print("🧹 [HabitManager] Cancelled AlarmKit alarm for '\(habit.title)'")
                print("   • Alarm ID: \(alarmID)")
            } catch {
                print("⚠️ [HabitManager] AlarmKit cancel skipped for '\(habit.title)': \(error)")
            }
        }
    }

    private func uniqueTimes(_ times: [String]) -> [String] {
        Array(
            Set(times.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        )
        .filter { !$0.isEmpty }
        .sorted()
    }
}

// MARK: - LureliaHabit notification fields
//
// These properties live as an extension rather than in the model itself
// so the SwiftData schema stays stable. Notification settings are derived
// from them but never persisted as SwiftData attributes — they are stored
// in the plain JSON fields below.

extension LureliaHabit {

    // MARK: - Reminder toggle

    /// Whether this habit has notifications enabled.
    /// Backed by a plain persisted Bool on the model.
    var reminderEnabled: Bool {
        get { _reminderEnabled }
        set { _reminderEnabled = newValue; updatedAt = Date() }
    }

    // MARK: - Times of day

    /// Fire times as "HH:mm" 24-hour strings, e.g. ["08:00", "20:00"].
    /// Stored as JSON in `timesOfDayStorage`.
    var timesOfDay: [String] {
        get {
            guard let data = timesOfDayStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                timesOfDayStorage = "[]"
                return
            }
            timesOfDayStorage = json
            updatedAt = Date()
        }
    }

    // MARK: - Days of week restriction

    /// Optional weekday restriction (1=Sun … 7=Sat, matching Calendar.component(.weekday)).
    /// Empty means fire every day. Stored as JSON in `reminderDaysOfWeekStorage`.
    var reminderDaysOfWeek: [Int] {
        get {
            guard let data = reminderDaysOfWeekStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                reminderDaysOfWeekStorage = "[]"
                return
            }
            reminderDaysOfWeekStorage = json
            updatedAt = Date()
        }
    }

    // MARK: - AlarmKit

    var alarmFireTimes: [String] {
        get {
            guard let data = alarmFireTimesStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                alarmFireTimesStorage = "[]"
                return
            }
            alarmFireTimesStorage = json
            updatedAt = Date()
        }
    }

    var alarmIdentifiers: [LureliaHabitAlarmIdentifier] {
        get {
            guard let data = alarmIDsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LureliaHabitAlarmIdentifier].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                alarmIDsStorage = "[]"
                return
            }
            alarmIDsStorage = json
            updatedAt = Date()
        }
    }

    func alarmUUID(forFireTime fireTime: String) -> UUID {
        let normalizedFireTime = fireTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = alarmIdentifiers.first(where: { $0.fireTime == normalizedFireTime }) {
            return existing.id
        }

        let newIdentifier = LureliaHabitAlarmIdentifier(fireTime: normalizedFireTime)
        alarmIdentifiers.append(newIdentifier)
        return newIdentifier.id
    }

    func keepAlarmIdentifiers(for fireTimes: [String]) {
        let selectedFireTimes = Set(fireTimes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        var identifiers = alarmIdentifiers

        for fireTime in selectedFireTimes where !identifiers.contains(where: { $0.fireTime == fireTime }) {
            identifiers.append(LureliaHabitAlarmIdentifier(fireTime: fireTime))
        }

        alarmIdentifiers = identifiers.sorted { $0.fireTime < $1.fireTime }
    }
}

struct LureliaHabitAlarmIdentifier: Codable, Identifiable, Hashable {
    var id: UUID
    var fireTime: String

    init(id: UUID = UUID(), fireTime: String) {
        self.id = id
        self.fireTime = fireTime
    }
}

// MARK: - String helper

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
}
