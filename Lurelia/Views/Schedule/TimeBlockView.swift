//
//  TimeBlockView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

// MARK: - Slot
// One entry per (reminder × fire-time). A reminder with 3 times today
// produces 3 separate slots, each pinned to the correct hour.

private struct ReminderSlot: Identifiable {
    let id = UUID()
    let reminder: LureliaReminder
    let fireDate: Date
}

// MARK: - TimeBlockView

struct TimeBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var reminders: [LureliaReminder]

    private let calendar  = Calendar.current
    private let startHour = 6
    private let endHour   = 23

    // Mutating this at midnight forces todaysSlots to recompute.
    @State private var currentDay: Date = Calendar.current.startOfDay(for: Date())

    // All slots for today, one per (reminder × fire-time).
    private var todaysSlots: [ReminderSlot] {
        let today = calendar.startOfDay(for: currentDay)
        var slots: [ReminderSlot] = []

        for reminder in reminders where reminder.isEnabled && reminder.kind == .standalone {
            guard shouldShowReminder(reminder, on: today) else { continue }

            for fireDate in resolvedFireTimesToday(reminder, today: today) {
                slots.append(ReminderSlot(reminder: reminder, fireDate: fireDate))
            }
        }

        return slots.sorted { $0.fireDate < $1.fireDate }
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 0) {

                // Nav bar
                HStack(alignment: .center, spacing: 12) {
                    Text("Time Block")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Spacer()

                    Button { dismiss() } label: {
                        Image("xmarkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 59)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if todaysSlots.isEmpty {
                            emptyState
                        } else {
                            timeline
                        }
                    }
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LColors.glassSurface)
                            .overlay {
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
                            }
                            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { scheduleMidnightRefresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Timeline")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Image("clockfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)

                Text("\(todaysSlots.count)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(LGradients.header))
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(startHour...endHour, id: \.self) { hour in
                TimeBlockHourRow(
                    hour: hour,
                    slots: slotsForHour(hour),
                    isCurrentHour: calendar.component(.hour, from: Date()) == hour
                )
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("starcal")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .foregroundStyle(LGradients.header)

            Text("Nothing Blocked Yet")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Text("Reminders scheduled for today will appear here in their time slots.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LColors.glassBorder, lineWidth: 1)
        }
    }

    // MARK: - Slot helpers

    private func slotsForHour(_ hour: Int) -> [ReminderSlot] {
        todaysSlots.filter { calendar.component(.hour, from: $0.fireDate) == hour }
    }

    /// Expands one reminder into all its fire-dates for `today` after shouldShowReminder has confirmed
    /// the reminder actually belongs on this date.
    /// Priority order:
    ///   1. timesOfDay ["HH:mm"] — the canonical multi-time source
    ///   2. additionalFireTimes (legacy extra-time objects)
    ///   3. primaryHour / primaryMinute
    ///   4. nextFireAt fallback only when it falls on today
    private func resolvedFireTimesToday(_ reminder: LureliaReminder, today: Date) -> [Date] {
        var results: [Date] = []

        // 1. timesOfDay ["HH:mm"]
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        for hhmm in stored {
            if let d = parseHHMM(hhmm, on: today) { results.append(d) }
        }

        // 2. additionalFireTimes
        for ft in reminder.additionalFireTimes {
            let hhmm = String(format: "%02d:%02d", ft.hour, ft.minute)
            if let d = parseHHMM(hhmm, on: today),
               !results.contains(where: { calendar.isDate($0, equalTo: d, toGranularity: .minute) }) {
                results.append(d)
            }
        }

        if !results.isEmpty { return results.sorted() }

        // 3. primaryHour / primaryMinute
        if reminder.primaryHour != -1 {
            let hhmm = String(format: "%02d:%02d", reminder.primaryHour, reminder.primaryMinute)
            if let d = parseHHMM(hhmm, on: today) {
                results.append(d)
                return results
            }
        }

        // 4. Only use nextFireAt if it genuinely falls on today.
        //    Never pin scheduledDate to today — that drags in every reminder ever created.
        if let next = reminder.nextFireAt, calendar.isDate(next, inSameDayAs: today) {
            results.append(next)
        }

        return results.sorted()
    }

    private func parseHHMM(_ str: String, on day: Date) -> Date? {
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
    }

    private func shouldShowReminder(_ reminder: LureliaReminder, on day: Date) -> Bool {
        if reminder.repeatUnit == .none {
            if reminder.isCompleted { return false }
            if let next = reminder.nextFireAt {
                return calendar.isDate(next, inSameDayAs: day)
            }
            return calendar.isDate(reminder.scheduledDate, inSameDayAs: day)
        }

        // For repeating/routine reminders, nextFireAt is the scheduling source of truth.
        // If it exists and is not today, do not pin old stored clock times onto today.
        if let next = reminder.nextFireAt {
            return calendar.isDate(next, inSameDayAs: day)
        }

        // Fallback only for older reminders that do not have nextFireAt populated yet.
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        guard reminder.scheduledDate <= endOfDay else { return false }

        switch reminder.repeatUnit {
        case .minutes, .hours, .days:
            return calendar.isDate(reminder.scheduledDate, inSameDayAs: day)

        case .weeks:
            if !reminder.repeatWeekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: day)
                return reminder.repeatWeekdays.contains(weekday)
            }
            return calendar.isDate(reminder.scheduledDate, inSameDayAs: day)

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

    // MARK: - Midnight refresh

    private func scheduleMidnightRefresh() {
        guard let tomorrow = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: Date())
        ) else { return }

        let delay = tomorrow.timeIntervalSinceNow
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            currentDay = calendar.startOfDay(for: Date())
            scheduleMidnightRefresh()
        }
    }
}

