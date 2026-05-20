//
//  RemindersView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UserNotifications

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LureliaReminder.scheduledDate)
    private var reminders: [LureliaReminder]

    @State private var showAddReminder = false
    @State private var editingReminder: LureliaReminder?
    @State private var showCompletionBanner = false

    private func triggerBanner() {
        showCompletionBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCompletionBanner = false
        }
    }

    private var filteredReminders: [LureliaReminder] {
        reminders
            .filter { $0.kind == .standalone }
            .sorted {
                let lDone = $0.isCompleted && $0.repeatUnit == .none
                let rDone = $1.isCompleted && $1.repeatUnit == .none
                if lDone != rDone { return !lDone }
                if $0.isEnabled != $1.isEnabled { return $0.isEnabled }
                let lDate = $0.nextFireAt ?? $0.scheduledDate
                let rDate = $1.nextFireAt ?? $1.scheduledDate
                return lDate < rDate
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        HStack {
                            Text("Reminders")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            Button { showAddReminder = true } label: {
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

                        overviewCard
                            .padding(.horizontal, 24)

                        if filteredReminders.isEmpty {
                            emptyState
                                .padding(.top, 40)
                                .padding(.horizontal, 24)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredReminders) { reminder in
                                    LureliaReminderCard(
                                        reminder: reminder,
                                        onEdit: { editingReminder = reminder },
                                        onDelete: { delete(reminder) },
                                        onComplete: { triggerBanner() }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer().frame(height: 120)
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddReminder) {
                AddReminderView()
            }
            .sheet(item: $editingReminder) { reminder in
                AddReminderView(editingReminder: reminder)
            }
        }
        .completionBanner(isShowing: showCompletionBanner, message: "Reminder completed!")
    }

    // MARK: - Overview

    private var standaloneReminders: [LureliaReminder] {
        reminders.filter { $0.kind == .standalone }
    }

    private func resolvedTimesOfDay(_ reminder: LureliaReminder) -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        if !stored.isEmpty { return stored }
        let cal = Calendar.current
        let ph = reminder.primaryHour != -1 ? reminder.primaryHour : cal.component(.hour, from: reminder.scheduledDate)
        let pm = reminder.primaryMinute != -1 ? reminder.primaryMinute : cal.component(.minute, from: reminder.scheduledDate)
        var times = [String(format: "%02d:%02d", ph, pm)]
        for ft in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", ft.hour, ft.minute))
        }
        return times
    }

    private func allFireDates(_ reminder: LureliaReminder, on date: Date) -> [Date] {
        let cal = Calendar.current
        let dayComponents = cal.dateComponents([.year, .month, .day], from: date)
        let times = resolvedTimesOfDay(reminder)

        return times.compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            var c = dayComponents; c.hour = h; c.minute = m; c.second = 0
            return cal.date(from: c)
        }.sorted()
    }

    private var upcomingTodayCount: Int {
        let cal = Calendar.current
        let now = Date()
        let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now

        return standaloneReminders.reduce(0) { sum, reminder in
            guard reminder.isEnabled && !reminder.isCompleted else { return sum }
            let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
            guard nextFire > now && nextFire < endOfDay else { return sum }

            let nextHH = cal.component(.hour, from: nextFire)
            let nextMM = cal.component(.minute, from: nextFire)

            var seen = Set<String>()
            let remaining = allFireDates(reminder, on: now)
                .map { d in (cal.component(.hour, from: d), cal.component(.minute, from: d)) }
                .filter { (h, m) in
                    guard seen.insert("\(h):\(m)").inserted else { return false }
                    return h > nextHH || (h == nextHH && m >= nextMM)
                }.count

            return sum + max(1, remaining)
        }
    }

    private var totalTodayCount: Int {
        let cal = Calendar.current
        let now = Date()

        return standaloneReminders.reduce(0) { sum, reminder in
            guard reminder.isEnabled else { return sum }
            let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
            let completedToday = reminder.completionTimestamps.contains { cal.isDateInToday($0) }
            let skippedToday = reminder.skippedTimestamps.contains { cal.isDateInToday($0) }
            guard cal.isDate(nextFire, inSameDayAs: now) || completedToday || skippedToday else { return sum }

            var seen = Set<String>()
            let count = allFireDates(reminder, on: now)
                .map { d in (cal.component(.hour, from: d), cal.component(.minute, from: d)) }
                .filter { (h, m) in seen.insert("\(h):\(m)").inserted }
                .count

            return sum + max(1, count)
        }
    }

    private var doneTodayCount: Int {
        let cal = Calendar.current
        let today = Date()
        return standaloneReminders.reduce(0) { sum, reminder in
            sum + reminder.completionTimestamps.filter { cal.isDate($0, inSameDayAs: today) }.count
        }
    }

    private var skippedTodayCount: Int {
        let cal = Calendar.current
        let today = Date()
        return standaloneReminders.reduce(0) { sum, reminder in
            sum + reminder.skippedTimestamps.filter { cal.isDate($0, inSameDayAs: today) }.count
        }
    }

    private var nextUpReminder: LureliaReminder? {
        let now = Date()
        return standaloneReminders
            .filter { $0.isEnabled && !$0.isCompleted && ($0.nextFireAt ?? $0.scheduledDate) > now }
            .sorted { ($0.nextFireAt ?? $0.scheduledDate) < ($1.nextFireAt ?? $1.scheduledDate) }
            .first
    }

    private var encouragingText: String {
        if doneTodayCount > 0 && upcomingTodayCount == 0 { return "You've completed all your reminders for today." }
        if doneTodayCount > 0 { return "You've completed \(doneTodayCount) reminder\(doneTodayCount == 1 ? "" : "s") today. Keep going." }
        if totalTodayCount > 0 { return "You have \(totalTodayCount) reminder\(totalTodayCount == 1 ? "" : "s") scheduled for today." }
        return "You're all caught up for now."
    }

    private var overviewCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            overviewCardContent(now: context.date)
        }
    }

    private func overviewCardContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image("bellfill")
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 20, height: 20).foregroundStyle(LGradients.header)

                Text("Overview")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Spacer()

                if let next = nextUpReminder {
                    Text("Next: \((next.nextFireAt ?? next.scheduledDate).formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.gradientBlue)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(LColors.gradientBlue.opacity(0.12), in: Capsule())
                }
            }

            Text(encouragingText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                LureliaReminderStatCard(value: upcomingTodayCount, label: "Upcoming Today")
                LureliaReminderStatCard(value: doneTodayCount, label: "Done Today")
                LureliaReminderStatCard(value: totalTodayCount, label: "Total Today")
                LureliaReminderStatCard(value: skippedTodayCount, label: "Skipped Today")
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.12),
                                    LColors.gradientPurple.opacity(0.14),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("bellfill")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 48, height: 48).foregroundStyle(LGradients.header)

            Text("No Reminders Yet")
                .font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(LColors.textPrimary)

            Text("Create standalone reminders to track anything you need to remember.")
                .font(.system(size: 14, design: .rounded)).foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 18)

            Button { showAddReminder = true } label: {
                Text("Create Reminder")
                    .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LGradients.header))
            }
            .buttonStyle(.plain).padding(.top, 4)
        }
        .padding(22)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(LColors.glassBorder, lineWidth: 1))
    }

    private func delete(_ reminder: LureliaReminder) {
        modelContext.delete(reminder)
        try? modelContext.save()
    }
}

