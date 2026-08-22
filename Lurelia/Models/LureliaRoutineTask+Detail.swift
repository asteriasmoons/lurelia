//
//  LureliaRoutineTask+Detail.swift
//  Lurelia
//
//  Per-task blueprint helpers: sorted child-model accessors, scheduling
//  helpers, and statistics for individual routine tasks. The underlying
//  content (steps / supplies / obstacles / history) lives in dedicated
//  @Model child entities (see LureliaRoutineTaskContent.swift).
//

import Foundation
import SwiftData

// MARK: - Trigger Type (mirrors habit Cue type)

extension LureliaRoutineTask {

    var triggerType: LureliaCueType? {
        get {
            guard let raw = triggerTypeRaw else { return nil }
            return LureliaCueType(rawValue: raw)
        }
        set {
            triggerTypeRaw = newValue?.rawValue
        }
    }
}

// MARK: - Sorted Child Accessors

extension LureliaRoutineTask {

    var sortedSteps: [LureliaRoutineTaskStep] {
        (stepItems ?? [])
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedSupplies: [LureliaRoutineTaskSupply] {
        (supplyItems ?? [])
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedObstacles: [LureliaRoutineTaskObstacle] {
        (obstacleItems ?? [])
            .filter { !$0.obstacle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedHistory: [LureliaRoutineTaskHistoryEntry] {
        (historyItems ?? []).sorted { $0.date > $1.date }
    }
}

// MARK: - Schedule Helpers

extension LureliaRoutineTask {

    var dueDateComponents: DateComponents {
        DateComponents(hour: dueHour, minute: dueMinute)
    }

    var formattedDueTime: String {
        var components = DateComponents()
        components.hour = dueHour
        components.minute = dueMinute

        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%d:%02d", dueHour, dueMinute)
        }

        return date.formatted(date: .omitted, time: .shortened)
    }

    var notificationCount: Int {
        guard notificationsEnabled else { return 0 }
        return max(notificationLeadMinutes.count, 1)
    }

    /// The next `Date` this task's due time occurs, respecting configured days.
    func nextDueDate(after reference: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard hasDueTime else { return nil }

        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: reference) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = dueHour
            comps.minute = dueMinute
            comps.second = 0
            guard let candidate = calendar.date(from: comps) else { continue }

            if candidate <= reference { continue }

            if repeatsOnDays && !scheduledDays.isEmpty {
                let weekday = calendar.component(.weekday, from: candidate)
                if !scheduledDays.contains(weekday) { continue }
            }

            return candidate
        }

        return nil
    }
}

// MARK: - Statistics

extension LureliaRoutineTask {

    private var allHistory: [LureliaRoutineTaskHistoryEntry] {
        historyItems ?? []
    }

    var completedHistoryCount: Int {
        allHistory.filter { $0.wasCompleted }.count
    }

    var skippedHistoryCount: Int {
        allHistory.filter { !$0.wasCompleted }.count
    }

    var totalHistoryCount: Int {
        allHistory.count
    }

    var hasStatistics: Bool {
        !allHistory.isEmpty
    }

    /// 0...1 completion rate across recorded history.
    var completionRate: Double {
        let total = totalHistoryCount
        guard total > 0 else { return 0 }
        return Double(completedHistoryCount) / Double(total)
    }

    /// Average completion duration, in seconds, across completed entries that
    /// recorded a duration. Returns 0 when there is no timing data.
    var averageDurationSeconds: Int {
        let durations = allHistory
            .filter { $0.wasCompleted && $0.durationSeconds > 0 }
            .map { $0.durationSeconds }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / durations.count
    }

    /// Fastest recorded completion, in seconds. Returns 0 when unavailable.
    var fastestDurationSeconds: Int {
        allHistory
            .filter { $0.wasCompleted && $0.durationSeconds > 0 }
            .map { $0.durationSeconds }
            .min() ?? 0
    }

    /// Consecutive-day streak of completions ending today or yesterday.
    var currentStreak: Int {
        let calendar = Calendar.current
        let completedDays = allHistory
            .filter { $0.wasCompleted }
            .map { calendar.startOfDay(for: $0.date) }
        let unique = Array(Set(completedDays)).sorted(by: >)
        guard !unique.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        for day in unique {
            if day == cursor || day == calendar.date(byAdding: .day, value: -1, to: cursor) {
                streak += 1
                cursor = day
            } else if day < cursor {
                break
            }
        }
        return streak
    }
}