// MARK: - Hour row

private struct TimeBlockHourRow: View {
    let hour: Int
    let slots: [ReminderSlot]
    let isCurrentHour: Bool

    private var hourLabel: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
            .replacingOccurrences(of: ":00", with: "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(hourLabel)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(isCurrentHour ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LColors.textSecondary))

                Rectangle()
                    .fill(isCurrentHour ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LColors.glassBorder.opacity(0.45)))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 10) {
                if slots.isEmpty {
                    Rectangle()
                        .fill(LColors.glassBorder.opacity(0.25))
                        .frame(height: 1)
                        .padding(.top, 8)
                } else {
                    ForEach(slots) { slot in
                        TimeBlockReminderCard(slot: slot)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, slots.isEmpty ? 20 : 12)
        }
        .padding(.top, 4)
    }
}

// MARK: - Reminder card

private struct TimeBlockReminderCard: View {
    let slot: ReminderSlot

    private var reminder: LureliaReminder { slot.reminder }
    private var fireDate: Date           { slot.fireDate }

    private var isCompleted: Bool { reminder.isCompleted }

    private var isDueNow: Bool {
        !isCompleted && abs(fireDate.timeIntervalSinceNow) <= 15 * 60
    }

    // A slot is only overdue if the reminder is non-repeating, not completed,
    // and the fire time has passed. Recurring reminders that fired earlier
    // today are simply past — not overdue.
    private var isOverdue: Bool {
        !isCompleted
            && !isDueNow
            && fireDate < Date()
            && reminder.repeatUnit == .none
    }

    private var accent: Color {
        if isCompleted { return .white.opacity(0.3) }
        if isOverdue   { return Color(lureliaHex: "#ff9be6") }
        if isDueNow    { return Color(lureliaHex: "#b476ff") }
        return Color(lureliaHex: "#7eedff")
    }

    private var statusText: String {
        if isCompleted { return "DONE" }
        if isOverdue   { return "OVERDUE" }
        if isDueNow    { return "DUE NOW" }
        return "UPCOMING"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 36, height: 36)

                LureliaIconView(iconId: reminder.icon, size: 19)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Text(reminder.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(isCompleted ? LColors.textSecondary : LColors.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 6)

                    Circle()
                        .strokeBorder(accent.opacity(0.75), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }

                HStack(spacing: 6) {
                    Text(fireDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))

                    Text(statusText)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
                }

                if let notes = reminder.notes,
                   !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(12)
        .opacity(isCompleted ? 0.5 : 1.0)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LColors.glassSurface2)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.18),
                                    LColors.gradientPurple.opacity(0.22),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.92),
                                    LColors.gradientPurple.opacity(0.92),
                                    Color.white.opacity(0.38)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.05
                        )
                }
        }
    }
}

#Preview {
    ZStack {
        LureliaBackgroundAlt()
        TimeBlockView()
    }
}

