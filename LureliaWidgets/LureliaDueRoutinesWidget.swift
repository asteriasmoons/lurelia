//
//  LureliaDueRoutinesWidget.swift
//  Lurelia
//

import WidgetKit
import SwiftUI
import AppIntents
import SwiftData
import UIKit

struct LureliaWidgetRoutineItem: Identifiable, Hashable {
    let id: String // Maps to persistentID
    let name: String
    let icon: String
    let colorHex: String
    let timeRange: String
    let status: LureliaWidgetRoutineStatus
    let phaseID: String?
    let phaseName: String?
    var isDone: Bool
}

enum LureliaWidgetRoutineStatus: String, Hashable {
    case dueNow = "Due Now"
    case soon = "Soon"
}

struct LureliaDueRoutinesEntry: TimelineEntry {
    let date: Date
    let routines: [LureliaWidgetRoutineItem]
}

struct LureliaDueRoutinesProvider: TimelineProvider {
    func placeholder(in context: Context) -> LureliaDueRoutinesEntry {
        LureliaDueRoutinesEntry(
            date: Date(),
            routines: [
                LureliaWidgetRoutineItem(
                    id: UUID().uuidString,
                    name: "Morning Ritual",
                    icon: "sunrise.fill",
                    colorHex: "#7d19f7",
                    timeRange: "8AM \u{2013} 8:30AM",
                    status: .dueNow,
                    phaseID: nil,
                    phaseName: "Shower Prep",
                    isDone: false
                ),
                LureliaWidgetRoutineItem(
                    id: UUID().uuidString,
                    name: "Evening Wind Down",
                    icon: "moon.stars.fill",
                    colorHex: "#03dbfc",
                    timeRange: "9:30PM \u{2013} 10PM",
                    status: .soon,
                    phaseID: nil,
                    phaseName: "Aftercare",
                    isDone: false
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LureliaDueRoutinesEntry) -> Void) {
        let entry = fetchRoutines()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LureliaDueRoutinesEntry>) -> Void) {
        let entry = fetchRoutines()
        let nextRefresh = Date().addingTimeInterval(15 * 60) // Refresh every 15 minutes
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func fetchRoutines() -> LureliaDueRoutinesEntry {
        do {
            let container = try LureliaWidgetShared.makeModelContainer()
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<LureliaRoutine>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            
            let allRoutines = try context.fetch(descriptor)

            for routine in allRoutines {
                print("Routine '\(routine.name)' icon = '\(routine.icon)'")
                print("Exists = \(FileManager.default.fileExists(atPath: LureliaWidgetShared.iconURL(for: routine.icon).path))")
                print("Path = \(LureliaWidgetShared.iconURL(for: routine.icon).path)")
            }
            
            let now = Date()

            let items = allRoutines
                .filter { routine in
                    let hasRoutineSchedule = routine.scheduleEnabled &&
                        !routine.scheduledDays.isEmpty
                    let hasPhaseSchedule = routine.phasesEnabled &&
                        (routine.phases ?? []).contains { $0.scheduleEnabled && !$0.scheduledDays.isEmpty }
                    return hasRoutineSchedule || hasPhaseSchedule
                }
                .compactMap { routine in
                    routineWidgetItem(for: routine, now: now)
                }
                .sorted { left, right in
                    if left.status == .dueNow && right.status != .dueNow { return true }
                    if left.status != .dueNow && right.status == .dueNow { return false }
                    return left.timeRange < right.timeRange
                }
            
            return LureliaDueRoutinesEntry(date: Date(), routines: items)
        } catch {
            return LureliaDueRoutinesEntry(date: Date(), routines: [])
        }
    }
    private func routineWidgetItem(
        for routine: LureliaRoutine,
        now: Date
    ) -> LureliaWidgetRoutineItem? {
        guard let startDate = nextRoutineStartDate(for: routine, now: now) else {
            return nil
        }

        let endDate: Date
        if routine.phasesEnabled {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: startDate)
            let latestEnd = (routine.phases ?? [])
                .filter { $0.scheduleEnabled && $0.scheduledDays.contains(weekday) }
                .map { $0.endHour * 60 + $0.endMinute }
                .max() ?? (routine.startHour * 60 + routine.startMinute + routine.durationMinutes)
            var comps = calendar.dateComponents([.year, .month, .day], from: startDate)
            comps.hour = latestEnd / 60
            comps.minute = latestEnd % 60
            comps.second = 0
            endDate = calendar.date(from: comps) ?? startDate.addingTimeInterval(TimeInterval(routine.durationMinutes * 60))
        } else {
            endDate = startDate.addingTimeInterval(TimeInterval(routine.durationMinutes * 60))
        }

        let next24Hours = now.addingTimeInterval(24 * 60 * 60)

        let isDueNow = isRoutineDueNow(startDate: startDate, endDate: endDate, now: now)
        let isSoon = isRoutineSoon(startDate: startDate, now: now, limit: next24Hours)
        let isScheduledTodayIncomplete = Calendar.current.isDateInToday(startDate)
            && !routine.allTasksDone
            && startDate <= now

        guard isDueNow || isSoon || isScheduledTodayIncomplete else {
            return nil
        }

        // Hide completed routines for today
        if Calendar.current.isDateInToday(startDate) && routine.allTasksDone {
            return nil
        }

        let status: LureliaWidgetRoutineStatus =
            (isDueNow || isScheduledTodayIncomplete) ? .dueNow : .soon

        let nextPhase = nextPhase(for: routine, now: now)

        return LureliaWidgetRoutineItem(
            id: routine.persistentID,
            name: routine.name,
            icon: routine.icon.isEmpty ? "sparkle" : routine.icon,
            colorHex: routine.colorHex.isEmpty ? "#7d19f7" : routine.colorHex,
            timeRange: widgetTimeRange(startDate: startDate, endDate: endDate),
            status: status,
            phaseID: nextPhase?.persistentID,
            phaseName: cleanedPhaseName(nextPhase),
            isDone: routine.allTasksDone
        )
    }

    private func isRoutineDueNow(
        startDate: Date,
        endDate: Date,
        now: Date
    ) -> Bool {
        startDate <= now && endDate >= now
    }

    private func isRoutineSoon(
        startDate: Date,
        now: Date,
        limit: Date
    ) -> Bool {
        startDate > now && startDate <= limit
    }

    private func nextRoutineStartDate(
        for routine: LureliaRoutine,
        now: Date
    ) -> Date? {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: now)

        // Phase-based: check if any phase is scheduled for today
        if routine.phasesEnabled {
            let todayPhases = (routine.phases ?? [])
                .filter { $0.scheduleEnabled && $0.scheduledDays.contains(todayWeekday) }
                .sorted { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute }

            if let earliest = todayPhases.first {
                var comps = calendar.dateComponents([.year, .month, .day], from: now)
                comps.hour = earliest.startHour
                comps.minute = earliest.startMinute
                comps.second = 0
                return calendar.date(from: comps)
            }

            // Check future days across all phases
            let startOfToday = calendar.startOfDay(for: now)
            for offset in 1...7 {
                guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
                let weekday = calendar.component(.weekday, from: candidateDay)
                let matchingPhases = (routine.phases ?? [])
                    .filter { $0.scheduleEnabled && $0.scheduledDays.contains(weekday) }
                    .sorted { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute }
                if let earliest = matchingPhases.first {
                    var comps = calendar.dateComponents([.year, .month, .day], from: candidateDay)
                    comps.hour = earliest.startHour
                    comps.minute = earliest.startMinute
                    comps.second = 0
                    return calendar.date(from: comps)
                }
            }
            return nil
        }

        // Routine-level schedule
        if routine.scheduledDays.contains(todayWeekday) {
            return routineDate(
                for: routine,
                dayOffset: 0,
                now: now,
                calendar: calendar
            )
        }

        let startOfToday = calendar.startOfDay(for: now)

        for offset in 1...7 {
            guard let candidateDay = calendar.date(
                byAdding: .day,
                value: offset,
                to: startOfToday
            ) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: candidateDay)

            guard routine.scheduledDays.contains(weekday) else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            components.hour = routine.startHour
            components.minute = routine.startMinute
            components.second = 0

            return calendar.date(from: components)
        }

