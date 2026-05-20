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
        VStack(alignment: .leading, spacing: 16) {
            header

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
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                            lineWidth: 1.4
                        )
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

            HStack(spacing: 10) {
                Button {
                    moveMonth(-1)
                } label: {
                    Image("chevleft")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LColors.textPrimary)
                        .frame(width: 14, height: 14)
                        .frame(width: 34, height: 34)
                        .background(LColors.glassSurface2, in: Circle())
                        .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        displayedMonth = Date()
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(LGradients.header))
                }
                .buttonStyle(.plain)

                Button {
                    moveMonth(1)
                } label: {
                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LColors.textPrimary)
                        .frame(width: 14, height: 14)
                        .frame(width: 34, height: 34)
                        .background(LColors.glassSurface2, in: Circle())
                        .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayBubble(_ day: CalendarDayBubble) -> some View {
        Text(day.numberText)
            .font(.system(size: 13, weight: day.isToday ? .black : .bold, design: .rounded))
            .foregroundStyle(dayForeground(for: day))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background {
                Circle()
                    .fill(day.isToday ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LColors.glassSurface2.opacity(day.isCurrentMonth ? 0.95 : 0.35)))
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        day.isToday ? .white.opacity(0.35) : LColors.glassBorder.opacity(day.isCurrentMonth ? 0.85 : 0.35),
                        lineWidth: 1
                    )
            }
            .opacity(day.isCurrentMonth ? 1 : 0.35)
    }

    private func dayForeground(for day: CalendarDayBubble) -> Color {
        if day.isToday { return .white }
        return day.isCurrentMonth ? LColors.textPrimary : LColors.textSecondary
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
        LureliaBackground()
        CalendarView()
    }
}
