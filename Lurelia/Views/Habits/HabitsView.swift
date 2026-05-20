//
//  HabitsView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LureliaHabit.createdAt)
    private var habits: [LureliaHabit]

    @State private var showNewHabit = false
    @State private var editingHabit: LureliaHabit? = nil
    @State private var historyHabit: LureliaHabit? = nil

    private var activeHabits: [LureliaHabit] { habits.filter { !$0.isArchived } }
    private var archivedHabits: [LureliaHabit] { habits.filter { $0.isArchived } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Header

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Habits")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Build consistency, one day at a time.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()

                        Button { showNewHabit = true } label: {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // MARK: - Empty State

                    if habits.isEmpty {
                        LureliaHabitsEmptyState {
                            showNewHabit = true
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 32)
                    } else {

                        // MARK: - Streak Summary

                        if !activeHabits.isEmpty {
                            LureliaHabitStreakSummary(habits: activeHabits)
                                .padding(.horizontal, 24)
                        }

                        // MARK: - Active Habits

                        if !activeHabits.isEmpty {
                            VStack(spacing: 14) {
                                ForEach(activeHabits) { habit in
                                    LureliaHabitCard(
                                        habit: habit,
                                        onEdit: { editingHabit = habit },
                                        onHistory: { historyHabit = habit }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // MARK: - Archived

                        if !archivedHabits.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ARCHIVED")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .tracking(0.8)
                                    .padding(.horizontal, 24)

                                VStack(spacing: 14) {
                                    ForEach(archivedHabits) { habit in
                                        LureliaHabitCard(
                                            habit: habit,
                                            onEdit: { editingHabit = habit },
                                            onHistory: { historyHabit = habit }
                                        )
                                        .opacity(0.6)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    Spacer().frame(height: 110)
                }
            }
        }
        .sheet(isPresented: $showNewHabit) {
            LureliaNewHabitSheet { showNewHabit = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingHabit) { habit in
            LureliaEditHabitSheet(habit: habit) { editingHabit = nil }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .overlay {
            if let habit = historyHabit {
                LureliaHabitHistoryOverlay(habit: habit) {
                    historyHabit = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(80)
            }
        }
    }
}

// MARK: - Empty State

private struct LureliaHabitsEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image("flame")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .foregroundStyle(LGradients.header)

            VStack(spacing: 8) {
                Text("No Habits Yet")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Start tracking a daily habit to build streaks and stay consistent over time.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button {
                onCreate()
            } label: {
                Text("Create Habit")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LGradients.header)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - Streak Summary Card

private struct LureliaHabitStreakSummary: View {
    let habits: [LureliaHabit]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image("flame")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(LGradients.header)

                Text("Habit Streak")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                ForEach(habits) { habit in
                    HStack {
                        Text(habit.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 10)

                        HStack(spacing: 6) {
                            streakPill(label: "DAYS", value: "\(strictDailyStreak(for: habit))")
                            streakPill(label: "WEEKS", value: "\(strictWeeklyStreak(for: habit))")
                        }
                    }

                    if habit.id != habits.last?.id {
                        Rectangle()
                            .fill(.white.opacity(0.07))
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.20),
                                    LColors.gradientPurple.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.95),
                            LColors.gradientPurple.opacity(0.95),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
    }

    private func strictDailyStreak(for habit: LureliaHabit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let resetStart = habit.statsResetAt.map { calendar.startOfDay(for: $0) }
        var streak = 0
        var day = today
        var checkedToday = false

        while true {
            let dayStart = calendar.startOfDay(for: day)

            if let resetStart, dayStart <= resetStart {
                break
            }

            let completed = (habit.logs ?? []).contains { log in
                calendar.isDate(log.dayStart, inSameDayAs: dayStart) && log.count >= habit.target
            }

            if completed {
                streak += 1
            } else if checkedToday {
                break
            }

            checkedToday = true

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }

        return streak
    }

    private func strictWeeklyStreak(for habit: LureliaHabit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let resetStart = habit.statsResetAt.map { calendar.startOfDay(for: $0) }
        var streak = 0
        var weekAnchor = today

        while true {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekAnchor) else {
                break
            }

            if let resetStart, weekInterval.start <= resetStart {
                break
            }

            let completedDaysInWeek = (habit.logs ?? []).filter { log in
                log.dayStart >= weekInterval.start &&
                log.dayStart < weekInterval.end &&
                log.count >= habit.target
            }.count

            if completedDaysInWeek >= habit.daysPerWeek {
                streak += 1
            } else {
                break
            }

            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekAnchor) else {
                break
            }
            weekAnchor = previousWeek
        }

        return streak
    }

    @ViewBuilder
    private func streakPill(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }
}

// MARK: - Habit Card

struct LureliaHabitCard: View {
    @Environment(\.modelContext) private var modelContext

    let habit: LureliaHabit
    let onEdit: () -> Void
    let onHistory: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showResetConfirm = false
    @State private var statusNow = Date()

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }
    private var todaysLog: LureliaHabitLog? { habit.todaysLog() }
    private var todaysSkip: LureliaHabitSkip? { habit.todaysSkip() }

    private struct ScheduledTimeBadge: Hashable {
        let id: String
        let label: String
        let fireDate: Date
    }

    private var scheduledTimeBadges: [ScheduledTimeBadge] {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return todayScheduledFireTimes.map { fireDate in
            let components = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
            let normalized = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
            return ScheduledTimeBadge(
                id: normalized,
                label: formatter.string(from: fireDate),
                fireDate: fireDate
            )
        }
    }

    private var todayScheduledFireTimes: [Date] {
        guard habit.reminderEnabled else { return [] }
        let times = habit.timesOfDay.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !times.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: statusNow)
        let weekday = calendar.component(.weekday, from: today)
        let allowedWeekdays = Set(habit.reminderDaysOfWeek)
        if !allowedWeekdays.isEmpty && !allowedWeekdays.contains(weekday) { return [] }

        return times.compactMap { timeString -> Date? in
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { return nil }

            var components = calendar.dateComponents([.year, .month, .day], from: today)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }
        .sorted()
    }

    private var nextUncompletedHabitFireAtToday: Date? {
        let completedCount = habit.todaysCount
        let scheduled = todayScheduledFireTimes
        guard completedCount < scheduled.count else { return nil }
        return scheduled[completedCount]
    }

    private func isNextDueTimeBadge(_ badge: ScheduledTimeBadge) -> Bool {
        guard let nextUncompleted = nextUncompletedHabitFireAtToday else { return false }
        return abs(badge.fireDate.timeIntervalSince(nextUncompleted)) < 60
    }

    private var activeTrackingStartDay: Date {
        let calendar = Calendar.current
        let createdStart = calendar.startOfDay(for: habit.createdAt)
        if let resetAt = habit.statsResetAt {
            return max(createdStart, calendar.startOfDay(for: resetAt))
        }
        return createdStart
    }

    private var mostRecentMissedFireAtBeforeToday: Date? {
        guard habit.reminderEnabled, !habit.isCompletedToday, todaysSkip == nil else { return nil }
        let times = habit.timesOfDay.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !times.isEmpty else { return nil }

        let calendar = Calendar.current
        let allowedWeekdays = Set(habit.reminderDaysOfWeek)
        let today = calendar.startOfDay(for: statusNow)
        let startDay = activeTrackingStartDay

        for offset in 1...370 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            if dayStart < startDay { break }

            let weekday = calendar.component(.weekday, from: dayStart)
            if !allowedWeekdays.isEmpty && !allowedWeekdays.contains(weekday) { continue }

            let wasCompleted = (habit.logs ?? []).contains { log in
                calendar.isDate(log.dayStart, inSameDayAs: dayStart) && log.count >= habit.target
            }
            if wasCompleted { continue }

            let wasSkipped = (habit.skips ?? []).contains { skip in
                calendar.isDate(skip.dayStart, inSameDayAs: dayStart)
            }
            if wasSkipped { continue }

            return times.compactMap { timeString -> Date? in
                let parts = timeString.split(separator: ":")
                guard parts.count == 2,
                      let hour = Int(parts[0]),
                      let minute = Int(parts[1]) else { return nil }

                var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
                components.hour = hour
                components.minute = minute
                components.second = 0
                return calendar.date(from: components)
            }
            .sorted(by: >)
            .first
        }

        return nil
    }

    private enum HabitStatusBadgeKind {
        case overdue
        case dueNow
        case upcoming
    }

    private var habitStatusBadgeKind: HabitStatusBadgeKind? {
        guard habit.reminderEnabled, todaysSkip == nil, !habit.isCompletedToday else { return nil }

        if let nextUncompleted = nextUncompletedHabitFireAtToday {
            if nextUncompleted <= statusNow { return .dueNow }
            if Calendar.current.isDateInToday(nextUncompleted) { return .upcoming }
        }

        if mostRecentMissedFireAtBeforeToday != nil { return .overdue }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // MARK: - Title + Completion Circle

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(habit.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if let details = habit.details,
                       !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(details)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            badgePill("\(habit.daysPerWeek)/7", color: LColors.gradientBlue)
                            badgePill("\(habit.target)x/day", color: LColors.gradientPurple)

                            habitStatusBadge

                            if todaysSkip != nil {
                                badgePill("SKIPPED", color: .white.opacity(0.35))
                            }

                            if habit.isCompletedToday {
                                badgePill("DONE", color: LColors.success)
                            }
                        }

                        if !scheduledTimeBadges.isEmpty {
                            FlexibleView(
                                data: scheduledTimeBadges,
                                spacing: 6,
                                alignment: .leading
                            ) { timeBadge in
                                if isNextDueTimeBadge(timeBadge) {
                                    gradientBadgePill(timeBadge.label)
                                } else {
                                    badgePill(timeBadge.label, color: .white.opacity(0.55))
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                habitCompletionCircle
            }

            // MARK: - Progress Dots

            HStack(spacing: 6) {
                ForEach(0..<habit.target, id: \.self) { i in
                    Image(systemName: i < habit.todaysCount ? "circle.fill" : "circle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            i < habit.todaysCount
                                ? AnyShapeStyle(LGradients.header)
                                : AnyShapeStyle(Color.white.opacity(0.3))
                        )
                }
            }

            // MARK: - Progress Bar

            VStack(spacing: 5) {
                HStack {
                    Text("\(habit.todaysCount) / \(habit.target) today")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("\(Int(habit.progress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(LGradients.header)
                            .frame(width: geo.size.width * habit.progress, height: 6)
                            .animation(.spring(duration: 0.4), value: habit.progress)
                    }
                }
                .frame(height: 6)
            }

            // MARK: - Actions

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    actionButton("Edit", icon: "pencil") { onEdit() }
                    actionButton("Clear", icon: "arrow.counterclockwise") { clearToday() }
                    actionButton(todaysSkip == nil ? "Skip" : "Skipped", icon: "skipwavy", isAsset: true) { toggleSkip() }
                }

                HStack(spacing: 8) {
                    actionButton("Reset", icon: "arrow.clockwise") { showResetConfirm = true }
                    actionButton("History", icon: "clock.arrow.circlepath") { onHistory() }
                    destructiveButton("Delete", icon: "trash", isAsset: true) { showDeleteConfirm = true }
                    Spacer()
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .imageScale(.small)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.20),
                                    LColors.gradientPurple.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.95),
                            LColors.gradientPurple.opacity(0.95),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
        .alert("Delete Habit?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteHabit() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete this habit and all of its history.")
        }
        .alert("Reset Stats?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetStats() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Streaks and stats will restart from today. Past log history is kept.")
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now in
            statusNow = now
        }
    }
    // Completion Circle

    private var habitCompletionCircle: some View {
        Button {
            quickLog()
        } label: {
            ZStack {
                Circle()
                    .fill(habit.isCompletedToday ? LColors.success.opacity(0.18) : Color.clear)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                habit.isCompletedToday ? LColors.success.opacity(0.85) : LColors.gradientBlue.opacity(0.85),
                                lineWidth: 2
                            )
                    }

                if habit.isCompletedToday {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(LColors.success)
                }
            }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(todaysSkip != nil || habit.todaysCount >= habit.target)
        .opacity((todaysSkip != nil || habit.todaysCount >= habit.target) ? 0.55 : 1)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, isAsset: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Group {
                    if isAsset {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                    } else {
                        Image(systemName: icon)
                    }
                }
                Text(title)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destructiveButton(_ title: String, icon: String, isAsset: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Group {
                    if isAsset {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                    } else {
                        Image(systemName: icon)
                    }
                }
                Text(title)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(LGradients.header)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    @ViewBuilder
    private var habitStatusBadge: some View {
        switch habitStatusBadgeKind {
        case .overdue:
            badgePill("OVERDUE", color: Color(lureliaHex: "#ff9be6"))
        case .dueNow:
            badgePill("DUE NOW", color: Color(lureliaHex: "#b476ff"))
        case .upcoming:
            badgePill("UPCOMING", color: Color(lureliaHex: "#7eedff"))
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func badgePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
    }

    @ViewBuilder
    private func gradientBadgePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(LGradients.header)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            )
    }

    // MARK: - Actions

    private func quickLog() {
        let cap = habit.target

        if let existingSkip = todaysSkip {
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existingSkip.persistentModelID }
        }

        if let existing = todaysLog {
            if existing.count < cap {
                existing.count += 1
                existing.updatedAt = Date()
                habit.updatedAt = Date()
            }
            return
        }

        let newLog = LureliaHabitLog(habit: habit, dayStart: todayStart, count: 1)
        modelContext.insert(newLog)
        habit.updatedAt = Date()
    }

    private func clearToday() {
        let cal = Calendar.current
        let todayLogs = (habit.logs ?? []).filter { cal.isDate($0.dayStart, inSameDayAs: todayStart) }
        for log in todayLogs { modelContext.delete(log) }
        habit.logs = (habit.logs ?? []).filter { !cal.isDate($0.dayStart, inSameDayAs: todayStart) }
        habit.updatedAt = Date()
    }

    private func toggleSkip() {
        if let existing = todaysSkip {
            modelContext.delete(existing)
            habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existing.persistentModelID }
            habit.updatedAt = Date()
            return
        }

        if let log = todaysLog, log.count > 0 { return }

        let skip = LureliaHabitSkip(habit: habit, dayStart: todayStart)
        modelContext.insert(skip)
        habit.updatedAt = Date()
        try? modelContext.save()
    }

    private func resetStats() {
        habit.statsResetAt = Date()
        habit.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteHabit() {
        for log in habit.logs ?? [] { modelContext.delete(log) }
        for skip in habit.skips ?? [] { modelContext.delete(skip) }
        modelContext.delete(habit)
    }
}

