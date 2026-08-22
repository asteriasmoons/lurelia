//
//  CalendarView.swift
//  Lurelia
//

import SwiftUI

struct CalendarView: View {
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    @State private var displayedMonth: Date = Date()

    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        currentMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        calendar.shortStandaloneWeekdaySymbols.map { String($0.prefix(1)) }
    }

    private var days: [CalendarDayBubble] {
        makeDays(for: currentMonthStart)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                header

                dayGrid
            }
        }
        .padding(.horizontal, 20)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Calendar")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Text(monthTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            headerControls
        }
    }

    private var headerControls: some View {
        HStack(spacing: 10) {
            Button {
                moveMonth(-1)
            } label: {
                Image("chevleft")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.90))
                    .frame(width: 16, height: 16)
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    displayedMonth = Date()
                }
            } label: {
                Text("Today")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
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

            Button {
                moveMonth(1)
            } label: {
                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.90))
                    .frame(width: 16, height: 16)
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
    }

    private var dayGrid: some View {
        calendarGridContent
    }

    private var calendarGridContent: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }

            ForEach(days) { day in
                dayBubble(day)
            }
        }
    }

    private func dayBubble(_ day: CalendarDayBubble) -> some View {
        ZStack {
            Circle()
                .fill(dayCircleFill(for: day))
                .overlay {
                    Circle()
                        .strokeBorder(dayCircleStroke(for: day), lineWidth: day.isToday ? 1.2 : 1)
                }

            Text(day.numberText)
                .font(.system(size: 13, weight: day.isToday ? .black : .bold, design: .rounded))
                .foregroundStyle(dayForeground(for: day))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .opacity(day.isCurrentMonth ? 1 : 0.35)
    }

    private func dayForeground(for day: CalendarDayBubble) -> Color {
        if day.isToday { return .white }
        return day.isCurrentMonth ? LColors.textPrimary : LColors.textSecondary
    }

    private func dayCircleFill(for day: CalendarDayBubble) -> AnyShapeStyle {
        if day.isToday {
            return AnyShapeStyle(LColors.neutralGlassHighlight.opacity(0.065))
        }
        return AnyShapeStyle(LColors.neutralGlassHighlight.opacity(day.isCurrentMonth ? 0.035 : 0.02))
    }

    private func dayCircleStroke(for day: CalendarDayBubble) -> AnyShapeStyle {
        if day.isToday {
            return AnyShapeStyle(LColors.neutralPearl.opacity(0.68))
        }
        return AnyShapeStyle(LColors.neutralGlassHighlight.opacity(day.isCurrentMonth ? 0.16 : 0.08))
    }

    private func moveMonth(_ value: Int) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        }
    }

    private func makeDays(for monthStart: Date) -> [CalendarDayBubble] {
        guard calendar.range(of: .day, in: .month, for: monthStart) != nil,
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthStart)
        else { return [] }

        let firstDisplayDate = firstWeek.start

        let monthDates: [Date] = (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstDisplayDate)
        }

        return monthDates.map { date in
            let day = calendar.component(.day, from: date)
            let isCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
            let isToday = calendar.isDateInToday(date)

            return CalendarDayBubble(
                date: date,
                numberText: "\(day)",
                isCurrentMonth: isCurrentMonth,
                isToday: isToday
            )
        }
    }
}

private struct CalendarDayBubble: Identifiable {
    let date: Date
    let numberText: String
    let isCurrentMonth: Bool
    let isToday: Bool

    var id: Date { date }
}

#Preview {
    ZStack {
        LureliaBackgroundAlt()
        CalendarView()
    }
}
