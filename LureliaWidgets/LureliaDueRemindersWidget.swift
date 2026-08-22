//
//  LureliaDueRemindersWidget.swift
//  Lurelia
//

import WidgetKit
import SwiftUI
import AppIntents
import SwiftData
import UIKit

struct LureliaWidgetReminderItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let icon: String
    let fireDate: Date
    let status: LureliaWidgetReminderStatus
    /// User-selected reminder color hex (fallback `#7d19f7` for legacy
    /// reminders with no color set).
    let colorHex: String
}

enum LureliaWidgetReminderStatus: String, Hashable {
    case dueNow = "Due Now"
    case soon = "Soon"
}

struct LureliaDueRemindersEntry: TimelineEntry {
    let date: Date
    let reminders: [LureliaWidgetReminderItem]
    let debugInfo: String
}

struct LureliaDueRemindersProvider: TimelineProvider {
    func placeholder(in context: Context) -> LureliaDueRemindersEntry {
        LureliaDueRemindersEntry(
            date: Date(),
            reminders: [
                LureliaWidgetReminderItem(
                    id: UUID(),
                    title: "Medicine PM",
                    icon: "pillfill",
                    fireDate: Date(),
                    status: .dueNow,
                    colorHex: "#7d19f7"
                ),
                LureliaWidgetReminderItem(
                    id: UUID(),
                    title: "Journal",
                    icon: "journalfill",
                    fireDate: Date().addingTimeInterval(20 * 60),
                    status: .soon,
                    colorHex: "#03dbfc"
                )
            ],
            debugInfo: "placeholder"
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (LureliaDueRemindersEntry) -> Void
    ) {
        let now = Date()
        let result = fetchWidgetReminders(now: now)
        completion(
            LureliaDueRemindersEntry(
                date: now,
                reminders: result.items,
                debugInfo: result.debugInfo
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<LureliaDueRemindersEntry>) -> Void
    ) {
        let now = Date()
        let result = fetchWidgetReminders(now: now)

        // Collect future fire dates where "Soon" would flip to "Due Now"
        let transitionDates = result.items
            .filter { $0.status == .soon }
            .map { $0.fireDate }
            .sorted()

        var entries: [LureliaDueRemindersEntry] = [
            LureliaDueRemindersEntry(
                date: now,
                reminders: result.items,
                debugInfo: result.debugInfo
            )
        ]

        // Re-evaluate status at each transition point using already-fetched data
        for transitionDate in transitionDates.prefix(12) {
            let reEvaluated = result.items.map { item in
                LureliaWidgetReminderItem(
                    id: item.id,
                    title: item.title,
                    icon: item.icon,
                    fireDate: item.fireDate,
                    status: item.fireDate <= transitionDate ? .dueNow : .soon,
                    colorHex: item.colorHex
                )
            }
            entries.append(
                LureliaDueRemindersEntry(
                    date: transitionDate,
                    reminders: reEvaluated,
                    debugInfo: result.debugInfo
                )
            )
        }

        // Refresh after the last transition or 15 minutes, whichever is sooner
        let lastTransition = transitionDates.last ?? now
        let nextRefresh = min(
            lastTransition.addingTimeInterval(60),
            now.addingTimeInterval(15 * 60)
        )

        completion(
            Timeline(
                entries: entries,
                policy: .after(nextRefresh)
            )
        )
    }

    private func fetchWidgetReminders(now: Date) -> (items: [LureliaWidgetReminderItem], debugInfo: String) {
        do {
            let container = try LureliaWidgetShared.makeModelContainer()
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<LureliaReminder>(
                sortBy: [SortDescriptor(\.scheduledDate)]
            )

            let allReminders = try context.fetch(descriptor)
            let enabledReminders = allReminders.filter { reminder in
                reminder.kind != .routine &&
                reminder.isEnabled &&
                !(reminder.repeatUnit == .none && reminder.isCompleted)
            }

            let items = enabledReminders
                .compactMap { reminder in
                    widgetItem(for: reminder, now: now)
                }
                .sorted { a, b in
                    if a.status == .dueNow && b.status != .dueNow { return true }
                    if a.status != .dueNow && b.status == .dueNow { return false }
                    return a.fireDate < b.fireDate
                }
                .prefix(6)
                .map { $0 }

            let firstFire: String
            if let first = enabledReminders.first {
                let fireDate = first.nextFireAt ?? first.scheduledDate
                let diff = fireDate.timeIntervalSince(now)
                firstFire = "\(first.title): fire=\(Int(diff))s nfa=\(first.nextFireAt != nil)"
            } else {
                firstFire = "none"
            }

            let debug = "raw=\(allReminders.count) en=\(enabledReminders.count) shown=\(items.count) | \(firstFire)"
            return (items, debug)
        } catch {
            return ([], "SwiftData error: \(error.localizedDescription)")
        }
    }

    private func widgetItem(
        for reminder: LureliaReminder,
        now: Date
    ) -> LureliaWidgetReminderItem? {
        let fireDate = displayFireDate(for: reminder, now: now)

        // No hard cutoff — surface every enabled, non-completed reminder
        // sorted by fire date so upcoming (even weeks-out) reminders like a
        // birthday still show up on the widget instead of being filtered
        // out as "not due soon".
        let hex = reminder.colorHex.trimmingCharacters(in: .whitespacesAndNewlines)

        // Anything within the next 24 hours or already past due reads as
        // "Due Now"; further out reads as "Soon".
        let soonThreshold = now.addingTimeInterval(24 * 60 * 60)
        let status: LureliaWidgetReminderStatus =
            fireDate <= soonThreshold ? .dueNow : .soon

        return LureliaWidgetReminderItem(
            id: reminder.id,
            title: reminder.title,
            icon: reminder.icon.isEmpty ? "bellfill" : reminder.icon,
            fireDate: fireDate,
            status: fireDate <= now ? .dueNow : status,
            colorHex: hex.isEmpty ? "#7d19f7" : hex
        )
    }

    private func displayFireDate(for reminder: LureliaReminder, now: Date) -> Date {
        reminder.nextFireAt ?? reminder.scheduledDate
    }

    private func firstUncompletedOccurrenceToday(
        for reminder: LureliaReminder,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let todayOccurrences = allFireTimesOnSameDay(
            for: reminder,
            as: now,
            using: calendar
        )

        // Most recent past occurrence that hasn't been completed or skipped (Due Now)
        if let pastDue = todayOccurrences
            .filter({ $0 <= now })
            .last(where: {
                !wasOccurrenceCompleted(reminder, occurrence: $0, calendar: calendar) &&
                !wasOccurrenceSkipped(reminder, occurrence: $0, calendar: calendar)
            }) {
            return pastDue
        }

        // Next future occurrence that hasn't been completed or skipped (Soon)
        return todayOccurrences
            .filter { $0 > now }
            .first {
                !wasOccurrenceCompleted(reminder, occurrence: $0, calendar: calendar) &&
                !wasOccurrenceSkipped(reminder, occurrence: $0, calendar: calendar)
            }
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

    private func resolvedTimesOfDay(_ reminder: LureliaReminder) -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        if !stored.isEmpty { return stored.sorted() }

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

        return Array(Set(times)).sorted()
    }

    private func wasOccurrenceCompleted(
        _ reminder: LureliaReminder,
        occurrence: Date,
        calendar: Calendar
    ) -> Bool {
        let occurrenceComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: occurrence)

        return reminder.completionTimestamps.contains { completed in
            let completedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: completed)
            return completedComponents.year == occurrenceComponents.year &&
            completedComponents.month == occurrenceComponents.month &&
            completedComponents.day == occurrenceComponents.day &&
            completedComponents.hour == occurrenceComponents.hour &&
            completedComponents.minute == occurrenceComponents.minute
        }
    }