// MARK: - History Overlay

private struct LureliaHabitHistoryOverlay: View {
    let habit: LureliaHabit
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteLog: LureliaHabitLog? = nil
    @State private var pendingDeleteSkip: LureliaHabitSkip? = nil

    private enum HistoryEntry: Identifiable {
        case log(LureliaHabitLog)
        case skip(LureliaHabitSkip)

        var id: PersistentIdentifier {
            switch self {
            case .log(let l): return l.persistentModelID
            case .skip(let s): return s.persistentModelID
            }
        }

        var date: Date {
            switch self {
            case .log(let l): return l.dayStart
            case .skip(let s): return s.dayStart
            }
        }

        var count: Int? {
            switch self {
            case .log(let l): return l.count
            case .skip: return nil
            }
        }

        var isSkipped: Bool {
            switch self {
            case .log: return false
            case .skip: return true
            }
        }
    }

    private var entries: [HistoryEntry] {
        let logs = (habit.logs ?? []).map { HistoryEntry.log($0) }
        let skips = (habit.skips ?? []).map { HistoryEntry.skip($0) }
        return (logs + skips).sorted {
            Calendar.current.startOfDay(for: $0.date) > Calendar.current.startOfDay(for: $1.date)
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {

                    // Handle
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 14)
                        .padding(.bottom, 18)

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Habit History")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(habit.title)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()

                        Button { onClose() } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    // Streak summary
                    HStack(spacing: 12) {
                        let dailyStreak = strictDailyStreak(for: habit)
                        let weeklyStreak = strictWeeklyStreak(for: habit)
                        streakBlock(label: "Daily Streak", value: "\(dailyStreak) day\(dailyStreak == 1 ? "" : "s")")
                        streakBlock(label: "Weekly Streak", value: "\(weeklyStreak) week\(weeklyStreak == 1 ? "" : "s")")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                    // Entries
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if entries.isEmpty {
                                Text("No history yet.")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                            } else {
                                ForEach(entries) { entry in
                                    historyRow(entry: entry)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .frame(maxHeight: 340)

                    // Close button
                    Button { onClose() } label: {
                        Text("Close")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LGradients.header)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .padding(.top, 8)
                }
                .frame(maxWidth: 390)
                .background {
                    ZStack {
                        LureliaBackgroundAlt()
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.98),
                                        LColors.gradientPurple.opacity(0.98),
                                        Color.white.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.25
                            )
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
                .padding(.horizontal, 18)
            }
        }
        .alert("Delete Record?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let log = pendingDeleteLog {
                    modelContext.delete(log)
                    habit.logs = (habit.logs ?? []).filter { $0.persistentModelID != log.persistentModelID }
                    pendingDeleteLog = nil
                }
                if let skip = pendingDeleteSkip {
                    modelContext.delete(skip)
                    habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != skip.persistentModelID }
                    pendingDeleteSkip = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete this history record.")
        }
    }

