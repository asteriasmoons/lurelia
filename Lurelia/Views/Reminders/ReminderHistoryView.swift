//
//  ReminderHistoryView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaReminderHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate = Date()
    @State private var visibleMonth = Date()

    @Query(sort: \LureliaReminderHistory.occurrenceDate, order: .reverse)
    private var historyEntries: [LureliaReminderHistory]

    private var selectedDayEntries: [LureliaReminderHistory] {
        let cal = Calendar.current
        return historyEntries
            .filter { cal.isDate($0.occurrenceDate, inSameDayAs: selectedDate) }
            .sorted { $0.occurrenceDate < $1.occurrenceDate }
    }

    private var visibleMonthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var calendarDays: [Date?] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: visibleMonth),
              let firstWeek = cal.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = cal.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1)) else {
            return []
        }

        var days: [Date?] = []
        var current = firstWeek.start

        while current < lastWeek.end {
            if cal.isDate(current, equalTo: visibleMonth, toGranularity: .month) {
                days.append(current)
            } else {
                days.append(nil)
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return days
    }

    private var weekdaySymbols: [String] {
        Calendar.current.shortStandaloneWeekdaySymbols.map { String($0.prefix(1)) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            calendarCard

                            if selectedDayEntries.isEmpty {
                                emptyState
                                    .padding(.top, 34)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(selectedDayEntries) { entry in
                                        historyRow(entry)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Reminder History")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var calendarCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        moveMonth(-1)
                    } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(visibleMonthTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        moveMonth(1)
                    } label: {
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                    spacing: 8
                ) {
                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            calendarDayButton(day)
                        } else {
                            Color.clear
                                .frame(height: 34)
                        }
                    }
                }
            }
        }
    }

    private func calendarDayButton(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)
        let dayHasEntries = historyEntries.contains { cal.isDate($0.occurrenceDate, inSameDayAs: day) }

        return Button {
            selectedDate = day
        } label: {
            ZStack(alignment: .bottom) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? LColors.bg : .white.opacity(isToday ? 1 : 0.78))
                    .frame(width: 34, height: 34)
                    .background(
                        isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.06)),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isToday && !isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear),
                                lineWidth: 1.2
                            )
                    }

                if dayHasEntries {
                    Circle()
                        .fill(isSelected ? LColors.bg.opacity(0.85) : Color.white.opacity(0.85))
                        .frame(width: 4, height: 4)
                        .offset(y: -3)
                }
            }
            .frame(height: 38)
        }
        .buttonStyle(.plain)
    }

    private func moveMonth(_ value: Int) {
        let cal = Calendar.current
        if let newMonth = cal.date(byAdding: .month, value: value, to: visibleMonth) {
            visibleMonth = newMonth
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("timebook")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 56, height: 56)

            Text("No History This Day")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Completed and skipped reminder occurrences for the selected day will appear here.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func historyRow(_ entry: LureliaReminderHistory) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.10))

                    Circle()
                        .strokeBorder(LGradients.header, lineWidth: 1.4)

                    Image(entry.reminderIcon.isEmpty ? "bellfill" : entry.reminderIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .padding(9)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.reminderTitle.isEmpty ? "Reminder" : entry.reminderTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(entry.occurrenceDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.85))

                        Text(entry.occurrenceDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                Spacer()

                Text(entry.action.rawValue)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(LGradients.header.opacity(0.13), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(LGradients.header, lineWidth: 1)
                    }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                deleteHistoryEntry(entry)
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }

    private func deleteHistoryEntry(_ entry: LureliaReminderHistory) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}
