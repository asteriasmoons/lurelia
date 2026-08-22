//
//  ReminderActionManager.swift
//  Lurelia
//

import Foundation
import SwiftData
import WidgetKit

@MainActor
enum ReminderActionManager {

    // MARK: - Delete

    static func deleteReminder(
        _ reminder: LureliaReminder,
        in modelContext: ModelContext
    ) {
        LureliaNotificationManager.shared.cancelReminder(reminder)

        modelContext.delete(reminder)

        do {
            try modelContext.save()
        } catch {
            print("❌ Reminder delete save failed: \(error)")
        }

        LureliaWidgetReloads.reloadAll()
        LureliaWidgetReloads.reloadAll()
    }

    // MARK: - Complete

    static func completeReminderOccurrence(
        _ reminder: LureliaReminder,
        in modelContext: ModelContext
    ) async {
        let completedAt = exactFireTime(from: reminder.nextFireAt ?? reminder.scheduledDate)

        await LureliaNotificationManager.shared.cancelReminder(reminder)

        reminder.updatedAt = Date()
        addHistoryEntry(
            reminder: reminder,
            action: .completed,
            occurrenceDate: completedAt,
            in: modelContext
        )

        var timestamps = reminder.completionTimestamps
        timestamps.append(completedAt)
        reminder.completionTimestamps = timestamps

        if reminder.repeatUnit != .none,
           let next = nextScheduledDate(after: completedAt, for: reminder) {

            let advancesToNewDay = !Calendar.current.isDate(next, inSameDayAs: completedAt)

            if hasMultipleFireTimes(reminder) || advancesToNewDay {
                resetChecklistCompletion(for: reminder)
            }

            reminder.nextFireAt = next

            if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                reminder.scheduledDate = primaryFireDate(onSameDayAs: next, for: reminder)
            }
        } else {
            reminder.isCompleted = true
            reminder.completedAt = completedAt
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Reminder completion save failed: \(error)")
        }

        LureliaWidgetReloads.reloadAll()
        LureliaWidgetReloads.reloadAll()