    private func strictDailyStreak(for habit: LureliaHabit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let resetStart = habit.statsResetAt.map { calendar.startOfDay(for: $0) }
        var streak = 0
        var day = today
        var checkedToday = false

        while true {
            let dayStart = calendar.startOfDay(for: day)

            if let resetStart, dayStart <= resetStart {
                break
            }

            let completed = (habit.logs ?? []).contains { log in
                calendar.isDate(log.dayStart, inSameDayAs: dayStart) && log.count >= habit.target
            }

            if completed {
                streak += 1
            } else if checkedToday {
                break
            }

            checkedToday = true

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }

        return streak
    }

    private func strictWeeklyStreak(for habit: LureliaHabit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let resetStart = habit.statsResetAt.map { calendar.startOfDay(for: $0) }
        var streak = 0
        var weekAnchor = today

        while true {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekAnchor) else {
                break
            }

            if let resetStart, weekInterval.start <= resetStart {
                break
            }

            let completedDaysInWeek = (habit.logs ?? []).filter { log in
                log.dayStart >= weekInterval.start &&
                log.dayStart < weekInterval.end &&
                log.count >= habit.target
            }.count

            if completedDaysInWeek >= habit.daysPerWeek {
                streak += 1
            } else {
                break
            }

            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekAnchor) else {
                break
            }
            weekAnchor = previousWeek
        }

        return streak
    }

    @ViewBuilder
    private func streakBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.6)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.18),
                            LColors.gradientPurple.opacity(0.16),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.95),
                            LColors.gradientPurple.opacity(0.95),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
    }

    @ViewBuilder
    private func historyRow(entry: HistoryEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel(entry.date))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if entry.isSkipped {
                    Text("Skipped this day")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    let count = entry.count ?? 0
                    Text("\(count) of \(habit.target) times completed")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            let count = entry.count ?? 0
            let statusLabel = entry.isSkipped ? "SKIPPED"
                : (count >= habit.target ? "DONE" : (count > 0 ? "PARTIAL" : "NONE"))
            let statusColor: Color = entry.isSkipped ? .white.opacity(0.35)
                : (count >= habit.target ? LColors.success : .white.opacity(0.35))

            Text(statusLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(statusColor.opacity(0.28), lineWidth: 1))
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.18),
                            LColors.gradientPurple.opacity(0.16),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.95),
                            LColors.gradientPurple.opacity(0.95),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
        .onLongPressGesture {
            switch entry {
            case .log(let log):
                pendingDeleteSkip = nil
                pendingDeleteLog = log
            case .skip(let skip):
                pendingDeleteLog = nil
                pendingDeleteSkip = skip
            }
            showDeleteConfirm = true
        }
    }
}