        return nil
    }

    private func routineDate(
        for routine: LureliaRoutine,
        dayOffset: Int,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let baseDay = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: now)
        ) ?? now

        var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
        components.hour = routine.startHour
        components.minute = routine.startMinute
        components.second = 0

        return calendar.date(from: components) ?? now
    }

    private func widgetTimeRange(startDate: Date, endDate: Date) -> String {
        "\(compactTime(startDate)) \u{2013} \(compactTime(endDate))"
    }

    private func compactTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let isPM = hour >= 12
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let meridiem = isPM ? "PM" : "AM"

        if minute == 0 {
            return "\(displayHour)\(meridiem)"
        } else {
            return "\(displayHour):\(String(format: "%02d", minute))\(meridiem)"
        }
    }
    
    private func nextPhase(
        for routine: LureliaRoutine,
        now: Date
    ) -> LureliaRoutinePhase? {
        guard routine.phasesEnabled else { return nil }

        let phases = routine.sortedPhases
        guard !phases.isEmpty else { return nil }

        return phases.first { phase in
            routine.tasksForPhase(phase).contains { $0.isPending }
        }
    }

    private func cleanedPhaseName(_ phase: LureliaRoutinePhase?) -> String? {
        let cleanedName = phase?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleanedName.isEmpty ? nil : cleanedName
    }

    private func phaseDate(
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components) ?? now
    }
}