    private func wasOccurrenceSkipped(
        _ reminder: LureliaReminder,
        occurrence: Date,
        calendar: Calendar
    ) -> Bool {
        let occurrenceComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: occurrence)

        return reminder.skippedTimestamps.contains { skipped in
            let skippedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: skipped)
            return skippedComponents.year == occurrenceComponents.year &&
            skippedComponents.month == occurrenceComponents.month &&
            skippedComponents.day == occurrenceComponents.day &&
            skippedComponents.hour == occurrenceComponents.hour &&
            skippedComponents.minute == occurrenceComponents.minute
        }
    }
}

struct LureliaDueRemindersWidgetView: View {
    let entry: LureliaDueRemindersEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if entry.reminders.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(entry.reminders.prefix(6)) { reminder in
                        reminderRow(reminder)
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
            widgetIcon("bellfill", size: 15)

            Text("Reminders")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Text("Now")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var emptyState: some View {
        Text("Nothing due soon")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }

    private func reminderRow(_ reminder: LureliaWidgetReminderItem) -> some View {
        let tint = Color(widgetHex: reminder.colorHex)

        return HStack(spacing: 9) {
            Button(
                intent: CompleteReminderWidgetIntent(
                    reminderID: reminder.id.uuidString
                )
            ) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 22, height: 22)

                    Circle()
                        .strokeBorder(tint, lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)

            widgetIcon(reminder.icon, tint: tint, size: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(reminder.status.rawValue)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(tint)

                    Text(reminder.fireDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer(minLength: 0)

            Button(
                intent: SkipReminderWidgetIntent(
                    reminderID: reminder.id.uuidString
                )
            ) {
                skipIcon(size: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.55), lineWidth: 1)
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
                .foregroundStyle(.white.opacity(0.55))
        } else {
            Image(systemName: "forward.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private func widgetIcon(
        _ name: String,
        tint: Color = .white,
        size: CGFloat
    ) -> some View {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconName = trimmedName.isEmpty ? "bellfill" : trimmedName

        if let uiImage = LureliaWidgetShared.widgetIcon(for: iconName) {
            tint
                .mask(
                    Image(uiImage: uiImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                )
                .frame(width: size, height: size)
        } else if let fallbackImage = LureliaWidgetShared.widgetIcon(for: "bellfill") {
            tint
                .mask(
                    Image(uiImage: fallbackImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                )
                .frame(width: size, height: size)
        } else {
            Image(systemName: "bell.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }
}

struct LureliaDueRemindersWidget: Widget {
    let kind = "LureliaDueRemindersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: LureliaDueRemindersProvider()
        ) { entry in
            LureliaDueRemindersWidgetView(entry: entry)
        }
        .configurationDisplayName("Due Reminders")
        .description("See reminders due now and coming up soon.")
        .supportedFamilies([
            .systemLarge
        ])
    }
}