        if reminder.repeatUnit != .none && reminder.isEnabled {
            await LureliaNotificationManager.shared.scheduleReminder(reminder)
        }
    }

    // MARK: - Skip

    static func skipReminderOccurrence(
        _ reminder: LureliaReminder,
        in modelContext: ModelContext
    ) async {
        let skippedAt = exactFireTime(from: reminder.nextFireAt ?? reminder.scheduledDate)

        await LureliaNotificationManager.shared.cancelReminder(reminder)

        reminder.updatedAt = Date()
        addHistoryEntry(
            reminder: reminder,
            action: .skipped,
            occurrenceDate: skippedAt,
            in: modelContext
        )

        var timestamps = reminder.skippedTimestamps
        timestamps.append(skippedAt)
        reminder.skippedTimestamps = timestamps

        if let next = nextScheduledDate(after: skippedAt, for: reminder) {
            let advancesToNewDay = !Calendar.current.isDate(next, inSameDayAs: skippedAt)

            if hasMultipleFireTimes(reminder) || advancesToNewDay {
                resetChecklistCompletion(for: reminder)
            }

            reminder.nextFireAt = next

            if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                reminder.scheduledDate = primaryFireDate(onSameDayAs: next, for: reminder)
            }
        } else {
            resetChecklistCompletion(for: reminder)
            reminder.isEnabled = false
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Reminder skip save failed: \(error)")
        }

        LureliaWidgetReloads.reloadAll()
        LureliaWidgetReloads.reloadAll()

        if reminder.isEnabled {
            await LureliaNotificationManager.shared.scheduleReminder(reminder)
        }
    }

    // MARK: - History

    private static func addHistoryEntry(
        reminder: LureliaReminder,
        action: LureliaReminderHistoryAction,
        occurrenceDate: Date,
        in modelContext: ModelContext
    ) {
        let key = historyOccurrenceKey(occurrenceDate)
        let descriptor = FetchDescriptor<LureliaReminderHistory>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        let alreadyExists = all.contains { entry in
            entry.reminderID == reminder.id &&
            entry.action == action &&
            historyOccurrenceKey(entry.occurrenceDate) == key
        }

        guard !alreadyExists else { return }

        let entry = LureliaReminderHistory(
            reminder: reminder,
            action: action,
            occurrenceDate: occurrenceDate,
            actionDate: Date()
        )

        modelContext.insert(entry)
    }

    private static func historyOccurrenceKey(_ date: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)-\(c.hour ?? 0)-\(c.minute ?? 0)"
    }

    // MARK: - Checklist

    private static func hasMultipleFireTimes(_ reminder: LureliaReminder) -> Bool {
        Set(resolvedTimesOfDay(for: reminder)).count > 1
    }

    private static func resetChecklistCompletion(for reminder: LureliaReminder) {
        var items = reminder.checklistItems
        guard items.contains(where: { $0.isCompleted }) else { return }

        for index in items.indices {
            items[index].isCompleted = false
            items[index].updatedAt = Date()
        }

        reminder.checklistItems = items
        reminder.updatedAt = Date()
    }
    
    // MARK: - Checklist Occurrence Reset

    static func resetChecklistIfNeededForCurrentOccurrence(
        _ reminder: LureliaReminder,
        in modelContext: ModelContext
    ) {
        guard reminder.repeatUnit != .none else { return }
        guard reminder.checklistItems.contains(where: { $0.isCompleted }) else { return }

        let calendar = Calendar.current
        let next = reminder.nextFireAt ?? reminder.scheduledDate

        let completedThisOccurrenceDay = reminder.completionTimestamps.contains {
            calendar.isDate($0, inSameDayAs: next)
        }

        if !completedThisOccurrenceDay {
            resetChecklistCompletion(for: reminder)

            do {
                try modelContext.save()
            } catch {
                print("❌ Checklist reset save failed: \(error)")
            }
        }
    }

    // MARK: - Date Helpers

    private static func exactFireTime(from candidate: Date) -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: candidate)
        c.second = 0
        return cal.date(from: c) ?? candidate
    }

    private static func primaryFireDate(
        onSameDayAs date: Date,
        for reminder: LureliaReminder
    ) -> Date {
        let cal = Calendar.current
        var day = cal.dateComponents([.year, .month, .day], from: date)
        let time = cal.dateComponents([.hour, .minute, .second], from: reminder.scheduledDate)

        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second ?? 0

        return cal.date(from: day) ?? date
    }

    private static func nextScheduledDate(
        after date: Date,
        for reminder: LureliaReminder
    ) -> Date? {
        let calendar = Calendar.current
        let allSameDayFires = allFireTimesOnSameDay(
            as: date,
            for: reminder,
            using: calendar
        )

        if let nextSameDay = allSameDayFires.filter({ $0 > date }).min() {
            return nextSameDay
        }

        return nextOccurrenceAfter(
            date: date,
            for: reminder,
            calendar: calendar
        )
    }

    private static func allFireTimesOnSameDay(
        as refDate: Date,
        for reminder: LureliaReminder,
        using calendar: Calendar
    ) -> [Date] {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: refDate)
        let times = resolvedTimesOfDay(for: reminder)

        return times.compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")

            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1])
            else {
                return nil
            }

            var c = dayComponents
            c.hour = hour
            c.minute = minute
            c.second = 0

            return calendar.date(from: c)
        }
        .sorted()
    }

    private static func resolvedTimesOfDay(for reminder: LureliaReminder) -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }

        if !stored.isEmpty {
            return stored
        }

        let cal = Calendar.current

        let hour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : cal.component(.hour, from: reminder.scheduledDate)

        let minute = reminder.primaryMinute != -1
            ? reminder.primaryMinute
            : cal.component(.minute, from: reminder.scheduledDate)

        var times = [String(format: "%02d:%02d", hour, minute)]

        for fireTime in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
        }

        return times
    }

    private static func nextOccurrenceAfter(
        date: Date,
        for reminder: LureliaReminder,
        calendar: Calendar
    ) -> Date? {
        let interval = max(1, reminder.repeatInterval)
        var next = reminder.scheduledDate

        func earliestFireOn(_ day: Date) -> Date? {
            allFireTimesOnSameDay(
                as: day,
                for: reminder,
                using: calendar
            )
            .filter { $0 > date }
            .min()
        }

        switch reminder.repeatUnit {
        case .minutes:
            repeat {
                guard let d = calendar.date(byAdding: .minute, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return next

        case .hours:
            repeat {
                guard let d = calendar.date(byAdding: .hour, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return next

        case .days:
            repeat {
                guard let d = calendar.date(byAdding: .day, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return earliestFireOn(next) ?? next

        case .weeks:
            if reminder.repeatWeekdays.isEmpty {
                repeat {
                    guard let d = calendar.date(byAdding: .weekOfYear, value: interval, to: next) else { return nil }
                    next = d
                } while next <= date
                return earliestFireOn(next) ?? next
            }

            let weekdays = Set(reminder.repeatWeekdays)
            let start = calendar.startOfDay(for: date)

            for offset in 1...370 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                guard weekdays.contains(calendar.component(.weekday, from: day)) else { continue }

                if let fire = earliestFireOn(day) {
                    return fire
                }
            }

            return nil

        case .months:
            repeat {
                guard let d = calendar.date(byAdding: .month, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return earliestFireOn(next) ?? next

        case .years:
            repeat {
                guard let d = calendar.date(byAdding: .year, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return earliestFireOn(next) ?? next

        case .none:
            return nil
        }
    }
}
