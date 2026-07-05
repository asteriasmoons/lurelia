//
//  LureliaHabitsWidget.swift
//  Lurelia
//

import WidgetKit
import SwiftUI
import AppIntents
import SwiftData
import UIKit

// MARK: - Widget Item

struct LureliaWidgetHabitItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let icon: String
    let count: Int
    let target: Int
    let status: LureliaWidgetHabitStatus
    let streak: Int
    let firedCount: Int
}

enum LureliaWidgetHabitStatus: String, Hashable {
    case dueNow = "Due Now"
    case soon = "Soon"
    case partial = "In Progress"
    case done = "Done"
    case skipped = "Skipped"
}

// MARK: - Timeline Entry

struct LureliaHabitsEntry: TimelineEntry {
    let date: Date
    let habits: [LureliaWidgetHabitItem]
    let debugInfo: String
}

// MARK: - Timeline Provider

struct LureliaHabitsProvider: TimelineProvider {
    func placeholder(in context: Context) -> LureliaHabitsEntry {
        LureliaHabitsEntry(
            date: Date(),
            habits: [
                LureliaWidgetHabitItem(
                    id: UUID(),
                    title: "Meditate",
                    icon: "sparklesfill",
                    count: 1,
                    target: 1,
                    status: .done,
                    streak: 12,
                    firedCount: 1
                ),
                LureliaWidgetHabitItem(
                    id: UUID(),
                    title: "Read",
                    icon: "bookfill",
                    count: 0,
                    target: 1,
                    status: .soon,
                    streak: 5,
                    firedCount: 0
                )
            ],
            debugInfo: "placeholder"
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (LureliaHabitsEntry) -> Void
    ) {
        let now = Date()
        let result = fetchWidgetHabits(now: now)
        completion(
            LureliaHabitsEntry(
                date: now,
                habits: result.items,
                debugInfo: result.debugInfo
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<LureliaHabitsEntry>) -> Void
    ) {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now) ?? now
        )

        // Collect all upcoming fire times from all habits today
        var fireDates: [Date] = [now]
        let upcomingTimes = collectUpcomingFireTimes(now: now, calendar: calendar)
        fireDates.append(contentsOf: upcomingTimes)
        fireDates.append(tomorrow)

        // Deduplicate and sort
        let uniqueDates = Array(Set(fireDates)).sorted()

        // Generate an entry for each date so the widget refreshes at each fire time
        let entries: [LureliaHabitsEntry] = uniqueDates.map { date in
            let result = fetchWidgetHabits(now: date)
            return LureliaHabitsEntry(
                date: date,
                habits: result.items,
                debugInfo: result.debugInfo
            )
        }

        completion(
            Timeline(
                entries: entries,
                policy: .after(tomorrow)
            )
        )
    }

    private func collectUpcomingFireTimes(now: Date, calendar: Calendar) -> [Date] {
        guard let container = try? LureliaWidgetShared.makeModelContainer() else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LureliaHabit>()
        guard let habits = try? context.fetch(descriptor) else { return [] }

        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var dates: [Date] = []

        for habit in habits where !habit.isArchived && habit.isActiveOn(now, calendar: calendar) {
            guard let data = habit.timesOfDayStorage.data(using: .utf8),
                  let times = try? JSONDecoder().decode([String].self, from: data) else { continue }

            for timeStr in times {
                let parts = timeStr.split(separator: ":")
                guard parts.count == 2,
                      let hour = Int(parts[0]),
                      let minute = Int(parts[1]) else { continue }

                var fireComponents = todayComponents
                fireComponents.hour = hour
                fireComponents.minute = minute
                fireComponents.second = 0

                if let fireDate = calendar.date(from: fireComponents), fireDate > now {
                    dates.append(fireDate)
                }
            }
        }

        return dates
    }