// MARK: - Schedule Form

private struct HabitScheduleForm: View {
    @Binding var daysPerWeek: Int
    @Binding var timesPerDay: Int
    var hideTimesPerDay: Bool
    var onTimesPerDayChange: (Int) -> Void

    private let allDays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Days per week — tap circles 1-7
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Days per week")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.gradientBlue)
                }

                HStack(spacing: 0) {
                    ForEach(1...7, id: \.self) { n in
                        let selected = n <= daysPerWeek
                        Button {
                            daysPerWeek = n
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    selected
                                    ? AnyShapeStyle(LGradients.header)
                                    : AnyShapeStyle(Color.white.opacity(0.06))
                                )
                                .foregroundStyle(selected ? .white : .white.opacity(0.35))
                        }
                        .buttonStyle(.plain)

                        if n < 7 {
                            Rectangle()
                                .fill(.white.opacity(0.08))
                                .frame(width: 1, height: 36)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
            }

            // Times per day — +/- counter
            if !hideTimesPerDay {
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)

                HStack {
                    Text("Times per day")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 0) {
                        Button {
                            let v = max(1, timesPerDay - 1)
                            timesPerDay = v
                            onTimesPerDayChange(v)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 1, height: 36)

                        Text("\(timesPerDay)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 36)

                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 1, height: 36)

                        Button {
                            let v = min(20, timesPerDay + 1)
                            timesPerDay = v
                            onTimesPerDayChange(v)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.95),
                            LColors.gradientPurple.opacity(0.95),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
    }
}

