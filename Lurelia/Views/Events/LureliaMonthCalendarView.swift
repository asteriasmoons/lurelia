//
//  LureliaMonthCalendarView.swift
//  Lurelia
//

import SwiftUI

struct LureliaMonthCalendarView: View {
    @Binding var focusedDate: Date
    let localOccurrences: [LureliaEventOccurrence]
    let externalOccurrences: [LureliaExternalCalendarOccurrence]
    let events: [LureliaEvent]
    let onSelect: (LureliaEventUnifiedOccurrence) -> Void

    @State private var selectedDay = Date()
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image("chevleft")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(focusedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button { moveMonth(1) } label: {
                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Self.weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDays, id: \.self) { day in
                    monthDayCell(day)
                }
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                let rows = rows(on: selectedDay)
                if rows.isEmpty {
                    LureliaEventsEmptyState(title: "No Events", subtitle: "Nothing is scheduled for this day.")
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(rows) { row in
                            LureliaEventOccurrenceRow(row: row, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private static let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: focusedDate),
              let monthRange = calendar.range(of: .day, in: .month, for: focusedDate)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingSlots = max(0, firstWeekday - 1)
        var days: [Date] = []

        for offset in stride(from: leadingSlots, to: 0, by: -1) {
            if let day = calendar.date(byAdding: .day, value: -offset, to: monthInterval.start) {
                days.append(day)
            }
        }

        for dayNumber in monthRange {
            if let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthInterval.start) {
                days.append(day)
            }
        }

        while days.count % 7 != 0 {
            if let last = days.last,
               let next = calendar.date(byAdding: .day, value: 1, to: last) {
                days.append(next)
            } else {
                break
            }
        }

        return days
    }

    private func monthDayCell(_ day: Date) -> some View {
        let isCurrentMonth = calendar.isDate(day, equalTo: focusedDate, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let dayRows = rows(on: day)

        return Button {
            selectedDay = day
            focusedDate = day
        } label: {
            GlassCard(cornerRadius: 14, padding: 7) {
                VStack(spacing: 5) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isCurrentMonth ? .white : LColors.textSecondary.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 3) {
                        ForEach(dayRows.prefix(3)) { row in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(row.color.opacity(row.isApple ? 0.55 : 0.9))
                                .frame(height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 19, alignment: .top)
                }
                .frame(height: 50)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func rows(on day: Date) -> [LureliaEventUnifiedOccurrence] {
        let local = localOccurrences
            .map { LureliaEventUnifiedOccurrence.local($0) }
        let external = externalOccurrences
            .map { LureliaEventUnifiedOccurrence.apple($0) }
        return LureliaEventUnifiedOccurrence.deduplicated(local + external)
            .filter { $0.occurs(on: day, calendar: calendar) }
            .sorted { $0.start < $1.start }
    }

    private func moveMonth(_ value: Int) {
        focusedDate = calendar.date(byAdding: .month, value: value, to: focusedDate) ?? focusedDate
        selectedDay = focusedDate
    }
}
