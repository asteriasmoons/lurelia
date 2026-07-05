//
//  HabitCardView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit
import Combine
import WidgetKit

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

    private struct ScheduledTimeBadge: Identifiable, Hashable {
        let label: String
        let fireDate: Date

        var id: String {
            "\(label)-\(fireDate.timeIntervalSince1970)"
        }
    }

    private var scheduledTimeBadges: [ScheduledTimeBadge] {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return todayScheduledFireTimes.map { fireDate in
            ScheduledTimeBadge(
                label: formatter.string(from: fireDate),
                fireDate: fireDate
            )
        }
    }

    private var todayScheduledFireTimes: [Date] {
        guard habit.reminderEnabled else { return [] }

        let times = habit.timesOfDay.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !times.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: statusNow)
        let weekday = calendar.component(.weekday, from: today)
        let allowedWeekdays = Set(habit.reminderDaysOfWeek)

        if !allowedWeekdays.isEmpty && !allowedWeekdays.contains(weekday) {
            return []
        }

        return times.compactMap { timeString -> Date? in
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1])
            else {
                return nil
            }

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
        guard habit.reminderEnabled,
              !habit.isCompletedToday,
              todaysSkip == nil
        else {
            return nil
        }

        let times = habit.timesOfDay.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !times.isEmpty else { return nil }

        let calendar = Calendar.current
        let allowedWeekdays = Set(habit.reminderDaysOfWeek)
        let today = calendar.startOfDay(for: statusNow)
        let startDay = activeTrackingStartDay

        for offset in 1...370 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            let dayStart = calendar.startOfDay(for: day)

            if dayStart < startDay {
                break
            }

            let weekday = calendar.component(.weekday, from: dayStart)

            if !allowedWeekdays.isEmpty && !allowedWeekdays.contains(weekday) {
                continue
            }

            let wasCompleted = (habit.logs ?? []).contains { log in
                calendar.isDate(log.dayStart, inSameDayAs: dayStart) && log.count >= habit.target
            }

            if wasCompleted {
                continue
            }

            let wasSkipped = (habit.skips ?? []).contains { skip in
                calendar.isDate(skip.dayStart, inSameDayAs: dayStart)
            }

            if wasSkipped {
                continue
            }

            return times.compactMap { timeString -> Date? in
                let parts = timeString.split(separator: ":")
                guard parts.count == 2,
                      let hour = Int(parts[0]),
                      let minute = Int(parts[1])
                else {
                    return nil
                }

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
        guard habit.reminderEnabled,
              todaysSkip == nil,
              !habit.isCompletedToday
        else {
            return nil
        }

        if let nextUncompleted = nextUncompletedHabitFireAtToday {
            if nextUncompleted <= statusNow {
                return .dueNow
            }

            if Calendar.current.isDateInToday(nextUncompleted) {
                return .upcoming
            }
        }

        if mostRecentMissedFireAtBeforeToday != nil {
            return .overdue
        }

        return nil
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                // MARK: - Title + Completion Circle

                HStack(alignment: .center, spacing: 12) {
                    LureliaHabitIconPreview(iconName: habit.iconName ?? "flame")
                        .frame(width: 42)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(habit.title)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 8)

                    habitCompletionCircle
                        .offset(y: 1)
                }

                // MARK: - Pill Badges

                HabitPillRow(pills: buildStatusAndTimePills())

                // MARK: - Progress Bar or Dots

                if habit.target == 1 {
                    VStack(spacing: 5) {
                        HStack {
                            Text("\(habit.todaysCount) / \(habit.target) completed")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))

                            Spacer()
                            
                        }

                        HStack(spacing: 4) {
                            let dotCount = 18
                            let filledDots = Int((habit.progress * Double(dotCount)).rounded())

                            ForEach(0..<dotCount, id: \.self) { index in
                                Circle()
                                    .fill(
                                        index < filledDots
                                        ? AnyShapeStyle(LGradients.header)
                                        : AnyShapeStyle(Color.clear)
                                    )
                                    .frame(width: 11, height: 11)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(
                                                index < filledDots
                                                ? AnyShapeStyle(LGradients.header)
                                                : AnyShapeStyle(Color.white.opacity(0.25)),
                                                lineWidth: 1
                                            )
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.spring(duration: 0.4), value: habit.progress)
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<habit.target, id: \.self) { i in
                            Circle()
                                .fill(
                                    i < habit.todaysCount
                                    ? AnyShapeStyle(LGradients.header)
                                    : AnyShapeStyle(Color.clear)
                                )
                                .frame(width: 12, height: 12)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            i < habit.todaysCount
                                            ? AnyShapeStyle(LGradients.header)
                                            : AnyShapeStyle(Color.white.opacity(0.35)),
                                            lineWidth: 1.25
                                        )
                                }
                        }
                    }

                    HStack {
                        Text("\(habit.todaysCount) / \(habit.target) completed")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))

                        Spacer()
                    }
                }

                // MARK: - Actions

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        actionButton("Edit", icon: "pencil") {
                            onEdit()
                        }

                        actionButton("Clear", icon: "arrow.counterclockwise") {
                            clearToday()
                        }

                        actionButton(
                            todaysSkip == nil ? "Skip" : "Skipped",
                            icon: "skipwavy",
                            isAsset: true
                        ) {
                            toggleSkip()
                        }

                        actionButton("Reset", icon: "arrow.clockwise") {
                            showResetConfirm = true
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        actionButton("History", icon: "clock.arrow.circlepath") {
                            onHistory()
                        }
                        
                        destructiveButton("Delete", icon: "trash", isAsset: true) {
                            showDeleteConfirm = true
                        }

                        Spacer()
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .imageScale(.small)
            }
        }
        .alert("Delete Habit?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteHabit()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete this habit and all of its history.")
        }
        .alert("Reset Stats?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                resetStats()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Streaks and stats will restart from today. Past log history is kept.")
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now in
            statusNow = now
        }
    }

    // MARK: - Completion Circle

    private var habitCompletionCircle: some View {
        Button {
            quickLog()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        habit.isCompletedToday
                        ? AnyShapeStyle(LGradients.header)
                        : AnyShapeStyle(Color.clear)
                    )
                    .frame(width: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                habit.isCompletedToday
                                ? AnyShapeStyle(LGradients.header)
                                : AnyShapeStyle(LGradients.header.opacity(0.85)),
                                lineWidth: 2.5
                            )
                    }

                if habit.isCompletedToday {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(todaysSkip != nil || habit.isCompletedToday)
        .opacity((todaysSkip != nil || habit.isCompletedToday) ? 0.55 : 1)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButton(
        _ title: String,
        icon: String,
        isAsset: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
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
    private func destructiveButton(
        _ title: String,
        icon: String,
        isAsset: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
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

    // MARK: - Actions

    private func quickLog() {
        let cap = habit.target

        if let existingSkip = todaysSkip {
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter {
                $0.persistentModelID != existingSkip.persistentModelID
            }
        }

        if let existing = todaysLog {
            if existing.count < cap {
                existing.count = min(cap, existing.count + 1)
                existing.updatedAt = Date()
                habit.updatedAt = Date()
                habit.logs = (habit.logs ?? []).map { log in
                    log.persistentModelID == existing.persistentModelID ? existing : log
                }
            }

            try? modelContext.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
            return
        }

        let newLog = LureliaHabitLog(
            habit: habit,
            dayStart: todayStart,
            count: 1
        )

        modelContext.insert(newLog)
        habit.logs = (habit.logs ?? []) + [newLog]
        habit.updatedAt = Date()

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
    }

    private func clearToday() {
        let cal = Calendar.current

        let todayLogs = (habit.logs ?? []).filter {
            cal.isDate($0.dayStart, inSameDayAs: todayStart)
        }

        for log in todayLogs {
            modelContext.delete(log)
        }

        habit.logs = (habit.logs ?? []).filter {
            !cal.isDate($0.dayStart, inSameDayAs: todayStart)
        }

        habit.updatedAt = Date()

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
    }

    private func toggleSkip() {
        if let existing = todaysSkip {
            modelContext.delete(existing)
            habit.skips = (habit.skips ?? []).filter {
                $0.persistentModelID != existing.persistentModelID
            }
            habit.updatedAt = Date()

            try? modelContext.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
            return
        }

        if let log = todaysLog, log.count > 0 {
            return
        }

        let skip = LureliaHabitSkip(
            habit: habit,
            dayStart: todayStart
        )

        modelContext.insert(skip)
        habit.skips = (habit.skips ?? []) + [skip]
        habit.updatedAt = Date()

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
    }

    private func resetStats() {
        habit.statsResetAt = Date()
        habit.updatedAt = Date()

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
    }

    private func deleteHabit() {
        HabitManager.shared.cancel(habit)

        for log in habit.logs ?? [] {
            modelContext.delete(log)
        }

        for skip in habit.skips ?? [] {
            modelContext.delete(skip)
        }

        modelContext.delete(habit)

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
    }

    // MARK: - Pill Data Builder

    private func buildStatusAndTimePills() -> [HabitPillItem] {
        var pills: [HabitPillItem] = []

        switch habitStatusBadgeKind {
        case .overdue:
            pills.append(.init(label: "OVERDUE", isGradient: false, r: 1.0, g: 0.61, b: 0.90))
        case .dueNow:
            pills.append(.init(label: "DUE NOW", isGradient: false, r: 0.71, g: 0.46, b: 1.0))
        case .upcoming:
            pills.append(.init(label: "UPCOMING", isGradient: false, r: 0.49, g: 0.93, b: 1.0))
        case .none:
            break
        }

        if todaysSkip != nil {
            pills.append(.init(label: "SKIPPED", isGradient: false, r: 1, g: 1, b: 1, alpha: 0.35))
        }

        if habit.isCompletedToday {
            pills.append(.init(label: "DONE", isGradient: false, r: 0.3, g: 0.9, b: 0.5))
        }

        for timeBadge in scheduledTimeBadges {
            pills.append(
                .init(
                    label: timeBadge.label,
                    isGradient: isNextDueTimeBadge(timeBadge),
                    r: 1,
                    g: 1,
                    b: 1,
                    alpha: 0.55
                )
            )
        }

        return pills
    }
}

// MARK: - Habit Pill Row

private struct HabitPillRow: View {
    let pills: [HabitPillItem]

    var body: some View {
        FlexibleView(data: pills, spacing: 4, alignment: .leading) { pill in
            pill.view
        }
    }
}

private struct HabitPillItem: Identifiable, Hashable {
    let id: String
    let label: String
    let isGradient: Bool
    let r: Double
    let g: Double
    let b: Double
    let alpha: Double

    init(
        label: String,
        isGradient: Bool,
        r: Double = 1,
        g: Double = 1,
        b: Double = 1,
        alpha: Double = 1
    ) {
        self.id = label
        self.label = label
        self.isGradient = isGradient
        self.r = r
        self.g = g
        self.b = b
        self.alpha = alpha
    }

    var color: Color {
        Color(red: r, green: g, blue: b).opacity(alpha)
    }

    @ViewBuilder
    var view: some View {
        if isGradient {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .fixedSize(horizontal: true, vertical: false)
                .background(Capsule().fill(LGradients.header))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
        } else {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .fixedSize(horizontal: true, vertical: false)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
        }
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
                        if abs(width - dimension.width - spacing) > geometry.size.width {
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