// MARK: - Reminder Card

struct LureliaReminderCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var reminder: LureliaReminder

    let onEdit: () -> Void
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    private var accent: Color { reminder.isEnabled ? LColors.gradientBlue : LColors.textSecondary }

    private var dateText: String { reminder.scheduledDate.formatted(date: .abbreviated, time: .omitted) }

    // All configured fire times displayed on the card — read from timesOfDay (source of truth)
    private var allFireDates: [Date] {
        let cal = Calendar.current
        let anchor = reminder.nextFireAt ?? reminder.scheduledDate
        let dayComponents = cal.dateComponents([.year, .month, .day], from: anchor)
        let times = resolvedTimesOfDay()

        return times.compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            var c = dayComponents; c.hour = h; c.minute = m; c.second = 0
            return cal.date(from: c)
        }.sorted()
    }

    private func resolvedTimesOfDay() -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        if !stored.isEmpty { return stored }
        let cal = Calendar.current
        let ph = reminder.primaryHour != -1 ? reminder.primaryHour : cal.component(.hour, from: reminder.scheduledDate)
        let pm = reminder.primaryMinute != -1 ? reminder.primaryMinute : cal.component(.minute, from: reminder.scheduledDate)
        var times = [String(format: "%02d:%02d", ph, pm)]
        for ft in reminder.additionalFireTimes { times.append(String(format: "%02d:%02d", ft.hour, ft.minute)) }
        return times
    }

    private var isDoneToday: Bool {
        // Recurring reminders are never "done" — they always show status badges
        // This matches the main RemindersView behavior exactly.
        guard reminder.repeatUnit == .none else { return false }
        let cal = Calendar.current
        if let completedAt = reminder.completedAt, cal.isDateInToday(completedAt) { return true }
        return reminder.completionTimestamps.contains { cal.isDateInToday($0) }
    }

    private func isOverdue(now: Date) -> Bool {
        guard !isDoneToday && reminder.isEnabled else { return false }
        if reminder.repeatUnit == .none && reminder.isCompleted { return false }
        let startOfToday = Calendar.current.startOfDay(for: now)
        return (reminder.nextFireAt ?? reminder.scheduledDate) < startOfToday
    }

    private func isDueNow(now: Date) -> Bool {
        guard !isDoneToday && reminder.isEnabled else { return false }
        if reminder.repeatUnit == .none && reminder.isCompleted { return false }
        let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
        // Recurring reminders missed on a prior day should not stay stuck on Due Now
        if reminder.repeatUnit != .none {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if nextFire < startOfToday { return false }
        }
        return nextFire <= now
    }

    private func isUpcoming(now: Date) -> Bool {
        guard !isDoneToday && reminder.isEnabled else { return false }
        if reminder.repeatUnit == .none && reminder.isCompleted { return false }
        let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
        guard nextFire > now else { return false }
        return nextFire <= now.addingTimeInterval(24 * 60 * 60)
    }

    private var compactRepeatText: String {
        guard reminder.repeatUnit != .none else { return "No repeat" }
        let interval = max(1, reminder.repeatInterval)
        if interval == 1 {
            switch reminder.repeatUnit {
            case .minutes: return "Every min"
            case .hours:   return "Hourly"
            case .days:    return "Daily"
            case .weeks:
                if reminder.repeatWeekdays.isEmpty { return "Weekly" }
                return "Weekly: \(reminder.repeatWeekdays.sorted().compactMap { weekdayName($0) }.joined(separator: ", "))"
            case .months:  return "Monthly"
            case .years:   return "Yearly"
            case .none:    return "No repeat"
            }
        }
        switch reminder.repeatUnit {
        case .minutes: return "Every \(interval) min"
        case .hours:   return "Every \(interval) hr"
        case .days:    return "Every \(interval) days"
        case .weeks:   return "Every \(interval) wks"
        case .months:  return "Every \(interval) mos"
        case .years:   return "Every \(interval) yrs"
        case .none:    return "No repeat"
        }
    }

    private var reminderIcon: String {
        reminder.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bellfill" : reminder.icon
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            cardContent(
                overdue:  isOverdue(now: now),
                dueNow:   isDueNow(now: now),
                upcoming: isUpcoming(now: now)
            )
        }
    }

    @ViewBuilder
    private func cardContent(overdue: Bool, dueNow: Bool, upcoming: Bool) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.10)).frame(width: 54, height: 54)
                    Circle().fill(Color.white.opacity(0.08)).frame(width: 38, height: 38).blur(radius: 10)
                    LureliaIconView(iconId: reminderIcon, size: 26).foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(reminder.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(reminder.isEnabled ? LColors.textPrimary : LColors.textSecondary)
                        .lineLimit(2)

                    if !reminder.category.isEmpty {
                        Text(reminder.category)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(accent).padding(.horizontal, 7).padding(.vertical, 4)
                            .background(accent.opacity(0.12), in: Capsule())
                    }

                    if let notes = reminder.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.75)).lineLimit(2)
                    }
                }

                completionCircle
            }

            Divider().overlay(LColors.glassBorder)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    reminderMetaPill(icon: "dotscal", title: dateText)
                    reminderRepeatLine(icon: "repeat", title: compactRepeatText)
                }
                fireTimesGrid
                if overdue || dueNow || upcoming {
                    HStack {
                        if overdue {
                            reminderBubbleText("OVERDUE",  color: Color(lureliaHex: "#ff9be6"))
                        } else if dueNow {
                            reminderBubbleText("DUE NOW",  color: Color(lureliaHex: "#b476ff"))
                        } else if upcoming {
                            reminderBubbleText("UPCOMING", color: Color(lureliaHex: "#7eedff"))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            HStack(spacing: 10) {
                Button { onEdit() } label: { reminderActionButton(title: "Edit", icon: "slider") }.buttonStyle(.plain)

                Button { skipReminderOccurrence() } label: { reminderActionButton(title: "Skip", icon: "skipwavy") }
                    .buttonStyle(.plain)
                    .disabled(!reminder.isEnabled || (reminder.repeatUnit == .none && reminder.isCompleted))
                    .opacity((!reminder.isEnabled || (reminder.repeatUnit == .none && reminder.isCompleted)) ? 0.4 : 1)

                Button(role: .destructive) { onDelete() } label: { reminderActionButton(title: "Delete", icon: "trash") }
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent.opacity(reminder.isEnabled ? 0.13 : 0.04), LColors.gradientPurple.opacity(reminder.isEnabled ? 0.08 : 0.03), Color.white.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(reminder.isEnabled ? 0.95 : 0.35),
                                    LColors.gradientPurple.opacity(reminder.isEnabled ? 0.95 : 0.35),
                                    Color.white.opacity(reminder.isEnabled ? 0.55 : 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                }
        }
        .opacity(reminder.isEnabled ? 1 : 0.65)
    }

    // MARK: Sub-views

    private var completionCircle: some View {
        Button { completeReminderOccurrence() } label: {
            ZStack {
                Circle()
                    .fill(reminder.isCompleted && reminder.repeatUnit == .none ? accent.opacity(0.18) : Color.clear)
                    .frame(width: 30, height: 30)
                    .overlay { Circle().strokeBorder(accent.opacity(0.75), lineWidth: 2) }
                if reminder.isCompleted && reminder.repeatUnit == .none {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(accent)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var fireTimesGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            alignment: .center, spacing: 8
        ) {
            ForEach(Array(allFireDates.enumerated()), id: \.offset) { _, d in
                reminderBubbleText(d.formatted(date: .omitted, time: .shortened), color: accent)
            }
        }
    }

    private func reminderBubbleText(_ title: String, color: Color) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(LColors.glassBorder, lineWidth: 1))
    }

    private func reminderMetaPill(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(icon).renderingMode(.template).resizable().scaledToFit().frame(width: 12, height: 12)
            Text(title).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
        }
        .foregroundStyle(LColors.textSecondary).frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(LColors.glassBorder, lineWidth: 1))
    }

    private func reminderRepeatLine(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(icon).renderingMode(.template).resizable().scaledToFit().frame(width: 14, height: 14)
            Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer()
        }
        .foregroundStyle(LColors.textSecondary).padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(LColors.glassBorder, lineWidth: 1))
    }

    private func reminderActionButton(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(icon).renderingMode(.template).resizable().scaledToFit().frame(width: 13, height: 13)
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(LColors.textPrimary.opacity(0.78)).frame(maxWidth: .infinity).frame(height: 40)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(LColors.glassBorder, lineWidth: 1))
    }

    private func weekdayName(_ weekday: Int) -> String? {
        guard weekday >= 1 && weekday <= 7 else { return nil }
        return Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    // MARK: Actions

    private func completeReminderOccurrence() {
        Task {
            await LureliaNotificationManager.shared.cancelReminder(reminder)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                reminder.updatedAt = Date()
                let completedAt = reminder.nextFireAt ?? reminder.scheduledDate
                var timestamps = reminder.completionTimestamps
                timestamps.append(completedAt)
                reminder.completionTimestamps = timestamps

                if reminder.repeatUnit != .none, let next = nextScheduledDate(after: completedAt) {
                    reminder.nextFireAt = next
                    if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                        reminder.scheduledDate = primaryFireDate(onSameDayAs: next)
                    }
                } else {
                    reminder.isCompleted = true
                    reminder.completedAt = Date()
                }
            }
            try? modelContext.save()
            if reminder.repeatUnit != .none && reminder.isEnabled {
                await LureliaNotificationManager.shared.scheduleReminder(reminder)
            }
            await MainActor.run { onComplete?() }
        }
    }

    private func skipReminderOccurrence() {
        Task {
            await LureliaNotificationManager.shared.cancelReminder(reminder)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                reminder.updatedAt = Date()
                let skippedAt = reminder.nextFireAt ?? reminder.scheduledDate
                var timestamps = reminder.skippedTimestamps
                timestamps.append(skippedAt)
                reminder.skippedTimestamps = timestamps

                if let next = nextScheduledDate(after: skippedAt) {
                    reminder.nextFireAt = next
                    if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                        reminder.scheduledDate = primaryFireDate(onSameDayAs: next)
                    }
                } else {
                    reminder.isEnabled = false
                }
            }
            try? modelContext.save()
            if reminder.isEnabled {
                await LureliaNotificationManager.shared.scheduleReminder(reminder)
            }
        }
    }

    private func primaryFireDate(onSameDayAs date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.dateComponents([.year, .month, .day], from: date)
        let time = cal.dateComponents([.hour, .minute, .second], from: reminder.scheduledDate)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second ?? 0
        return cal.date(from: day) ?? date
    }

    private func nextScheduledDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        let allTodayFires = allFireTimesOnSameDay(as: reminder.scheduledDate, using: calendar)
        if let nextToday = allTodayFires.filter({ $0 > date }).min() { return nextToday }
        return nextOccurrenceAfter(date: date, calendar: calendar)
    }

    private func allFireTimesOnSameDay(as refDate: Date, using calendar: Calendar) -> [Date] {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: refDate)
        let times = resolvedTimesOfDay()

        return times.compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            var c = dayComponents
            c.hour = h
            c.minute = m
            c.second = 0
            return calendar.date(from: c)
        }.sorted()
    }

    private func nextOccurrenceAfter(date: Date, calendar: Calendar) -> Date? {
        let interval = max(1, reminder.repeatInterval)
        var next = reminder.scheduledDate

        func earliestFireOn(_ d: Date) -> Date? {
            allFireTimesOnSameDay(as: d, using: calendar).filter { $0 > date }.min()
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
            let wds = Set(reminder.repeatWeekdays)
            let start = calendar.startOfDay(for: date)
            for offset in 1...370 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                guard wds.contains(calendar.component(.weekday, from: day)) else { continue }
                if let fire = earliestFireOn(day) { return fire }
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

// MARK: - Stat Card

struct LureliaReminderStatCard: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76).padding(.horizontal, 8)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
    }
}
