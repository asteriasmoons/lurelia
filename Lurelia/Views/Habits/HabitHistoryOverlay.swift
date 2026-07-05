//
//  HabitHistoryOverlay.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaHabitHistoryOverlay: View {
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

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 14)
                        .padding(.bottom, 18)

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

                    HStack(spacing: 12) {
                        let dailyStreak = strictDailyStreak(for: habit)
                        let weeklyStreak = strictWeeklyStreak(for: habit)

                        streakBlock(label: "Daily Streak", value: "\(dailyStreak) day\(dailyStreak == 1 ? "" : "s")")
                        streakBlock(label: "Weekly Streak", value: "\(weeklyStreak) week\(weeklyStreak == 1 ? "" : "s")")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

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

                try? modelContext.save()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete this history record.")
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

            if !habit.isActiveOn(dayStart, calendar: calendar) {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                    break
                }
                day = previousDay
                continue
            }

            let completed = (habit.logs ?? []).contains { log in
                calendar.isDate(log.dayStart, inSameDayAs: dayStart) && log.count >= habit.target
            }

            let skipped = (habit.skips ?? []).contains { skip in
                calendar.isDate(skip.dayStart, inSameDayAs: dayStart)
            }

            if completed {
                streak += 1
            } else if skipped {
                // skipped active days protect the streak without incrementing
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

            let activeDaysInWeek = activeHabitDays(in: weekInterval, for: habit, calendar: calendar)
            if activeDaysInWeek.isEmpty { break }

            let completedDaysInWeek = Set((habit.logs ?? []).compactMap { log -> Date? in
                let dayStart = calendar.startOfDay(for: log.dayStart)

                guard weekInterval.contains(dayStart),
                      habit.isActiveOn(dayStart, calendar: calendar),
                      log.count >= habit.target
                else {
                    return nil
                }

                return dayStart
            })

            let skippedDaysInWeek = Set((habit.skips ?? []).compactMap { skip -> Date? in
                let dayStart = calendar.startOfDay(for: skip.dayStart)

                guard weekInterval.contains(dayStart),
                      habit.isActiveOn(dayStart, calendar: calendar)
                else {
                    return nil
                }

                return dayStart
            })

            if completedDaysInWeek.union(skippedDaysInWeek).count >= activeDaysInWeek.count {
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

    private func activeHabitDays(
        in interval: DateInterval,
        for habit: LureliaHabit,
        calendar: Calendar
    ) -> Set<Date> {
        var days = Set<Date>()
        var cursor = calendar.startOfDay(for: interval.start)

        while cursor < interval.end {
            if habit.isActiveOn(cursor, calendar: calendar) {
                days.insert(cursor)
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }

            cursor = next
        }

        return days
    }

    @ViewBuilder
    private func streakBlock(label: String, value: String) -> some View {
        GlassCard {
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
        }
    }

    @ViewBuilder
    private func historyRow(entry: HistoryEntry) -> some View {
        GlassCard {
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
                let statusLabel = entry.isSkipped
                    ? "SKIPPED"
                    : (count >= habit.target ? "DONE" : (count > 0 ? "PARTIAL" : "NONE"))

                let statusColor: Color = entry.isSkipped
                    ? .white.opacity(0.35)
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
        }
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