// MARK: - Habit Notification Kind

enum LureliaHabitNotificationKind: String, CaseIterable {
    case daily         = "Daily"
    case weekly        = "Weekly"
    case everyXHours   = "Every XH"
    case everyXMinutes = "Every XM"
}

// MARK: - Shared Notification Form

private struct HabitNotificationForm: View {
    @Binding var notificationEnabled: Bool
    @Binding var notifKind: LureliaHabitNotificationKind
    @Binding var startDate: Date
    @Binding var reminderTimes: [Date]
    @Binding var weeklyDays: Set<Int>
    @Binding var intervalValue: Int
    @Binding var intervalValueText: String
    @Binding var intervalWindowStart: Date
    @Binding var intervalWindowEnd: Date
    var timesPerDay: Int
    var daysPerWeek: Int

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Toggle row
            HStack {
                Text("NOTIFICATION")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.8)
                Spacer()
                Toggle("", isOn: $notificationEnabled)
                    .labelsHidden()
                    .tint(LColors.gradientPurple)
            }

            if notificationEnabled {

                // Start date
                controlRow(label: "Start") {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(LColors.gradientBlue)
                }

                // Kind pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LureliaHabitNotificationKind.allCases, id: \.self) { k in
                            let on = notifKind == k
                            Button {
                                notifKind = k
                            } label: {
                                Text(k.rawValue.uppercased())
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(on ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        on
                                        ? AnyShapeStyle(LGradients.header)
                                        : AnyShapeStyle(Color.white.opacity(0.08))
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(
                                            on ? Color.clear : Color.white.opacity(0.14),
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Kind-specific controls
                switch notifKind {
                case .daily:   dailyControls
                case .weekly:  weeklyControls
                case .everyXHours:   intervalControls(unit: "hours")
                case .everyXMinutes: intervalControls(unit: "minutes")
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.95),
                            LColors.gradientPurple.opacity(0.95),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
    }

    // MARK: - Daily

    @ViewBuilder
    private var dailyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(reminderTimes.indices), id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    Text(reminderTimes.count > 1 ? "TIME \(idx + 1)" : "TIME")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(0.6)
                    LureliaGradientTimeDrumPicker(
                        hour: Binding(
                            get: { Calendar.current.component(.hour, from: reminderTimes[idx]) },
                            set: { h in
                                var c = Calendar.current.dateComponents([.hour, .minute], from: reminderTimes[idx])
                                c.hour = h
                                if let d = Calendar.current.date(from: c) { reminderTimes[idx] = d }
                            }
                        ),
                        minute: Binding(
                            get: { Calendar.current.component(.minute, from: reminderTimes[idx]) },
                            set: { m in
                                var c = Calendar.current.dateComponents([.hour, .minute], from: reminderTimes[idx])
                                c.minute = m
                                if let d = Calendar.current.date(from: c) { reminderTimes[idx] = d }
                            }
                        )
                    )
                }
            }
        }
    }

    // MARK: - Weekly

    @ViewBuilder
    private var weeklyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            let picked = weeklyDays.count
            Text("Pick exactly \(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s") (\(picked)/\(daysPerWeek))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(picked == daysPerWeek ? .white : .white.opacity(0.45))

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { d in
                    let on    = weeklyDays.contains(d)
                    let atCap = !on && weeklyDays.count >= daysPerWeek
                    Button {
                        if on { weeklyDays.remove(d) }
                        else if !atCap { weeklyDays.insert(d) }
                    } label: {
                        Text(weekdays[d])
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .frame(width: 36, height: 36)
                            .background(
                                on
                                ? AnyShapeStyle(LGradients.header)
                                : AnyShapeStyle(Color.white.opacity(0.08))
                            )
                            .foregroundStyle(on ? .white : .white.opacity(0.55))
                            .clipShape(Circle())
                            .opacity(atCap ? 0.4 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(atCap)
                }
            }

            ForEach(Array(reminderTimes.indices), id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    Text(reminderTimes.count > 1 ? "TIME \(idx + 1)" : "TIME")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(0.6)
                    LureliaGradientTimeDrumPicker(
                        hour: Binding(
                            get: { Calendar.current.component(.hour, from: reminderTimes[idx]) },
                            set: { h in
                                var c = Calendar.current.dateComponents([.hour, .minute], from: reminderTimes[idx])
                                c.hour = h
                                if let d = Calendar.current.date(from: c) { reminderTimes[idx] = d }
                            }
                        ),
                        minute: Binding(
                            get: { Calendar.current.component(.minute, from: reminderTimes[idx]) },
                            set: { m in
                                var c = Calendar.current.dateComponents([.hour, .minute], from: reminderTimes[idx])
                                c.minute = m
                                if let d = Calendar.current.date(from: c) { reminderTimes[idx] = d }
                            }
                        )
                    )
                }
            }
        }
    }

    // MARK: - Interval (hours / minutes)

    @ViewBuilder
    private func intervalControls(unit: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            controlRow(label: "Every") {
                HStack(spacing: 8) {
                    Button {
                        let v = max(1, intervalValue - 1)
                        intervalValue = v; intervalValueText = "\(v)"
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    TextField("", text: $intervalValueText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 48)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                        .onChange(of: intervalValueText) { _, t in
                            if let p = Int(t.filter(\.isNumber)), p >= 1 { intervalValue = p }
                        }

                    Button {
                        let v = intervalValue + 1
                        intervalValue = v; intervalValueText = "\(v)"
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(unit)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("FROM")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.6)
                LureliaGradientTimeDrumPicker(
                    hour: Binding(
                        get: { Calendar.current.component(.hour, from: intervalWindowStart) },
                        set: { h in
                            var c = Calendar.current.dateComponents([.hour, .minute], from: intervalWindowStart)
                            c.hour = h
                            if let d = Calendar.current.date(from: c) { intervalWindowStart = d }
                        }
                    ),
                    minute: Binding(
                        get: { Calendar.current.component(.minute, from: intervalWindowStart) },
                        set: { m in
                            var c = Calendar.current.dateComponents([.hour, .minute], from: intervalWindowStart)
                            c.minute = m
                            if let d = Calendar.current.date(from: c) { intervalWindowStart = d }
                        }
                    )
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("UNTIL")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.6)
                LureliaGradientTimeDrumPicker(
                    hour: Binding(
                        get: { Calendar.current.component(.hour, from: intervalWindowEnd) },
                        set: { h in
                            var c = Calendar.current.dateComponents([.hour, .minute], from: intervalWindowEnd)
                            c.hour = h
                            if let d = Calendar.current.date(from: c) { intervalWindowEnd = d }
                        }
                    ),
                    minute: Binding(
                        get: { Calendar.current.component(.minute, from: intervalWindowEnd) },
                        set: { m in
                            var c = Calendar.current.dateComponents([.hour, .minute], from: intervalWindowEnd)
                            c.minute = m
                            if let d = Calendar.current.date(from: c) { intervalWindowEnd = d }
                        }
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func controlRow<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            content()
        }
    }
}

// MARK: - New Habit Sheet

struct LureliaNewHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    let onClose: () -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var daysPerWeek = 7
    @State private var timesPerDay = 1

    @State private var notificationEnabled = false
    @State private var notifKind: LureliaHabitNotificationKind = .daily
    @State private var startDate: Date = Date()
    @State private var reminderTimes: [Date] = [Date()]
    @State private var weeklyDays: Set<Int> = []
    @State private var intervalValue: Int = 1
    @State private var intervalValueText: String = "1"
    @State private var intervalWindowStart: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var intervalWindowEnd: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if notificationEnabled && notifKind == .weekly { return weeklyDays.count == daysPerWeek }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        formSection(label: "TITLE") {
                            textField(placeholder: "Habit title", text: $title)
                        }

                        formSection(label: "DESCRIPTION") {
                            textField(placeholder: "Optional description", text: $details)
                        }

                        formSection(label: "SCHEDULE") {
                            HabitScheduleForm(
                                daysPerWeek: $daysPerWeek,
                                timesPerDay: $timesPerDay,
                                hideTimesPerDay: notificationEnabled && (notifKind == .everyXHours || notifKind == .everyXMinutes),
                                onTimesPerDayChange: { v in syncReminderTimes(to: v) }
                            )
                        }

                        formSection(label: "NOTIFICATION") {
                            HabitNotificationForm(
                                notificationEnabled: $notificationEnabled,
                                notifKind: $notifKind,
                                startDate: $startDate,
                                reminderTimes: $reminderTimes,
                                weeklyDays: $weeklyDays,
                                intervalValue: $intervalValue,
                                intervalValueText: $intervalValueText,
                                intervalWindowStart: $intervalWindowStart,
                                intervalWindowEnd: $intervalWindowEnd,
                                timesPerDay: timesPerDay,
                                daysPerWeek: daysPerWeek
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onClose() }
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { save() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(canSave ? LColors.gradientBlue : .white.opacity(0.25))
                        .disabled(!canSave)
                }
            }
        }
        .onTapGesture { dismissKeyboard() }
    }

    private func syncReminderTimes(to count: Int) {
        while reminderTimes.count < count { reminderTimes.append(reminderTimes.last ?? Date()) }
        if reminderTimes.count > count { reminderTimes = Array(reminderTimes.prefix(count)) }
    }

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.8)
            content()
        }
    }

    @ViewBuilder
    private func textField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.95),
                                LColors.gradientPurple.opacity(0.95),
                                Color.white.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.15
                    )
            )
    }

    private func save() {
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleTrimmed.isEmpty else { return }
        let detailsTrimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTimesPerDay = (notificationEnabled && (notifKind == .everyXHours || notifKind == .everyXMinutes))
            ? computedIntervalTimesPerDay() : timesPerDay
        let habit = LureliaHabit(
            title: titleTrimmed,
            details: detailsTrimmed.isEmpty ? nil : detailsTrimmed,
            daysPerWeek: daysPerWeek,
            timesPerDay: resolvedTimesPerDay
        )
        modelContext.insert(habit)
        if notificationEnabled {
            applyNotificationSettings(to: habit)
            HabitManager.shared.schedule(habit)
        }
        onClose()
    }

    private func applyNotificationSettings(to habit: LureliaHabit) {
        habit.reminderEnabled = true
        switch notifKind {
        case .daily:
            habit.timesOfDay = reminderTimes.map { hhmm(from: $0) }
            habit.reminderDaysOfWeek = []
        case .weekly:
            habit.timesOfDay = reminderTimes.map { hhmm(from: $0) }
            habit.reminderDaysOfWeek = weeklyDays.map { $0 + 1 }.sorted()
        case .everyXHours:
            habit.timesOfDay = intervalFireTimes(intervalMinutes: max(1, intervalValue) * 60)
            habit.reminderDaysOfWeek = []
        case .everyXMinutes:
            habit.timesOfDay = intervalFireTimes(intervalMinutes: max(1, intervalValue))
            habit.reminderDaysOfWeek = []
        }
    }

    private func hhmm(from date: Date) -> String {
        String(format: "%02d:%02d",
               Calendar.current.component(.hour, from: date),
               Calendar.current.component(.minute, from: date))
    }

    private func intervalFireTimes(intervalMinutes: Int) -> [String] {
        let cal = Calendar.current
        let startTotal = cal.component(.hour, from: intervalWindowStart) * 60 + cal.component(.minute, from: intervalWindowStart)
        let endTotal   = cal.component(.hour, from: intervalWindowEnd)   * 60 + cal.component(.minute, from: intervalWindowEnd)
        guard endTotal >= startTotal, intervalMinutes > 0 else { return [] }
        var times: [String] = []
        var cursor = startTotal
        while cursor <= endTotal {
            times.append(String(format: "%02d:%02d", cursor / 60, cursor % 60))
            cursor += intervalMinutes
        }
        return times
    }

    private func computedIntervalTimesPerDay() -> Int {
        let cal = Calendar.current
        let startTotal = cal.component(.hour, from: intervalWindowStart) * 60 + cal.component(.minute, from: intervalWindowStart)
        let endTotal   = cal.component(.hour, from: intervalWindowEnd)   * 60 + cal.component(.minute, from: intervalWindowEnd)
        let intervalMins = notifKind == .everyXHours ? max(1, intervalValue) * 60 : max(1, intervalValue)
        guard endTotal >= startTotal, intervalMins > 0 else { return 1 }
        return max(1, (endTotal - startTotal) / intervalMins + 1)
    }
}