    private func fetchWidgetHabits(now: Date) -> (items: [LureliaWidgetHabitItem], debugInfo: String) {
        do {
            let container = try LureliaWidgetShared.makeModelContainer()
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<LureliaHabit>(
                sortBy: [SortDescriptor(\.title)]
            )

            let allHabits = try context.fetch(descriptor)
            let calendar = Calendar.current

            // Filter: active (not archived) and scheduled for today
            let todaysHabits = allHabits.filter { habit in
                !habit.isArchived && habit.isActiveOn(now, calendar: calendar)
            }

            let todayStart = calendar.startOfDay(for: now)

            let items: [LureliaWidgetHabitItem] = todaysHabits.compactMap { habit in
                let todaysLog = (habit.logs ?? []).first { log in
                    calendar.isDate(log.dayStart, inSameDayAs: todayStart)
                }
                let todaysSkip = (habit.skips ?? []).first { skip in
                    calendar.isDate(skip.dayStart, inSameDayAs: todayStart)
                }

                let count = todaysLog?.count ?? 0
                let target = habit.target
                let fired = firedCountToday(habit, now: now, calendar: calendar)

                let status: LureliaWidgetHabitStatus
                if todaysSkip != nil && count == 0 {
                    status = .skipped
                } else if count >= target {
                    status = .done
                } else if fired > count {
                    // A fire time passed and she hasn't completed it yet
                    status = .dueNow
                } else if count > 0 {
                    // Caught up with all fired times, waiting for next
                    status = .partial
                } else {
                    // Nothing fired yet, nothing done
                    status = .soon
                }

                return LureliaWidgetHabitItem(
                    id: habit.id,
                    title: habit.title,
                    icon: habit.iconName ?? "repeatfill",
                    count: count,
                    target: target,
                    status: status,
                    streak: habit.dailyStreak,
                    firedCount: 0
                )
            }
            .sorted { a, b in
                // Due now first, then partial, then soon, then done/skipped
                let order: [LureliaWidgetHabitStatus] = [.dueNow, .partial, .soon, .done, .skipped]
                let aIdx = order.firstIndex(of: a.status) ?? 0
                let bIdx = order.firstIndex(of: b.status) ?? 0
                if aIdx != bIdx { return aIdx < bIdx }
                return a.title.localizedCompare(b.title) == .orderedAscending
            }
            .prefix(4)
            .map { $0 }

            let debug = "raw=\(allHabits.count) today=\(todaysHabits.count) shown=\(items.count)"
            return (items, debug)
        } catch {
            return ([], "SwiftData error: \(error.localizedDescription)")
        }
    }

    private func habitHasFiredToday(_ habit: LureliaHabit, now: Date, calendar: Calendar) -> Bool {
        return firedCountToday(habit, now: now, calendar: calendar) > 0
    }

    private func firedCountToday(_ habit: LureliaHabit, now: Date, calendar: Calendar) -> Int {
        guard let data = habit.timesOfDayStorage.data(using: .utf8),
              let times = try? JSONDecoder().decode([String].self, from: data),
              !times.isEmpty else {
            return 0
        }

        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var count = 0

        for timeStr in times {
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }

            var fireComponents = todayComponents
            fireComponents.hour = hour
            fireComponents.minute = minute
            fireComponents.second = 0

            if let fireDate = calendar.date(from: fireComponents), fireDate <= now {
                count += 1
            }
        }

        return count
    }
}

// MARK: - Widget View