struct LureliaDueRoutinesWidgetView: View {
    let entry: LureliaDueRoutinesEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            
            if entry.routines.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(entry.routines.prefix(5)) { routine in
                        routineRow(routine)
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
            if let uiImage = LureliaWidgetShared.widgetIcon(for: "repeatfill") {
                Color.white
                    .mask(
                        Image(uiImage: uiImage)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                    )
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "arrow.clockwise")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white)
            }
            
            Text("My Routines")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
    
    private var emptyState: some View {
        Text("No routines scheduled")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }
    
    private func routineRow(_ routine: LureliaWidgetRoutineItem) -> some View {
        let routineTint = Color(widgetHex: routine.colorHex)

        return HStack(alignment: .top, spacing: 10) {
            widgetIcon(routine.icon, tint: routineTint, size: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                // Row 1: Name • Status
                HStack(spacing: 5) {
                    Text(routine.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("•")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))

                    routineStatusBadge(routine.status, tint: routineTint)
                }

                // Row 2: Phase • Time
                HStack(spacing: 5) {
                    if let phaseName = routine.phaseName {
                        Text(phaseName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                    }

                    Text(routine.timeRange)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button(intent: CompleteRoutineWidgetIntent(routineID: routine.id, phaseID: routine.phaseID)) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 22, height: 22)

                    Circle()
                        .strokeBorder(routineTint, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if routine.isDone {
                        Circle()
                            .fill(routineTint)
                            .frame(width: 12, height: 12)
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(routineTint.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(routineTint.opacity(0.4), lineWidth: 1)
        )
    }

    private func routineStatusBadge(
        _ status: LureliaWidgetRoutineStatus,
        tint: Color
    ) -> some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        status == .dueNow
                        ? tint.opacity(0.95)
                        : Color.white.opacity(0.16)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        status == .dueNow
                        ? Color.white.opacity(0.28)
                        : tint.opacity(0.65),
                        lineWidth: 1
                    )
            )
    }

    @ViewBuilder
    private func widgetIcon(_ name: String, tint: Color, size: CGFloat) -> some View {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconName = trimmedName.isEmpty ? "sparkle" : trimmedName
        
        if let uiImage = LureliaWidgetShared.widgetIcon(for: iconName) {
            tint
                .mask(
                    Image(uiImage: uiImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                )
                .frame(width: size, height: size)
        } else {
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(tint)
        }
    }
}

// Color Hex Extension Helper local scope fallback
extension Color {
    init(widgetHex: String) {
        let hex = widgetHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct LureliaDueRoutinesWidget: Widget {
    let kind = "LureliaDueRoutinesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: LureliaDueRoutinesProvider()
        ) { entry in
            LureliaDueRoutinesWidgetView(entry: entry)
        }
        .configurationDisplayName("Routines Dashboard")
        .description("Track and complete your active routines quickly.")
        .supportedFamilies([.systemLarge])
    }
}
