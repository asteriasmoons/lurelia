//
//  CoinsView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaCoinsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var tasks: [LureliaTask]
    @Query private var reminders: [LureliaReminder]
    @Query private var routineStats: [LureliaRoutineStats]

    @State private var appeared = false
    @State private var starPulse = false

    private let purplePrimary = Color(lureliaHex: "#6a1eff")
    private let purpleMid = Color(lureliaHex: "#8b4cff")
    private let purpleSoft = Color(lureliaHex: "#c7a3ff")
    private let purpleDark = Color(lureliaHex: "#251044")

    private var purpleGrad: LinearGradient {
        LinearGradient(
            colors: [
                purplePrimary,
                purpleMid,
                purpleSoft
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var userSettings: UserSettings? {
        settings.first
    }

    private var currentRoutineStats: LureliaRoutineStats? {
        routineStats.first
    }

    private var balance: Int {
        userSettings?.coinBalance ?? 0
    }

    private var completedTasks: [LureliaTask] {
        tasks.filter { $0.isCompleted }
    }

    private var tasksCompleted: Int {
        completedTasks.count
    }

    private var earnedFromCompletedTasks: Int {
        completedTasks.reduce(0) { $0 + $1.coinReward }
    }

    private var totalPossibleCoins: Int {
        tasks.reduce(0) { $0 + $1.coinReward }
    }

    private var canBuyBackMissedStreak: Bool {
        balance >= 500 && mostRecentMissedReminderStreakDay() != nil
    }

    private var buyBackSubtitle: String {
        canBuyBackMissedStreak
        ? "Spend coins to repair your most recent missed reminder streak day."
        : "Requires 500 coins and a missed reminder streak day."
    }

    private var canSkipWithoutBreakingStreak: Bool {
        balance >= 250 && remainingReminderFireTimesToday().isEmpty == false
    }

    private var skipWithoutBreakingSubtitle: String {
        canSkipWithoutBreakingStreak
        ? "Spend coins to skip today’s remaining reminder fire times without breaking your streak."
        : "Requires 250 coins and remaining reminder fire times today."
    }

    private var canBuyBackRoutineTime: Bool {
        balance >= 150 && (currentRoutineStats?.routineTimeMissedMinutes ?? 0) > 0
    }

    private var routineTimeBuybackSubtitle: String {
        guard let stats = currentRoutineStats,
              stats.routineTimeMissedMinutes > 0 else {
            return "Requires missed routine minutes to restore."
        }

        let recoverAmount = min(30, stats.routineTimeMissedMinutes)
        return "Restore \(recoverAmount) missed routine minute\(recoverAmount == 1 ? "" : "s") into credited time."
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 10)

                        coinHero

                        balanceCard

                        howToEarnCard

                        comingSoonCard

                        Spacer().frame(height: 100)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) {
                appeared = true
            }

            starPulse = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Coins")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 59)
        .padding(.bottom, 18)
    }

    // MARK: - Coin Hero

    private var coinHero: some View {
        ZStack {
            Circle()
                .fill(purplePrimary.opacity(0.22))
                .frame(width: 142, height: 142)
                .blur(radius: 25)
                .scaleEffect(starPulse ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: starPulse)

            Image("sparkle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .foregroundStyle(purpleGrad)
                .shadow(color: purplePrimary.opacity(0.55), radius: 20, y: 8)
                .scaleEffect(starPulse ? 1.08 : 0.94)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: starPulse)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .onAppear { starPulse = true }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Coin Balance")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(purpleSoft.opacity(0.82))
                    .textCase(.uppercase)

                Text("\(balance)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(purpleSoft)
                    .monospacedDigit()
                    .shadow(color: purplePrimary.opacity(0.30), radius: 12)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
            }

            HStack(spacing: 0) {
                LureliaCoinsStatCell(
                    label: "Earned",
                    value: "+\(earnedFromCompletedTasks)",
                    color: purplePrimary
                )

                Divider()
                    .frame(width: 1, height: 36)
                    .background(.white.opacity(0.12))

                LureliaCoinsStatCell(
                    label: "Tasks Done",
                    value: "\(tasksCompleted)",
                    color: purplePrimary
                )

                Divider()
                    .frame(width: 1, height: 36)
                    .background(.white.opacity(0.12))

                LureliaCoinsStatCell(
                    label: "Possible",
                    value: "\(totalPossibleCoins)",
                    color: purplePrimary
                )
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(purplePrimary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            purplePrimary.opacity(0.55),
                            Color.white.opacity(0.85).opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: purplePrimary.opacity(0.16), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 24)
    }

    // MARK: - How to Earn

    private var howToEarnCard: some View {
        LureliaCoinsSectionCard(title: "How to Earn") {
            VStack(spacing: 10) {
                LureliaEarnRow(
                    icon: "checkwavy",
                    label: "Complete a task",
                    amount: "Task reward",
                    color: purpleSoft
                )

                LureliaEarnRow(
                    icon: "starcal",
                    label: "Choose higher-effort tasks",
                    amount: "More coins",
                    color: purplePrimary
                )

                LureliaEarnRow(
                    icon: "clockfill",
                    label: "Finish scheduled routines",
                    amount: "Coming soon",
                    color: purpleSoft
                )

                LureliaEarnRow(
                    icon: "flame",
                    label: "Build completion streaks",
                    amount: "Coming soon",
                    color: purplePrimary
                )
            }
        }
    }

    // MARK: - Coming Soon

    private var comingSoonCard: some View {
        LureliaCoinsSectionCard(title: "Rewards Options") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Use your coins to repair missed progress, protect your streaks, and restore routine time when life gets messy.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    buyBackMissedReminderStreak()
                } label: {
                    LureliaRewardPlaceholderRow(
                        title: "Buy Back a Missed Streak",
                        description: buyBackSubtitle,
                        cost: 500
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canBuyBackMissedStreak)
                .opacity(canBuyBackMissedStreak ? 1 : 0.45)

                Button {
                    skipWithoutBreakingReminderStreak()
                } label: {
                    LureliaRewardPlaceholderRow(
                        title: "Skip Without Breaking Streak",
                        description: skipWithoutBreakingSubtitle,
                        cost: 250
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSkipWithoutBreakingStreak)
                .opacity(canSkipWithoutBreakingStreak ? 1 : 0.45)

                Button {
                    buyBackRoutineTime()
                } label: {
                    LureliaRewardPlaceholderRow(
                        title: "Routine Time Buyback",
                        description: routineTimeBuybackSubtitle,
                        cost: 150
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canBuyBackRoutineTime)
                .opacity(canBuyBackRoutineTime ? 1 : 0.45)
            }
        }
    }


    // MARK: - Reward Actions

    private func buyBackRoutineTime() {
        guard balance >= 150,
              let settings = userSettings,
              let stats = currentRoutineStats,
              stats.routineTimeMissedMinutes > 0 else { return }

        let recoverAmount = min(30, stats.routineTimeMissedMinutes)

        stats.routineTimeMissedMinutes = max(0, stats.routineTimeMissedMinutes - recoverAmount)
        stats.routineTimeCreditMinutes += recoverAmount
        stats.totalBuybacksUsed += 1
        stats.totalCoinsSpentOnBuybacks += 150
        stats.lastBuybackAt = Date()
        stats.updatedAt = Date()

        settings.coinBalance = max(0, settings.coinBalance - 150)

        do {
            try modelContext.save()
        } catch {
            print("[CoinsView] Failed to buy back routine time: \(error)")
        }
    }

    private func skipWithoutBreakingReminderStreak() {
        guard balance >= 250,
              let settings = userSettings else { return }

        let remainingFireTimes = remainingReminderFireTimesToday()
        guard !remainingFireTimes.isEmpty else { return }

        for entry in remainingFireTimes {
            var completionTimestamps = entry.reminder.completionTimestamps
            var skippedTimestamps = entry.reminder.skippedTimestamps

            let alreadyCompleted = completionTimestamps.contains { existingDate in
                abs(existingDate.timeIntervalSince(entry.fireDate)) < 60
            }

            if !alreadyCompleted {
                completionTimestamps.append(entry.fireDate)
            }

            let alreadySkipped = skippedTimestamps.contains { existingDate in
                abs(existingDate.timeIntervalSince(entry.fireDate)) < 60
            }

            if !alreadySkipped {
                skippedTimestamps.append(entry.fireDate)
            }

            entry.reminder.completionTimestamps = completionTimestamps
            entry.reminder.skippedTimestamps = skippedTimestamps
        }

        settings.coinBalance = max(0, settings.coinBalance - 250)

        do {
            try modelContext.save()
        } catch {
            print("[CoinsView] Failed to skip without breaking reminder streak: \(error)")
        }
    }

    private func buyBackMissedReminderStreak() {
        guard balance >= 500,
              let settings = userSettings,
              let missedDay = mostRecentMissedReminderStreakDay() else { return }

        let calendar = Calendar.current
        let activeReminders = reminders.filter { $0.isEnabled }

        for reminder in activeReminders {
            let fireDates = fireTimes(for: reminder, on: missedDay, calendar: calendar)
            guard !fireDates.isEmpty else { continue }

            var timestamps = reminder.completionTimestamps
            for fireDate in fireDates {
                let alreadyCompleted = timestamps.contains { existingDate in
                    abs(existingDate.timeIntervalSince(fireDate)) < 60
                }

                if !alreadyCompleted {
                    timestamps.append(fireDate)
                }
            }
            reminder.completionTimestamps = timestamps
        }

        settings.coinBalance = max(0, settings.coinBalance - 500)

        do {
            try modelContext.save()
        } catch {
            print("[CoinsView] Failed to buy back missed reminder streak: \(error)")
        }
    }

    private func remainingReminderFireTimesToday() -> [(reminder: LureliaReminder, fireDate: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [(reminder: LureliaReminder, fireDate: Date)] = []

        for reminder in reminders where reminder.isEnabled {
            let fireDates = fireTimes(for: reminder, on: today, calendar: calendar)
            guard !fireDates.isEmpty else { continue }

            for fireDate in fireDates {
                let isCompleted = reminder.completionTimestamps.contains { existingDate in
                    abs(existingDate.timeIntervalSince(fireDate)) < 60
                }

                let isSkipped = reminder.skippedTimestamps.contains { existingDate in
                    abs(existingDate.timeIntervalSince(fireDate)) < 60
                }

                if !isCompleted && !isSkipped {
                    results.append((reminder, fireDate))
                }
            }
        }

        return results.sorted { $0.fireDate < $1.fireDate }
    }

    private func mostRecentMissedReminderStreakDay() -> Date? {
        let calendar = Calendar.current
        let activeReminders = reminders.filter { $0.isEnabled }
        guard !activeReminders.isEmpty else { return nil }

        let today = calendar.startOfDay(for: Date())

        for offset in 0...370 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            let dueFireCount = activeReminders.reduce(0) { total, reminder in
                total + fireTimes(for: reminder, on: day, calendar: calendar).count
            }
            guard dueFireCount > 0 else { continue }

            let completedFireTotal = activeReminders.reduce(0) { total, reminder in
                total + completedFireCount(for: reminder, on: day, calendar: calendar)
            }

            if completedFireTotal < dueFireCount {
                return day
            }
        }

        return nil
    }

    private func completedFireCount(for reminder: LureliaReminder, on day: Date, calendar: Calendar) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        var count = reminder.completionTimestamps.filter {
            calendar.isDate($0, inSameDayAs: dayStart)
        }.count

        if count == 0,
           reminder.repeatUnit == .none,
           reminder.isCompleted,
           let completedAt = reminder.completedAt,
           calendar.isDate(completedAt, inSameDayAs: dayStart) {
            count = 1
        }

        return min(count, fireTimes(for: reminder, on: dayStart, calendar: calendar).count)
    }

    private func fireTimes(for reminder: LureliaReminder, on day: Date, calendar: Calendar) -> [Date] {
        guard reminder.isEnabled else { return [] }
        let dayStart = calendar.startOfDay(for: day)

        if reminder.repeatUnit == .none {
            let anchor = reminder.nextFireAt ?? reminder.scheduledDate
            guard calendar.isDate(anchor, inSameDayAs: dayStart) else { return [] }
            return resolvedTimesOfDay(for: reminder, on: dayStart, calendar: calendar)
        }

        if let nextFire = reminder.nextFireAt,
           !calendar.isDate(nextFire, inSameDayAs: dayStart) {
            return []
        }

        if !isRepeatingReminderDue(reminder, on: dayStart, calendar: calendar) {
            return []
        }

        return resolvedTimesOfDay(for: reminder, on: dayStart, calendar: calendar)
    }

    private func isRepeatingReminderDue(_ reminder: LureliaReminder, on day: Date, calendar: Calendar) -> Bool {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        guard reminder.scheduledDate <= endOfDay else { return false }

        switch reminder.repeatUnit {
        case .minutes, .hours, .days:
            return true

        case .weeks:
            if !reminder.repeatWeekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: day)
                return reminder.repeatWeekdays.contains(weekday)
            }
            return true

        case .months:
            let scheduledDay = calendar.component(.day, from: reminder.scheduledDate)
            let currentDay = calendar.component(.day, from: day)
            return scheduledDay == currentDay

        case .years:
            let scheduled = calendar.dateComponents([.month, .day], from: reminder.scheduledDate)
            let current = calendar.dateComponents([.month, .day], from: day)
            return scheduled.month == current.month && scheduled.day == current.day

        case .none:
            return false
        }
    }

    private func resolvedTimesOfDay(for reminder: LureliaReminder, on day: Date, calendar: Calendar) -> [Date] {
        var timeStrings = reminder.timesOfDay.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if timeStrings.isEmpty {
            if reminder.primaryHour != -1 {
                timeStrings.append(String(format: "%02d:%02d", reminder.primaryHour, reminder.primaryMinute))
            } else {
                let hour = calendar.component(.hour, from: reminder.scheduledDate)
                let minute = calendar.component(.minute, from: reminder.scheduledDate)
                timeStrings.append(String(format: "%02d:%02d", hour, minute))
            }

            for fireTime in reminder.additionalFireTimes {
                timeStrings.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
            }
        }

        var seen = Set<String>()

        return timeStrings.compactMap { rawValue -> Date? in
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = value.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { return nil }

            let normalized = String(format: "%02d:%02d", hour, minute)
            guard !seen.contains(normalized) else { return nil }
            seen.insert(normalized)

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }
        .sorted()
    }

}

