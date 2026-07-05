//
//  HabitsView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit
import Combine
import WidgetKit

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
        NavigationStack {
        ZStack(alignment: .bottomTrailing) {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Header

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Habits")
                                .font(.system(size: 30, weight: .black, design: .rounded))
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
                                    NavigationLink(value: habit.id) {
                                    LureliaHabitCard(
                                        habit: habit,
                                        onEdit: { editingHabit = habit },
                                        onHistory: { historyHabit = habit }
                                    )
                                    }
                                    .buttonStyle(.plain)
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
                                        NavigationLink(value: habit.id) {
                                        LureliaHabitCard(
                                            habit: habit,
                                            onEdit: { editingHabit = habit },
                                            onHistory: { historyHabit = habit }
                                        )
                                        .opacity(0.6)
                                        }
                                        .buttonStyle(.plain)
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
        .fullScreenCover(isPresented: $showNewHabit) {
            LureliaHabitFormSheet(habit: nil) {
                showNewHabit = false
            }
        }
        .fullScreenCover(item: $editingHabit) { habit in
            LureliaHabitFormSheet(habit: habit) { editingHabit = nil }
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
        .navigationDestination(for: UUID.self) { habitID in
            if let habit = habits.first(where: { $0.id == habitID }) {
                HabitBlueprintDetailView(habit: habit)
            }
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
        GlassCard {
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

// MARK: - Schedule Form

struct LureliaHabitIconPreview: View {
    let iconName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.22),
                            LColors.gradientPurple.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)

            Circle()
                .strokeBorder(LGradients.header, lineWidth: 2.5)
                .frame(width: 42, height: 42)

            Group {
                if UIImage(named: iconName) != nil {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: iconName)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 22, height: 22)
            .foregroundStyle(.white)
        }
    }
}

struct LureliaHabitIconPickerButton: View {
    @Binding var iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: 12) {
                    LureliaHabitIconPreview(iconName: iconName)

                    Text("Choose Icon")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct HabitScheduleForm: View {
    @Binding var activeWeekdays: Set<Int>
    @Binding var daysPerWeek: Int
    @Binding var timesPerDay: Int
    var hideTimesPerDay: Bool
    var onTimesPerDayChange: (Int) -> Void

    private let weekdays: [(value: Int, label: String)] = [
        (1, "Sun"),
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat")
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Active weekdays")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("\(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.gradientBlue)
                    }

                    HStack(spacing: 6) {
                        ForEach(weekdays, id: \.value) { weekday in
                            let selected = activeWeekdays.contains(weekday.value)

                            Button {
                                toggleWeekday(weekday.value)
                            } label: {
                                Text(weekday.label)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(selected ? .white : .white.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        selected
                                        ? AnyShapeStyle(LGradients.header)
                                        : AnyShapeStyle(Color.white.opacity(0.08))
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(selected ? Color.clear : Color.white.opacity(0.14), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

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
        }
        .onAppear {
            syncDaysPerWeek()
        }
        .onChange(of: activeWeekdays) { _, _ in
            syncDaysPerWeek()
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if activeWeekdays.contains(weekday) {
            guard activeWeekdays.count > 1 else { return }
            activeWeekdays.remove(weekday)
        } else {
            activeWeekdays.insert(weekday)
        }

        syncDaysPerWeek()
    }

    private func syncDaysPerWeek() {
        if activeWeekdays.isEmpty {
            activeWeekdays = [1, 2, 3, 4, 5, 6, 7]
        }
        daysPerWeek = activeWeekdays.count
    }
}

// MARK: - Habit Notification Kind

enum LureliaHabitNotificationKind: String, CaseIterable {
    case daily         = "Daily"
    case everyXHours   = "Every XH"
    case everyXMinutes = "Every XM"
}

// MARK: - Shared Notification Form

struct HabitNotificationForm: View {
    @Binding var notificationEnabled: Bool
    @Binding var notifKind: LureliaHabitNotificationKind
    @Binding var startDate: Date
    @Binding var reminderTimes: [Date]
    @Binding var intervalValue: Int
    @Binding var intervalValueText: String
    @Binding var intervalWindowStart: Date
    @Binding var intervalWindowEnd: Date
    var timesPerDay: Int
    var iconName: String = "flame"
    var daysPerWeek: Int



    var body: some View {
        GlassCard {
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
                case .everyXHours:   intervalControls(unit: "hours")
                case .everyXMinutes: intervalControls(unit: "minutes")
                }
            }
            }
        }

    }

    // MARK: - Daily

    @ViewBuilder
    private var dailyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(reminderTimes.indices), id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    if reminderTimes.count > 1 {
                        Text("TIME \(idx + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(0.6)
                    }
                    LureliaGradientTimeDrumPicker(
                        hour: hourBinding(for: idx),
                        minute: minuteBinding(for: idx)
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
                    hour: windowStartHourBinding,
                    minute: windowStartMinuteBinding
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("UNTIL")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.6)
                LureliaGradientTimeDrumPicker(
                    hour: windowEndHourBinding,
                    minute: windowEndMinuteBinding
                )
            }
        }
    }

    private func hourBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: reminderTimes.indices.contains(index) ? reminderTimes[index] : Date()) },
            set: { newHour in
                guard reminderTimes.indices.contains(index) else { return }
                var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTimes[index])
                c.hour = newHour; c.second = 0
                if let d = Calendar.current.date(from: c) { reminderTimes[index] = d }
            }
        )
    }

    private func minuteBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: reminderTimes.indices.contains(index) ? reminderTimes[index] : Date()) },
            set: { newMinute in
                guard reminderTimes.indices.contains(index) else { return }
                var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTimes[index])
                c.minute = newMinute; c.second = 0
                if let d = Calendar.current.date(from: c) { reminderTimes[index] = d }
            }
        )
    }

    private var windowStartHourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: intervalWindowStart) },
            set: { newHour in
                var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: intervalWindowStart)
                c.hour = newHour; c.second = 0
                if let d = Calendar.current.date(from: c) { intervalWindowStart = d }
            }
        )
    }

    private var windowStartMinuteBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: intervalWindowStart) },
            set: { newMinute in
                var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: intervalWindowStart)
                c.minute = newMinute; c.second = 0
                if let d = Calendar.current.date(from: c) { intervalWindowStart = d }
            }
        )
    }

    private var windowEndHourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: intervalWindowEnd) },
            set: { newHour in
                var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: intervalWindowEnd)
                c.hour = newHour; c.second = 0
                if let d = Calendar.current.date(from: c) { intervalWindowEnd = d }
            }
        )
    }

    private var windowEndMinuteBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: intervalWindowEnd) },
            set: { newMinute in
                var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: intervalWindowEnd)
                c.minute = newMinute; c.second = 0
                if let d = Calendar.current.date(from: c) { intervalWindowEnd = d }
            }
        )
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

// MARK: - Habit Pill Row (wrapping)

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

    init(label: String, isGradient: Bool, r: Double = 1, g: Double = 1, b: Double = 1, alpha: Double = 1) {
        self.id = label
        self.label = label
        self.isGradient = isGradient
        self.r = r; self.g = g; self.b = b; self.alpha = alpha
    }

    var color: Color { Color(red: r, green: g, blue: b).opacity(alpha) }

    @ViewBuilder var view: some View {
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