struct LureliaHabitsWidgetView: View {
    let entry: LureliaHabitsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if entry.habits.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(entry.habits.prefix(4)) { habit in
                        habitRow(habit)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LureliaBackgroundAlt()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            widgetIcon("clockfill", size: 17)

            Text("Habits")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Text("Today")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("No habits for today")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(entry.debugInfo)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    private func habitRow(_ habit: LureliaWidgetHabitItem) -> some View {
        HStack(spacing: 9) {
            // Complete button
            if habit.status == .done {
                completedCircle
            } else if habit.status == .skipped {
                skippedCircle
            } else {
                Button(
                    intent: CompleteHabitWidgetIntent(
                        habitID: habit.id.uuidString
                    )
                ) {
                    progressCircle(habit: habit)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            widgetIcon(habit.icon, size: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(statusLabel(for: habit))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor(for: habit.status))
                }
            }

            Spacer(minLength: 0)

            // Skip button (only for dueNow/soon/partial)
            if habit.status == .dueNow || habit.status == .soon || habit.status == .partial {
                Button(
                    intent: SkipHabitWidgetIntent(
                        habitID: habit.id.uuidString
                    )
                ) {
                    skipIcon(size: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(lureliaHex: "#03dbfc").opacity(0.55),
                            Color(lureliaHex: "#7d19f7").opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Circle States

    private func progressCircle(habit: LureliaWidgetHabitItem) -> some View {
        let size: CGFloat = 28
        let dotCount = 16
        let dotRadius: CGFloat = 1.5
        let ringRadius: CGFloat = (size / 2) - dotRadius
        let filledDots = habit.target > 1
            ? Int(round(Double(dotCount) * Double(habit.count) / Double(habit.target)))
            : 0

        return ZStack {
            // Background dots
            ForEach(0..<dotCount, id: \.self) { i in
                let angle = (2 * .pi / Double(dotCount)) * Double(i) - .pi / 2
                let x = cos(angle) * Double(ringRadius)
                let y = sin(angle) * Double(ringRadius)

                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: dotRadius * 2, height: dotRadius * 2)
                    .offset(x: x, y: y)
            }

            // Progress dots (gradient colored)
            if habit.count > 0 && habit.target > 1 {
                ForEach(0..<filledDots, id: \.self) { i in
                    let angle = (2 * .pi / Double(dotCount)) * Double(i) - .pi / 2
                    let x = cos(angle) * Double(ringRadius)
                    let y = sin(angle) * Double(ringRadius)
                    let t = Double(i) / Double(max(dotCount - 1, 1))
                    let color = gradientColor(at: t)

                    Circle()
                        .fill(color)
                        .frame(width: dotRadius * 2, height: dotRadius * 2)
                        .offset(x: x, y: y)
                }
            } else {
                // All dots gradient (no progress yet)
                ForEach(0..<dotCount, id: \.self) { i in
                    let angle = (2 * .pi / Double(dotCount)) * Double(i) - .pi / 2
                    let x = cos(angle) * Double(ringRadius)
                    let y = sin(angle) * Double(ringRadius)
                    let t = Double(i) / Double(max(dotCount - 1, 1))
                    let color = gradientColor(at: t)

                    Circle()
                        .fill(color)
                        .frame(width: dotRadius * 2, height: dotRadius * 2)
                        .offset(x: x, y: y)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func gradientColor(at t: Double) -> Color {
        // #03dbfc (cyan) -> #7d19f7 (purple)
        let r = 0.012 + (0.490 - 0.012) * t
        let g = 0.859 + (0.098 - 0.859) * t
        let b = 0.988 + (0.969 - 0.988) * t
        return Color(red: r, green: g, blue: b)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private var completedCircle: some View {
        ZStack {
            Circle()
                .fill(widgetGradient)
                .frame(width: 28, height: 28)

            if let uiImage = LureliaWidgetShared.widgetIcon(for: "checkwavy") {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
            }
        }
    }

    private var skippedCircle: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 28, height: 28)

            if let uiImage = LureliaWidgetShared.widgetIcon(for: "minuswavy") {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Status

    private func statusLabel(for habit: LureliaWidgetHabitItem) -> String {
        switch habit.status {
        case .done:
            return habit.target > 1 ? "Done · \(habit.count)/\(habit.target)" : "Done"
        case .skipped:
            return "Skipped"
        case .partial:
            return "In Progress · \(habit.count)/\(habit.target)"
        case .dueNow:
            return habit.count > 0
                ? "Due Now · \(habit.count)/\(habit.target)"
                : (habit.target > 1 ? "Due Now · 0/\(habit.target)" : "Due Now")
        case .soon:
            return habit.target > 1 ? "Soon · 0/\(habit.target)" : "Soon"
        }
    }

    private func statusColor(for status: LureliaWidgetHabitStatus) -> Color {
        switch status {
        case .dueNow:
            return Color(lureliaHex: "#c7a3ff")
        case .soon:
            return Color(lureliaHex: "#7eedff")
        case .partial:
            return Color(lureliaHex: "#7eedff")
        case .done:
            return Color(lureliaHex: "#e2ed8a")
        case .skipped:
            return .white.opacity(0.45)
        }
    }

    // MARK: - Shared Styling

    private var widgetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(lureliaHex: "#03dbfc"),
                Color(lureliaHex: "#7d19f7")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func skipIcon(size: CGFloat) -> some View {
        if let uiImage = LureliaWidgetShared.widgetIcon(for: "skipwavy") {
            Image(uiImage: uiImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.white.opacity(0.35))
        } else {
            Image(systemName: "forward.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    @ViewBuilder
    private func widgetIcon(_ name: String, size: CGFloat) -> some View {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconName = trimmedName.isEmpty ? "repeatfill" : trimmedName

        if let uiImage = LureliaWidgetShared.widgetIcon(for: iconName) {
            widgetGradient
                .mask(
                    Image(uiImage: uiImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                )
                .frame(width: size, height: size)
        } else if let fallbackImage = LureliaWidgetShared.widgetIcon(for: "repeatfill") {
            widgetGradient
                .mask(
                    Image(uiImage: fallbackImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                )
                .frame(width: size, height: size)
        } else {
            widgetGradient
                .mask(
                    Image(systemName: "repeat")
                        .resizable()
                        .scaledToFit()
                )
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Widget Configuration

struct LureliaHabitsWidget: Widget {
    let kind = "LureliaHabitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: LureliaHabitsProvider()
        ) { entry in
            LureliaHabitsWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Habits")
        .description("Track and complete your daily habits.")
        .supportedFamilies([
            .systemLarge
        ])
    }
}
