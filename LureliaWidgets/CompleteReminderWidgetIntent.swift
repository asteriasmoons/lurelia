//
//  CompleteReminderWidgetIntent.swift
//  Lurelia
//

import Foundation
import AppIntents
import WidgetKit
import SwiftData

struct CompleteReminderWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var description = IntentDescription("Completes a due reminder from the widget.")

    @Parameter(title: "Reminder ID")
    var reminderID: String

    init() { }

    init(reminderID: String) {
        self.reminderID = reminderID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: reminderID) else {
            return .result()
        }

        // Access the shared SwiftData container for the widget
        let container = try LureliaWidgetShared.makeModelContainer()
        let context = ModelContext(container)

        // Fetch the reminder by ID
        let descriptor = FetchDescriptor<LureliaReminder>(
            predicate: #Predicate<LureliaReminder> { reminder in
                reminder.id == id
            }
        )

        guard let reminder = try context.fetch(descriptor).first else {
            return .result()
        }

        completeReminderOccurrence(reminder, in: context)
        try context.save()

        // Reload the widget timeline immediately
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRemindersWidget")

        return .result()
    }

    private func completeReminderOccurrence(_ reminder: LureliaReminder, in context: ModelContext) {
        let completedAt = exactFireTime(from: reminder.nextFireAt ?? reminder.scheduledDate)

        var timestamps = reminder.completionTimestamps
        if !timestamps.contains(where: { historyOccurrenceKey($0) == historyOccurrenceKey(completedAt) }) {
            timestamps.append(completedAt)
            reminder.completionTimestamps = timestamps
        }

        addHistoryEntry(
            reminder: reminder,
            action: .completed,
            occurrenceDate: completedAt,
            in: context
        )

        reminder.updatedAt = Date()

        if reminder.repeatUnit == .none {
            reminder.isCompleted = true
            reminder.completedAt = completedAt
            return
        }

        if let next = nextScheduledDate(for: reminder, after: completedAt) {
            let advancesToNewDay = !Calendar.current.isDate(next, inSameDayAs: completedAt)
            let hasMultipleFireTimes = Set(resolvedTimesOfDay(reminder)).count > 1

            if hasMultipleFireTimes || advancesToNewDay {
                resetChecklistCompletion(reminder)
            }

            reminder.nextFireAt = next

            if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                reminder.scheduledDate = primaryFireDate(for: reminder, onSameDayAs: next)
            }
        } else {
            reminder.isCompleted = true
            reminder.completedAt = completedAt
        }
    }

    private func addHistoryEntry(
        reminder: LureliaReminder,
        action: LureliaReminderHistoryAction,
        occurrenceDate: Date,
        in context: ModelContext
    ) {
        let key = historyOccurrenceKey(occurrenceDate)
        let reminderID = reminder.id

        let descriptor = FetchDescriptor<LureliaReminderHistory>(
            predicate: #Predicate<LureliaReminderHistory> { entry in
                entry.reminderID == reminderID && entry.action == action
            }
        )

        let existing = (try? context.fetch(descriptor)) ?? []
        let alreadyExists = existing.contains { entry in
            historyOccurrenceKey(entry.occurrenceDate) == key
        }

        guard !alreadyExists else { return }

        let entry = LureliaReminderHistory(
            reminder: reminder,
            action: action,
            occurrenceDate: occurrenceDate,
            actionDate: Date()
        )
        context.insert(entry)
    }

    private func resetChecklistCompletion(_ reminder: LureliaReminder) {
        var items = reminder.checklistItems
        guard items.contains(where: { $0.isCompleted }) else { return }

        for index in items.indices {
            items[index].isCompleted = false
            items[index].updatedAt = Date()
        }

        reminder.checklistItems = items
        reminder.updatedAt = Date()
    }

    private func resolvedTimesOfDay(_ reminder: LureliaReminder) -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        if !stored.isEmpty { return stored }

        let calendar = Calendar.current
        let primaryHour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : calendar.component(.hour, from: reminder.scheduledDate)

        let primaryMinute = reminder.primaryMinute != -1
            ? reminder.primaryMinute
            : calendar.component(.minute, from: reminder.scheduledDate)

        var times = [String(format: "%02d:%02d", primaryHour, primaryMinute)]

        for fireTime in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
        }

        return times
    }

    private func exactFireTime(from candidate: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate)
        components.second = 0
        return calendar.date(from: components) ?? candidate
    }

    private func historyOccurrenceKey(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(components.hour ?? 0)-\(components.minute ?? 0)"
    }

    private func primaryFireDate(for reminder: LureliaReminder, onSameDayAs date: Date) -> Date {
        let calendar = Calendar.current
        var day = calendar.dateComponents([.year, .month, .day], from: date)
        let time = calendar.dateComponents([.hour, .minute, .second], from: reminder.scheduledDate)

        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second ?? 0

        return calendar.date(from: day) ?? date
    }

    private func nextScheduledDate(for reminder: LureliaReminder, after date: Date) -> Date? {
        let calendar = Calendar.current
        let allSameDayFires = allFireTimesOnSameDay(for: reminder, as: date, using: calendar)

        if let nextSameDay = allSameDayFires.filter({ $0 > date }).min() {
            return nextSameDay
        }

        return nextOccurrenceAfter(reminder: reminder, date: date, calendar: calendar)
    }

    private func allFireTimesOnSameDay(
        for reminder: LureliaReminder,
        as referenceDate: Date,
        using calendar: Calendar
    ) -> [Date] {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        let times = resolvedTimesOfDay(reminder)

        return times.compactMap { timeString -> Date? in
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1])
            else {
                return nil
            }

            var components = dayComponents
            components.hour = hour
            components.minute = minute
            components.second = 0

            return calendar.date(from: components)
        }
        .sorted()
    }

    private func nextOccurrenceAfter(
        reminder: LureliaReminder,
        date: Date,
        calendar: Calendar
    ) -> Date? {
        let interval = max(1, reminder.repeatInterval)
        var next = reminder.scheduledDate

        func earliestFireOn(_ day: Date) -> Date? {
            allFireTimesOnSameDay(for: reminder, as: day, using: calendar)
                .filter { $0 > date }
                .min()
        }

        switch reminder.repeatUnit {
        case .minutes:
            repeat {
                guard let newDate = calendar.date(byAdding: .minute, value: interval, to: next) else { return nil }
                next = newDate
            } while next <= date
            return next

        case .hours:
            repeat {
                guard let newDate = calendar.date(byAdding: .hour, value: interval, to: next) else { return nil }
                next = newDate
            } while next <= date
            return next

        case .days:
            repeat {
                guard let newDate = calendar.date(byAdding: .day, value: interval, to: next) else { return nil }
                next = newDate
            } while next <= date
            return earliestFireOn(next) ?? next

        case .weeks:
            if reminder.repeatWeekdays.isEmpty {
                repeat {
                    guard let newDate = calendar.date(byAdding: .weekOfYear, value: interval, to: next) else { return nil }
                    next = newDate
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
                guard let newDate = calendar.date(byAdding: .month, value: interval, to: next) else { return nil }
                next = newDate
            } while next <= date
            return earliestFireOn(next) ?? next

        case .years:
            repeat {
                guard let newDate = calendar.date(byAdding: .year, value: interval, to: next) else { return nil }
                next = newDate
            } while next <= date
            return earliestFireOn(next) ?? next

        case .none:
            return nil
        }
    }
}