// MARK: - Edit Habit Sheet

struct LureliaEditHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var habit: LureliaHabit
    let onClose: () -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var daysPerWeek = 7
    @State private var timesPerDay = 1

    @State private var notificationEnabled = false
    @State private var notifKind: LureliaHabitNotificationKind = .daily
    @State private var startDate: Date = Date()
    @State private var reminderTimes: [Date] = [Date()]
    @State private var weeklyDays: Set<Int> = []
    @State private var intervalValue: Int = 1
    @State private var intervalValueText: String = "1"
    @State private var intervalWindowStart: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var intervalWindowEnd: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()

    init(habit: LureliaHabit, onClose: @escaping () -> Void) {
        self._habit = Bindable(wrappedValue: habit)
        self.onClose = onClose
    }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if notificationEnabled && notifKind == .weekly { return weeklyDays.count == daysPerWeek }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        formSection(label: "TITLE") {
                            textField(placeholder: "Habit title", text: $title)
                        }

                        formSection(label: "DESCRIPTION") {
                            textField(placeholder: "Optional description", text: $details)
                        }

                        formSection(label: "SCHEDULE") {
                            HabitScheduleForm(
                                daysPerWeek: $daysPerWeek,
                                timesPerDay: $timesPerDay,
                                hideTimesPerDay: notificationEnabled && (notifKind == .everyXHours || notifKind == .everyXMinutes),
                                onTimesPerDayChange: { v in syncReminderTimes(to: v) }
                            )
                        }

                        formSection(label: "NOTIFICATION") {
                            HabitNotificationForm(
                                notificationEnabled: $notificationEnabled,
                                notifKind: $notifKind,
                                startDate: $startDate,
                                reminderTimes: $reminderTimes,
                                weeklyDays: $weeklyDays,
                                intervalValue: $intervalValue,
                                intervalValueText: $intervalValueText,
                                intervalWindowStart: $intervalWindowStart,
                                intervalWindowEnd: $intervalWindowEnd,
                                timesPerDay: timesPerDay,
                                daysPerWeek: daysPerWeek
                            )
                        }

                        formSection(label: "ARCHIVE") {
                            Toggle(isOn: $habit.isArchived) {
                                Text("Archive this habit")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .tint(LColors.gradientPurple)
                            .padding(16)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onClose() }
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { applyChanges() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(canSave ? LColors.gradientBlue : .white.opacity(0.25))
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { loadFromModel() }
        .onTapGesture { dismissKeyboard() }
    }

    private func syncReminderTimes(to count: Int) {
        while reminderTimes.count < count { reminderTimes.append(reminderTimes.last ?? Date()) }
        if reminderTimes.count > count { reminderTimes = Array(reminderTimes.prefix(count)) }
    }

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.8)
            content()
        }
    }

    @ViewBuilder
    private func textField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func loadFromModel() {
        title = habit.title
        details = habit.details ?? ""
        daysPerWeek = habit.daysPerWeek
        timesPerDay = habit.timesPerDay
        notificationEnabled = habit.reminderEnabled

        let parsedTimes = habit.timesOfDay.compactMap { dateFromHHMM($0) }
        reminderTimes = parsedTimes.isEmpty ? [Date()] : parsedTimes

        let storedDays = habit.reminderDaysOfWeek
        weeklyDays = Set(storedDays.map { max(0, $0 - 1) })

        if !habit.reminderEnabled {
            notifKind = .daily
            return
        }

        if !storedDays.isEmpty {
            notifKind = .weekly
            return
        }

        if let inferred = inferredIntervalSettings(from: habit.timesOfDay) {
            notifKind = inferred.kind
            intervalValue = inferred.value
            intervalValueText = "\(inferred.value)"
            intervalWindowStart = inferred.start
            intervalWindowEnd = inferred.end
        } else {
            notifKind = .daily
        }
    }

    private func dateFromHHMM(_ value: String) -> Date? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private func inferredIntervalSettings(from values: [String]) -> (kind: LureliaHabitNotificationKind, value: Int, start: Date, end: Date)? {
        let dates = values.compactMap { dateFromHHMM($0) }.sorted()
        guard dates.count >= 2 else { return nil }

        let calendar = Calendar.current
        let minutes = dates.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
        let deltas = zip(minutes.dropFirst(), minutes).map { $0 - $1 }
        guard let firstDelta = deltas.first, firstDelta > 0, deltas.allSatisfy({ $0 == firstDelta }) else { return nil }

        let kind: LureliaHabitNotificationKind = firstDelta % 60 == 0 ? .everyXHours : .everyXMinutes
        let value = kind == .everyXHours ? firstDelta / 60 : firstDelta
        guard let start = dates.first, let end = dates.last else { return nil }
        return (kind, max(1, value), start, end)
    }

    private func applyChanges() {
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleTrimmed.isEmpty else { return }
        let detailsTrimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTimesPerDay = (notificationEnabled && (notifKind == .everyXHours || notifKind == .everyXMinutes))
            ? computedIntervalTimesPerDay() : timesPerDay
        habit.title = titleTrimmed
        habit.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed
        habit.daysPerWeek = daysPerWeek
        habit.timesPerDay = resolvedTimesPerDay
        habit.updatedAt = Date()

        HabitManager.shared.cancel(habit)
        if notificationEnabled {
            applyNotificationSettings(to: habit)
            HabitManager.shared.schedule(habit)
        } else {
            habit.reminderEnabled = false
            habit.timesOfDay = []
            habit.reminderDaysOfWeek = []
        }
        onClose()
    }

    private func applyNotificationSettings(to habit: LureliaHabit) {
        habit.reminderEnabled = true
        switch notifKind {
        case .daily:
            habit.timesOfDay = reminderTimes.map { hhmm(from: $0) }
            habit.reminderDaysOfWeek = []
        case .weekly:
            habit.timesOfDay = reminderTimes.map { hhmm(from: $0) }
            habit.reminderDaysOfWeek = weeklyDays.map { $0 + 1 }.sorted()
        case .everyXHours:
            habit.timesOfDay = intervalFireTimes(intervalMinutes: max(1, intervalValue) * 60)
            habit.reminderDaysOfWeek = []
        case .everyXMinutes:
            habit.timesOfDay = intervalFireTimes(intervalMinutes: max(1, intervalValue))
            habit.reminderDaysOfWeek = []
        }
    }

    private func hhmm(from date: Date) -> String {
        String(format: "%02d:%02d",
               Calendar.current.component(.hour, from: date),
               Calendar.current.component(.minute, from: date))
    }

    private func intervalFireTimes(intervalMinutes: Int) -> [String] {
        let cal = Calendar.current
        let startTotal = cal.component(.hour, from: intervalWindowStart) * 60 + cal.component(.minute, from: intervalWindowStart)
        let endTotal   = cal.component(.hour, from: intervalWindowEnd)   * 60 + cal.component(.minute, from: intervalWindowEnd)
        guard endTotal >= startTotal, intervalMinutes > 0 else { return [] }
        var times: [String] = []
        var cursor = startTotal
        while cursor <= endTotal {
            times.append(String(format: "%02d:%02d", cursor / 60, cursor % 60))
            cursor += intervalMinutes
        }
        return times
    }

    private func computedIntervalTimesPerDay() -> Int {
        let cal = Calendar.current
        let startTotal = cal.component(.hour, from: intervalWindowStart) * 60 + cal.component(.minute, from: intervalWindowStart)
        let endTotal   = cal.component(.hour, from: intervalWindowEnd)   * 60 + cal.component(.minute, from: intervalWindowEnd)
        let intervalMins = notifKind == .everyXHours ? max(1, intervalValue) * 60 : max(1, intervalValue)
        guard endTotal >= startTotal, intervalMins > 0 else { return 1 }
        return max(1, (endTotal - startTotal) / intervalMins + 1)
    }
}

// MARK: - Flexible Wrapping View

private struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    init(
        data: Data,
        spacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        let items = Array(data)
        let lastItem = items.last

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + spacing
                        }

                        let result = width

                        if item == lastItem {
                            width = 0
                        } else {
                            width -= dimension.width + spacing
                        }

                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height

                        if item == lastItem {
                            height = 0
                        }

                        return result
                    }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        totalHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        totalHeight = newHeight
                    }
            }
        )
    }
}

// MARK: - Keyboard

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
