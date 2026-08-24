//
//  LureliaWeekScheduleView.swift
//  Lurelia
//

import SwiftUI

struct LureliaWeekScheduleView: View {
    @Binding var focusedDate: Date
    let localOccurrences: [LureliaEventOccurrence]
    let externalOccurrences: [LureliaExternalCalendarOccurrence]
    let events: [LureliaEvent]
    let onSelect: (LureliaEventUnifiedOccurrence) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveWeek(-1) } label: {
                    Image("chevleft")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(weekTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button { moveWeek(1) } label: {
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

            VStack(spacing: 12) {
                ForEach(weekDays, id: \.self) { day in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)

                                Spacer()

                                Text("\(rows(on: day).count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.85).opacity(0.14), in: Capsule())
                            }

                            let dayRows = rows(on: day)
                            if dayRows.isEmpty {
                                Text("No events")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 7)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(dayRows) { row in
                                        LureliaEventOccurrenceRow(
                                            row: row,
                                            onSelect: onSelect,
                                            style: .frosty
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var weekDays: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: focusedDate) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    private var weekTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "This Week" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) - \(last.formatted(.dateTime.month(.abbreviated).day()))"
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

    private func moveWeek(_ value: Int) {
        focusedDate = calendar.date(byAdding: .weekOfYear, value: value, to: focusedDate) ?? focusedDate
    }
}
