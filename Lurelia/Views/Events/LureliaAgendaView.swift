//
//  LureliaAgendaView.swift
//  Lurelia
//
//  Agenda tab — matches the Kanban Timeline layout: a GlassCard with the
//  week strip (chev left / date range / chev right, then 7 day tiles)
//  above the selected day's header and its scheduled event rows.
//

import SwiftUI

struct LureliaAgendaView: View {
    @Binding var focusedDate: Date

    let interval: DateInterval
    let localOccurrences: [LureliaEventOccurrence]
    let externalOccurrences: [LureliaExternalCalendarOccurrence]
    let events: [LureliaEvent]
    let onSelect: (LureliaEventUnifiedOccurrence) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 16) {
            weekRow
            selectedDayHeader
            eventsList
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Week strip

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: focusedDate)?.start
            ?? calendar.startOfDay(for: focusedDate)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    private var weekRangeText: String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return focusedDate.formatted(date: .abbreviated, time: .omitted)
        }
        let startText = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) - \(endText)"
    }

    private var weekRow: some View {
        GlassCard(cornerRadius: 24, padding: 12) {
            VStack(spacing: 10) {
                HStack {
                    Button { moveWeek(by: -1) } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(weekRangeText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))

                    Spacer()

                    Button { moveWeek(by: 1) } label: {
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }

                weekDayPicker
            }
        }
    }

    private var weekDayPicker: some View {
        weekDayButtons
    }

    private var weekDayButtons: some View {
        HStack(spacing: 7) {
            ForEach(weekDays, id: \.self) { day in
                dayButton(day)
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: focusedDate)
        let isToday = calendar.isDateInToday(day)

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                focusedDate = day
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LColors.neutralGlassHighlight.opacity(0.055))

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(LGradients.header.opacity(0.52), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LColors.neutralGlassHighlight.opacity(0.035))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(LColors.neutralGlassHighlight.opacity(0.14), lineWidth: 1)
                        }
                }

                VStack(spacing: 5) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.56))

                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.80))

                    Circle()
                        .fill(isToday ? AnyShapeStyle(LColors.neutralPearl.opacity(0.82)) : AnyShapeStyle(Color.clear))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }

    private func moveWeek(by value: Int) {
        guard let newDay = calendar.date(byAdding: .weekOfYear, value: value, to: focusedDate) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            focusedDate = newDay
        }
    }

    // MARK: - Selected day header

    private var selectedDayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(focusedDate.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(todayRows.count) item\(todayRows.count == 1 ? "" : "s") scheduled")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    focusedDate = Date()
                }
            } label: {
                Text("Today")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .fixedSize(horizontal: true, vertical: false)
                    .background {
                        Capsule(style: .continuous)
                            .fill(LColors.neutralGlassHighlight.opacity(0.045))
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(LColors.neutralGlassHighlight.opacity(0.22), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Timeline

    /// A single time bucket in the vertical timeline. `label` is what appears
    /// next to the rail marker ("All Day", "8:00 AM", "9:00 AM"…). `sortKey`
    /// is used to order buckets chronologically; all-day rows always sort
    /// first via `.distantPast`.
    private struct TimeGroup: Identifiable {
        let id: String
        let label: String
        let sortKey: Date
        let rows: [LureliaEventUnifiedOccurrence]
    }

    private var eventsList: some View {
        Group {
            if todayRows.isEmpty {
                LureliaEventsEmptyState(
                    title: "No Events",
                    subtitle: "Nothing is scheduled for this day."
                )
            } else {
                timeline
            }
        }
    }

    private var timeline: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(width: 2)
                .padding(.leading, 18)
                .padding(.top, 8)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(groupedRows) { group in
                    timelineMarker(title: group.label)

                    ForEach(group.rows) { row in
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: 48)

                            LureliaEventOccurrenceRow(row: row, onSelect: onSelect)
                        }
                    }
                }
            }
        }
    }

    private func timelineMarker(title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LColors.neutralPearl.opacity(0.78))
                    .frame(width: 14, height: 14)

                Circle()
                    .strokeBorder(LColors.neutralPearl.opacity(0.32), lineWidth: 1)
                    .frame(width: 14, height: 14)
            }
            .frame(width: 38)

            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .tracking(0.4)

            Spacer()
        }
    }

    private var groupedRows: [TimeGroup] {
        let rows = todayRows
        let allDay = rows.filter { $0.isAllDay }
        let timed = rows.filter { !$0.isAllDay }

        var groups: [TimeGroup] = []

        if !allDay.isEmpty {
            groups.append(
                TimeGroup(
                    id: "all-day",
                    label: "All Day",
                    sortKey: .distantPast,
                    rows: allDay.sorted { $0.title < $1.title }
                )
            )
        }

        let bucketedTimed = Dictionary(grouping: timed) { row -> String in
            row.start.formatted(date: .omitted, time: .shortened)
        }

        for (label, bucketRows) in bucketedTimed {
            let sorted = bucketRows.sorted { $0.start < $1.start }
            groups.append(
                TimeGroup(
                    id: label,
                    label: label,
                    sortKey: sorted.first?.start ?? .distantFuture,
                    rows: sorted
                )
            )
        }

        return groups.sorted { $0.sortKey < $1.sortKey }
    }

    private var todayRows: [LureliaEventUnifiedOccurrence] {
        let local = localOccurrences
            .filter { rowMatchesFocusedDay(start: $0.start, end: $0.end) }
            .map { LureliaEventUnifiedOccurrence.local($0) }
        let external = externalOccurrences
            .filter { rowMatchesFocusedDay(start: $0.start, end: $0.end) }
            .map { LureliaEventUnifiedOccurrence.apple($0) }
        return (local + external).sorted { $0.start < $1.start }
    }

    private func rowMatchesFocusedDay(start: Date, end: Date) -> Bool {
        if calendar.isDate(start, inSameDayAs: focusedDate) { return true }
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(60))).contains(focusedDate)
    }
}