// MARK: - Supporting Views

struct LureliaCoinsStatCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .shadow(color: color.opacity(0.3), radius: 8)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LureliaCoinsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(lureliaHex: "#6a1eff").opacity(0.92))
                .textCase(.uppercase)

            content
        }
        .padding(18)
        .background(LColors.glassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            LColors.glassBorderStrong,
                            Color(lureliaHex: "#6a1eff").opacity(0.42),
                            Color(lureliaHex: "#c7a3ff").opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.white.opacity(0.85).opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
    }
}

struct LureliaEarnRow: View {
    let icon: String
    let label: String
    let amount: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.25), radius: 6)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            HStack(spacing: 4) {
                Image("sparkle")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)

                Text(amount)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Color(lureliaHex: "#6a1eff"))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(lureliaHex: "#251044").opacity(0.42), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(lureliaHex: "#6a1eff").opacity(0.45), lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }
}

struct LureliaRewardPlaceholderRow: View {
    let title: String
    let description: String
    let cost: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(lureliaHex: "#6a1eff").opacity(0.10))
                    .frame(width: 40, height: 40)

                Image("sparkle")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(Color(lureliaHex: "#6a1eff"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 4) {
                Image("sparkle")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)

                Text("\(cost)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Color(lureliaHex: "#6a1eff"))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(lureliaHex: "#251044").opacity(0.42), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(lureliaHex: "#6a1eff").opacity(0.45), lineWidth: 1)
            )
        }
        .padding(14)
        .background(Color(lureliaHex: "#6a1eff").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(lureliaHex: "#6a1eff").opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    LureliaCoinsView()
}
