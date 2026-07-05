//
//  KanbanTimelineView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Kanban Timeline View

struct KanbanTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \KanbanBoard.sortOrder)
    private var boards: [KanbanBoard]

    @Query private var allReminders: [LureliaReminder]

    @State private var selectedBoardID: UUID?
    @State private var selectedDay: Date = Date()
    @State private var showCreateBoard = false
    @State private var showAddColumn = false
    @State private var editingColumn: KanbanColumn?
    @State private var createRequest: KanbanCreateRequest?
    @State private var showCompletionBanner = false

    private var calendar: Calendar { .current }

    private var selectedBoard: KanbanBoard? {
        if let selectedBoardID,
           let board = boards.first(where: { $0.id == selectedBoardID }) {
            return board
        }

        return boards.first
    }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start
        ?? calendar.startOfDay(for: selectedDay)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    private var selectedDayTitle: String {
        selectedDay.formatted(date: .complete, time: .omitted)
    }

    private var selectedBoardAccent: Color {
        Color(lureliaHex: selectedBoard?.colorHex ?? "#03dbfc")
    }

    private var pinnedReminderIDs: Set<String> {
        let cards = boards
            .flatMap { $0.columns ?? [] }
            .flatMap { $0.cards ?? [] }
            .filter { $0.cardType == .reminder }

        return Set(cards.map { $0.itemID })
    }

    private var selectedDayStandaloneReminders: [LureliaReminder] {
        allReminders
            .filter { reminder in
                reminder.kind == .standalone &&
                reminder.isDue(on: selectedDay, calendar: calendar)
            }
            .sorted {
                let left = fireDates(for: $0, on: selectedDay).first ?? $0.nextFireAt ?? $0.scheduledDate
                let right = fireDates(for: $1, on: selectedDay).first ?? $1.nextFireAt ?? $1.scheduledDate
                return left < right
            }
    }

    private var inboxReminders: [LureliaReminder] {
        selectedDayStandaloneReminders
            .filter { !pinnedReminderIDs.contains($0.id.uuidString) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()

                VStack(spacing: 0) {

                    // MARK: - Header

                    HStack {
                        Text("Kanban Timeline")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        HStack(spacing: 14) {
                            Button {
                                showAddColumn = true
                            } label: {
                                Image("addwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(LGradients.header)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedBoard == nil)
                            .opacity(selectedBoard == nil ? 0.35 : 1)

                            Button {
                                dismiss()
                            } label: {
                                Image("xmarkwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(LGradients.header)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 59)
                    .padding(.bottom, 12)

                    // MARK: - Board Picker

                    boardPicker
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    // MARK: - Week Row

                    weekRow
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    if let board = selectedBoard {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 16) {

                                selectedDayHeader

                                ZStack(alignment: .topLeading) {

                                    Rectangle()
                                        .fill(.white.opacity(0.16))
                                        .frame(width: 2)
                                        .padding(.leading, 18)
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)

                                    VStack(alignment: .leading, spacing: 16) {

                                        timelineMarker(title: "Inbox")

                                        if !inboxReminders.isEmpty {
                                            KanbanTimelineInboxColumnView(
                                                board: board,
                                                reminders: inboxReminders,
                                                selectedDay: selectedDay,
                                                boardAccent: selectedBoardAccent,
                                                onMoveReminder: { reminder, column in
                                                    pinCard(type: .reminder, itemID: reminder.id.uuidString, in: column)
                                                }
                                            )
                                            .padding(.leading, 48)
                                        }

                                        if board.sortedColumns.isEmpty {
                                            emptyColumnsState(board: board)
                                                .padding(.leading, 48)
                                        } else if timelineColumnOccurrences.isEmpty {
                                            Text("No reminders left for this day.")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.45))
                                                .padding(.leading, 48)
                                                .padding(.vertical, 20)
                                        } else {
                                            ForEach(timelineColumnOccurrences) { occurrence in
                                                timelineMarker(title: occurrence.fireDate.formatted(date: .omitted, time: .shortened))

                                                KanbanTimelineColumnView(
                                                    column: occurrence.column,
                                                    selectedDay: selectedDay,
                                                    forcedFireDate: occurrence.fireDate,
                                                    allReminders: selectedDayStandaloneReminders,
                                                    onAddCard: {
                                                        createRequest = KanbanCreateRequest(type: .reminder, column: occurrence.column)
                                                    },
                                                    onEditColumn: {
                                                        editingColumn = occurrence.column
                                                    },
                                                    onComplete: {
                                                        triggerBanner()
                                                    }
                                                )
                                                .padding(.leading, 48)
                                            }
                                        }

                                        Button {
                                            showAddColumn = true
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image("addwavy")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 20, height: 20)
                                                    .foregroundStyle(LGradients.header)

                                                Text("Add Column")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundStyle(LColors.textSecondary)

                                                Spacer()
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 18)
                                            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 48)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 140)
                        }
                    } else {
                        noBoardsState
                            .padding(.horizontal, 24)
                            .padding(.top, 30)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .completionBanner(isShowing: showCompletionBanner, message: "Reminder completed!")
            .onAppear {
                if selectedBoardID == nil {
                    selectedBoardID = boards.first?.id
                }
            }
            .onChange(of: boards.map(\.id)) { _, ids in
                if selectedBoardID == nil {
                    selectedBoardID = ids.first
                } else if let selectedBoardID, !ids.contains(selectedBoardID) {
                    self.selectedBoardID = ids.first
                }
            }
            .sheet(isPresented: $showCreateBoard) {
                KanbanTimelineCreateBoardSheet()
            }
            .sheet(isPresented: $showAddColumn) {
                if let selectedBoard {
                    KanbanTimelineColumnSheet(board: selectedBoard)
                }
            }
            .sheet(item: $editingColumn) { column in
                if let selectedBoard {
                    KanbanTimelineColumnSheet(board: selectedBoard, column: column)
                }
            }
            .sheet(item: $createRequest) { request in
                AddReminderView(onCreated: { reminder in
                    reminder.kind = .standalone
                    pinCard(type: .reminder, itemID: reminder.id.uuidString, in: request.column)
                })
            }
            .navigationDestination(for: UUID.self) { reminderID in
                if let reminder = allReminders.first(where: { $0.id == reminderID }) {
                    ReminderDetailView(reminder: reminder)
                }
            }
        }
    }

    // MARK: - Board Picker

    private var boardPicker: some View {
        Menu {
            ForEach(boards) { board in
                Button {
                    selectedBoardID = board.id
                } label: {
                    HStack {
                        if selectedBoardID == board.id {
                            Image("checkwavy")
                                .renderingMode(.template)
                        } else {
                            Image("circle")
                        }

                        Text(board.name)
                    }
                }
            }

            if !boards.isEmpty {
                Divider()
            }

            Button {
                showCreateBoard = true
            } label: {
                HStack {
                    Image("addwavy")
                        .renderingMode(.template)

                    Text("Create New Board")
                }
            }
        } label: {
            GlassCard(cornerRadius: 22, padding: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(selectedBoardAccent.opacity(0.14))
                            .frame(width: 38, height: 38)

                        if let selectedBoard {
                            Image(selectedBoard.icon)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 19, height: 19)
                                .foregroundStyle(selectedBoardAccent)
                        } else {
                            Image("starcal")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 19, height: 19)
                                .foregroundStyle(LGradients.header)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("BOARD")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(0.6)

                        Text(selectedBoard?.name ?? "Choose a Board")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image("chevdown")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Row

    private var weekRow: some View {
        GlassCard(cornerRadius: 24, padding: 12) {
            VStack(spacing: 10) {
                HStack {
                    Button {
                        moveWeek(by: -1)
                    } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(weekRangeText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))

                    Spacer()

                    Button {
                        moveWeek(by: 1)
                    } label: {
                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LGradients.header)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 7) {
                    ForEach(weekDays, id: \.self) { day in
                        dayButton(day)
                    }
                }
            }
        }
    }
    
    private func timelineMarker(title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LGradients.header)
                    .frame(width: 14, height: 14)

                Circle()
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
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
    
    private func timelineMarkerTitle(for column: KanbanColumn) -> String {
        guard let date = earliestVisibleFireDate(in: column) else {
            return column.name
        }

        return date.formatted(date: .omitted, time: .shortened)
    }
    
    private var timelineStartForSelectedDay: Date {
        calendar.startOfDay(for: selectedDay)
    }
    
    private var timelineEndForSelectedDay: Date {
        let start = calendar.startOfDay(for: selectedDay)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? selectedDay
    }

    private func hasVisibleFireDate(_ reminder: LureliaReminder) -> Bool {
        fireDates(for: reminder, on: selectedDay).contains { fireDate in
            fireDate >= timelineStartForSelectedDay &&
            fireDate < timelineEndForSelectedDay
        }
    }

    private func earliestVisibleFireDate(in column: KanbanColumn) -> Date? {
        var dates: [Date] = []

        for card in column.sortedCards {
            guard card.cardType == .reminder,
                  let reminder = selectedDayStandaloneReminders.first(where: { $0.id.uuidString == card.itemID })
            else {
                continue
            }

            let validDates = fireDates(for: reminder, on: selectedDay).filter { fireDate in
                fireDate >= timelineStartForSelectedDay
            }

            dates.append(contentsOf: validDates)
        }

        return dates.min()
    }

    private var timelineColumns: [KanbanColumn] {
        guard let board = selectedBoard else { return [] }

        let remainingColumns = board.sortedColumns.filter { column in
            earliestVisibleFireDate(in: column) != nil
        }

        return remainingColumns.sorted { left, right in
            let leftDate = earliestVisibleFireDate(in: left) ?? .distantFuture
            let rightDate = earliestVisibleFireDate(in: right) ?? .distantFuture

            if leftDate != rightDate {
                return leftDate < rightDate
            }

            return left.sortOrder < right.sortOrder
        }
    }

    private var weekRangeText: String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return selectedDay.formatted(date: .abbreviated, time: .omitted)
        }

        let startText = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) - \(endText)"
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 5) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.45))

                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.82))

                Circle()
                    .fill(isToday ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LGradients.header)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.06))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func moveWeek(by value: Int) {
        guard let newDay = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDay) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selectedDay = newDay
        }
    }

    // MARK: - Selected Day Header

    private var selectedDayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDayTitle)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(selectedDayStandaloneReminders.count) reminder\(selectedDayStandaloneReminders.count == 1 ? "" : "s") scheduled")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Button {
                selectedDay = Date()
            } label: {
                Text("Today")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.gradientBlue)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(LColors.gradientBlue.opacity(0.13), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(LColors.gradientBlue.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Empty States

    private var noBoardsState: some View {
        VStack(spacing: 18) {
            Image("starcal")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .foregroundStyle(LGradients.header)

            VStack(spacing: 8) {
                Text("No Boards Yet")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Create a board to start organizing reminders by timeline.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button {
                showCreateBoard = true
            } label: {
                Text("Create Board")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LGradients.header)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private func emptyColumnsState(board: KanbanBoard) -> some View {
        VStack(spacing: 14) {
            Image(board.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .foregroundStyle(Color(lureliaHex: board.colorHex))

            Text("No Columns Yet")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Add columns to organize reminders for this day.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)

            Button {
                showAddColumn = true
            } label: {
                Text("Add Column")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LGradients.header)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func triggerBanner() {
        showCompletionBanner = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCompletionBanner = false
        }
    }

    private func pinCard(type: KanbanCardType, itemID: String, in column: KanbanColumn) {
        guard type == .reminder else { return }

        let alreadyExists = (column.cards ?? []).contains {
            $0.cardType == .reminder && $0.itemID == itemID
        }

        guard !alreadyExists else { return }

        let card = KanbanCard(cardType: .reminder, itemID: UUID(), sortOrder: (column.cards ?? []).count)
        card.itemID = itemID

        modelContext.insert(card)

        if column.cards == nil {
            column.cards = []
        }

        column.cards?.append(card)
        column.board?.updatedAt = Date()

        try? modelContext.save()
    }

    private func fireDates(for reminder: LureliaReminder, on day: Date) -> [Date] {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let times = resolvedTimesOfDay(for: reminder)

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

    private func resolvedTimesOfDay(for reminder: LureliaReminder) -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }

        if !stored.isEmpty {
            return stored
        }

        let hour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : calendar.component(.hour, from: reminder.scheduledDate)

        let minute = reminder.primaryMinute != -1
            ? reminder.primaryMinute
            : calendar.component(.minute, from: reminder.scheduledDate)

        var times = [String(format: "%02d:%02d", hour, minute)]

        for fireTime in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
        }

        return times
    }
    
    private var timelineColumnOccurrences: [KanbanTimelineColumnOccurrence] {
        guard let board = selectedBoard else { return [] }

        var occurrences: [KanbanTimelineColumnOccurrence] = []

        for column in board.sortedColumns {
            var fireDatesForColumn: [Date] = []

            for card in column.sortedCards {
                guard card.cardType == .reminder,
                      let reminder = selectedDayStandaloneReminders.first(where: { $0.id.uuidString == card.itemID })
                else {
                    continue
                }

                let dates = fireDates(for: reminder, on: selectedDay).filter { fireDate in
                    if calendar.isDateInToday(selectedDay) {
                        return !reminder.wasCompleted(on: selectedDay, calendar: calendar)
                    }

                    return true
                }

                fireDatesForColumn.append(contentsOf: dates)
            }

            let uniqueDates = Array(Set(fireDatesForColumn)).sorted()

            for fireDate in uniqueDates {
                occurrences.append(
                    KanbanTimelineColumnOccurrence(
                        column: column,
                        fireDate: fireDate
                    )
                )
            }
        }

        return occurrences.sorted { left, right in
            if left.fireDate != right.fireDate {
                return left.fireDate < right.fireDate
            }

            return left.column.sortOrder < right.column.sortOrder
        }
    }
}

// MARK: - Kanban Timeline Occurrence

struct KanbanTimelineOccurrence: Identifiable, Hashable {
    let card: KanbanCard
    let reminder: LureliaReminder
    let fireDate: Date

    var id: String {
        "\(card.id.uuidString)-\(reminder.id.uuidString)-\(fireDate.timeIntervalSince1970)"
    }
}

struct KanbanTimelineColumnOccurrence: Identifiable {
    let column: KanbanColumn
    let fireDate: Date

    var id: String {
        "\(column.id.uuidString)-\(fireDate.timeIntervalSince1970)"
    }
}

// MARK: - Kanban Timeline Column View

struct KanbanTimelineColumnView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var column: KanbanColumn

    let selectedDay: Date
    var forcedFireDate: Date? = nil
    let allReminders: [LureliaReminder]
    let onAddCard: () -> Void
    let onEditColumn: () -> Void
    var onComplete: (() -> Void)? = nil

    private var accentColor: Color {
        Color(lureliaHex: column.colorHex)
    }

    private var visibleOccurrences: [KanbanTimelineOccurrence] {
        var occurrences: [KanbanTimelineOccurrence] = []

        for card in column.sortedCards {
            guard card.cardType == .reminder,
                  let reminder = allReminders.first(where: { $0.id.uuidString == card.itemID })
            else {
                continue
            }

            let fireDates = fireDatesForSelectedDay(reminder).filter { fireDate in
                if let forcedFireDate {
                    return abs(fireDate.timeIntervalSince(forcedFireDate)) < 60
                }

                if Calendar.current.isDateInToday(selectedDay) {
                    return !reminder.wasCompleted(on: selectedDay, calendar: .current)
                }

                return true
            }

            for fireDate in fireDates {
                occurrences.append(
                    KanbanTimelineOccurrence(
                        card: card,
                        reminder: reminder,
                        fireDate: fireDate
                    )
                )
            }
        }

        return occurrences.sorted { left, right in
            if left.fireDate != right.fireDate {
                return left.fireDate < right.fireDate
            }

            return left.card.sortOrder < right.card.sortOrder
        }
    }
    
    private func fireDatesForSelectedDay(_ reminder: LureliaReminder) -> [Date] {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDay)
        let times = resolvedTimesOfDay(for: reminder)

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
    
    private func resolvedTimesOfDay(for reminder: LureliaReminder) -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }

        if !stored.isEmpty {
            return stored
        }

        let calendar = Calendar.current

        let hour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : calendar.component(.hour, from: reminder.scheduledDate)

        let minute = reminder.primaryMinute != -1
            ? reminder.primaryMinute
            : calendar.component(.minute, from: reminder.scheduledDate)

        var times = [String(format: "%02d:%02d", hour, minute)]

        for fireTime in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
        }

        return times
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(column.name)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Spacer()

                Text("\(visibleOccurrences.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.14), in: Capsule())

                Button {
                    onAddCard()
                } label: {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Divider()
                .overlay(LColors.glassBorder)
                .padding(.horizontal, 10)

            VStack(spacing: 10) {
                ForEach(visibleOccurrences) { occurrence in
                    KanbanTimelineOccurrenceCard(
                        occurrence: occurrence,
                        selectedDay: selectedDay,
                        accent: accentColor,
                        onDelete: { deleteCard(occurrence.card) },
                        onComplete: onComplete
                    )
                    .contextMenu {
                        ForEach(availableMoveColumns(for: occurrence.card)) { targetColumn in
                            Button {
                                moveCard(occurrence.card, to: targetColumn)
                            } label: {
                                HStack {
                                    Image("rightwavy")
                                        .renderingMode(.template)

                                    Text("Move to \(targetColumn.name)")
                                }
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteCard(occurrence.card)
                        } label: {
                            HStack {
                                Image("trash")
                                    .renderingMode(.template)

                                Text("Delete Card")
                            }
                        }
                    }
                }

                if visibleOccurrences.isEmpty {
                    VStack(spacing: 8) {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(LColors.textSecondary.opacity(0.4))

                        Text("No reminders for this day")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(accentColor.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            Button {
                onEditColumn()
            } label: {
                HStack {
                    Image("pencil")
                        .renderingMode(.template)

                    Text("Edit Column")
                }
            }

            Divider()

            Button(role: .destructive) {
                deleteColumn()
            } label: {
                HStack {
                    Image("trash")
                        .renderingMode(.template)

                    Text("Delete Column")
                }
            }
        }
    }

    private func deleteCard(_ card: KanbanCard) {
        modelContext.delete(card)
        try? modelContext.save()
    }

    private func deleteColumn() {
        if let cards = column.cards {
            for card in cards {
                modelContext.delete(card)
            }
        }

        modelContext.delete(column)
        try? modelContext.save()
    }

    private func availableMoveColumns(for card: KanbanCard) -> [KanbanColumn] {
        column.board?.sortedColumns.filter { $0.id != column.id } ?? []
    }

    private func moveCard(_ card: KanbanCard, to targetColumn: KanbanColumn) {
        guard targetColumn.id != column.id else { return }

        column.cards = (column.cards ?? []).filter { $0.id != card.id }

        card.sortOrder = (targetColumn.cards ?? []).count

        if targetColumn.cards == nil {
            targetColumn.cards = []
        }

        targetColumn.cards?.append(card)

        for (index, card) in (column.cards ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
            card.sortOrder = index
        }

        for (index, card) in (targetColumn.cards ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
            card.sortOrder = index
        }

        try? modelContext.save()
    }
}

// MARK: - Kanban Timeline Item Card

struct KanbanTimelineItemCard: View {
    let card: KanbanCard
    let selectedDay: Date
    let allReminders: [LureliaReminder]
    let accent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    var body: some View {
        if card.cardType == .reminder,
           let reminder = allReminders.first(where: { $0.id.uuidString == card.itemID }) {
            NavigationLink(value: reminder.id) {
                KanbanTimelineReminderCard(
                    reminder: reminder,
                    selectedDay: selectedDay,
                    accent: accent,
                    onDelete: onDelete,
                    onComplete: onComplete
                )
            }
            .buttonStyle(.plain)
        } else {
            orphanCard
        }
    }

    private var orphanCard: some View {
        HStack(spacing: 10) {
            Image("warnwavy")
                .renderingMode(.template)
                .foregroundStyle(LColors.textSecondary)

            Text("Item deleted")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image("trash")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color(lureliaHex: "#0db7d9"))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Kanban Timeline Occurrence Card

struct KanbanTimelineOccurrenceCard: View {
    let occurrence: KanbanTimelineOccurrence
    let selectedDay: Date
    let accent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    var body: some View {
        NavigationLink(value: occurrence.reminder.id) {
            KanbanTimelineReminderCard(
                reminder: occurrence.reminder,
                selectedDay: selectedDay,
                forcedFireDate: occurrence.fireDate,
                accent: accent,
                onDelete: onDelete,
                onComplete: onComplete
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kanban Timeline Inbox Column

struct KanbanTimelineInboxColumnView: View {
    let board: KanbanBoard
    let reminders: [LureliaReminder]
    let selectedDay: Date
    let boardAccent: Color
    let onMoveReminder: (LureliaReminder, KanbanColumn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image("inbox")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(boardAccent)

                    Text("Inbox")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                }

                Spacer()

                Text("\(reminders.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(boardAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(boardAccent.opacity(0.14), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Divider()
                .overlay(LColors.glassBorder)
                .padding(.horizontal, 10)

            VStack(spacing: 10) {
                ForEach(reminders) { reminder in
                    KanbanTimelineInboxReminderCard(
                        reminder: reminder,
                        selectedDay: selectedDay,
                        accent: boardAccent
                    )
                    .contextMenu {
                        if board.sortedColumns.isEmpty {
                            Label {
                                Text("Add a column first")
                            } icon: {
                                Image("inbox")
                                    .renderingMode(.template)
                            }
                        } else {
                            ForEach(board.sortedColumns) { column in
                                Button {
                                    onMoveReminder(reminder, column)
                                } label: {
                                    HStack {
                                        Image("rightwavy")
                                            .renderingMode(.template)

                                        Text("Move to \(column.name)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(boardAccent.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(boardAccent.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

// MARK: - Timeline Reminder Card

struct KanbanTimelineReminderCard: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var reminder: LureliaReminder
    let selectedDay: Date
    var forcedFireDate: Date? = nil
    let accent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    private var calendar: Calendar { .current }

    private var reminderIcon: String {
        reminder.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bellfill" : reminder.icon
    }

    private var fireDates: [Date] {
        if let forcedFireDate {
            return [forcedFireDate]
        }

        let dayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDay)

        return resolvedTimesOfDay().compactMap { timeString -> Date? in
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

    private var isDoneOnSelectedDay: Bool {
        if let completedAt = reminder.completedAt,
           calendar.isDate(completedAt, inSameDayAs: selectedDay) {
            return true
        }

        return reminder.completionTimestamps.contains {
            calendar.isDate($0, inSameDayAs: selectedDay)
        }
    }

    private func isOverdue(now: Date) -> Bool {
        guard calendar.isDateInToday(selectedDay) else { return false }
        guard !isDoneOnSelectedDay && reminder.isEnabled else { return false }

        let startOfToday = calendar.startOfDay(for: now)
        let nextFire = reminder.nextFireAt ?? reminder.scheduledDate

        return nextFire < startOfToday
    }

    private func isDueNow(now: Date) -> Bool {
        guard calendar.isDateInToday(selectedDay) else { return false }
        guard !isDoneOnSelectedDay && reminder.isEnabled else { return false }

        let nextFire = reminder.nextFireAt ?? reminder.scheduledDate

        if reminder.repeatUnit != .none {
            let startOfToday = calendar.startOfDay(for: now)
            if nextFire < startOfToday { return false }
        }

        return nextFire <= now
    }

    private func isUpcoming(now: Date) -> Bool {
        guard !isDoneOnSelectedDay && reminder.isEnabled else { return false }

        if calendar.isDateInToday(selectedDay) {
            let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
            return nextFire > now && nextFire <= now.addingTimeInterval(24 * 60 * 60)
        }

        guard let firstFire = fireDates.first else { return false }
        return firstFire > now
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date

            cardContent(
                overdue: isOverdue(now: now),
                dueNow: isDueNow(now: now),
                upcoming: isUpcoming(now: now)
            )
        }
    }

    @ViewBuilder
    private func cardContent(overdue: Bool, dueNow: Bool, upcoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 36, height: 36)

                    LureliaIconView(iconId: reminderIcon, size: 19)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(reminder.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(reminder.isEnabled ? LColors.textPrimary : LColors.textSecondary)
                        .lineLimit(2)

                    badgeRow(overdue: overdue, dueNow: dueNow, upcoming: upcoming)
                }

                Spacer(minLength: 8)

                completionCircle
            }

            HStack(alignment: .center, spacing: 8) {
                if let notes = reminder.notes,
                   !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                deleteButton
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LColors.glassSurface2)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                }
        }
        .opacity(reminder.isEnabled ? 1 : 0.65)
    }

    private var completionCircle: some View {
        Button {
            completeReminderOccurrence()
        } label: {
            ZStack {
                Circle()
                    .fill(isDoneOnSelectedDay && reminder.repeatUnit == .none ? accent.opacity(0.18) : Color.clear)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle()
                            .strokeBorder(accent.opacity(0.75), lineWidth: 2)
                    }

                if isDoneOnSelectedDay && reminder.repeatUnit == .none {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(accent)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image("trash")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(Color(lureliaHex: "#0db7d9"))
                .frame(width: 30, height: 30)
                .background(LColors.glassSurface, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(LColors.glassBorder.opacity(0.75), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func badgeRow(overdue: Bool, dueNow: Bool, upcoming: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(Array(fireDates.prefix(2).enumerated()), id: \.offset) { _, date in
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
            }

            if fireDates.count > 2 {
                Text("+\(fireDates.count - 2)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
            }

            if overdue || dueNow || upcoming {
                let label = overdue ? "OVERDUE" : dueNow ? "DUE NOW" : "UPCOMING"
                let color = overdue ? Color(lureliaHex: "#ff9be6") : dueNow ? Color(lureliaHex: "#b476ff") : Color(lureliaHex: "#7eedff")

                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reminder Scheduling Helpers

    private func resolvedTimesOfDay() -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }

        if !stored.isEmpty {
            return stored
        }

        let hour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : calendar.component(.hour, from: reminder.scheduledDate)

        let minute = reminder.primaryMinute != -1
            ? reminder.primaryMinute
            : calendar.component(.minute, from: reminder.scheduledDate)

        var times = [String(format: "%02d:%02d", hour, minute)]

        for fireTime in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
        }

        return times
    }

    // MARK: - Actions

    private func completeReminderOccurrence() {
        Task {
            await ReminderActionManager.completeReminderOccurrence(
                reminder,
                in: modelContext
            )

            await MainActor.run {
                onComplete?()
            }
        }
    }
}

// MARK: - Timeline Inbox Reminder Card

struct KanbanTimelineInboxReminderCard: View {
    let reminder: LureliaReminder
    let selectedDay: Date
    let accent: Color

    private var calendar: Calendar { .current }

    private var reminderIcon: String {
        reminder.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bellfill" : reminder.icon
    }

    private var fireDates: [Date] {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDay)
        let times = resolvedTimesOfDay()

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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 36, height: 36)

                LureliaIconView(iconId: reminderIcon, size: 19)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(reminder.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(reminder.isEnabled ? LColors.textPrimary : LColors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ForEach(Array(fireDates.prefix(2).enumerated()), id: \.offset) { _, date in
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
                    }

                    if fireDates.count > 2 {
                        Text("+\(fireDates.count - 2)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
                    }
                }
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LColors.glassSurface2)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                }
        }
        .opacity(reminder.isEnabled ? 1 : 0.65)
    }

    private func resolvedTimesOfDay() -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }

        if !stored.isEmpty {
            return stored
        }

        let hour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : calendar.component(.hour, from: reminder.scheduledDate)

        let minute = reminder.primaryMinute != -1
            ? reminder.primaryMinute
            : calendar.component(.minute, from: reminder.scheduledDate)

        var times = [String(format: "%02d:%02d", hour, minute)]

        for fireTime in reminder.additionalFireTimes {
            times.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
        }

        return times
    }
}

// MARK: - Timeline Column Sheet

struct KanbanTimelineColumnSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var board: KanbanBoard
    var column: KanbanColumn?

    @State private var name: String
    @State private var selectedColor: Color

    init(board: KanbanBoard, column: KanbanColumn? = nil) {
        self.board = board
        self.column = column
        _name = State(initialValue: column?.name ?? "")
        _selectedColor = State(initialValue: Color(lureliaHex: column?.colorHex ?? "#03dbfc"))
    }

    private var isEditing: Bool { column != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEditing ? "Edit Column" : "New Column")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(isEditing ? "Update this column." : "Add a column to \(board.name).")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }

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

                LureliaFormSection(title: "Column Name") {
                    TextField("e.g. Morning, Afternoon, Evening", text: $name)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                LureliaFormSection(title: "Color") {
                    ColorPicker(selection: $selectedColor, supportsOpacity: false) {
                        Text("Column Color")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(14)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button { save() } label: {
                    Text(isEditing ? "Save Changes" : "Add Column")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LGradients.header)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard canSave else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = selectedColor.toHex() ?? column?.colorHex ?? "#03dbfc"

        if let column {
            column.name = trimmedName
            column.colorHex = hex
        } else {
            let newColumn = KanbanColumn(
                name: trimmedName,
                colorHex: hex,
                sortOrder: (board.columns ?? []).count
            )

            modelContext.insert(newColumn)

            if board.columns == nil {
                board.columns = []
            }

            board.columns?.append(newColumn)
        }

        board.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Create Board Sheet

struct KanbanTimelineCreateBoardSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \KanbanBoard.sortOrder)
    private var boards: [KanbanBoard]

    @State private var name = ""
    @State private var icon = "starcal"
    @State private var selectedColor = Color(lureliaHex: "#03dbfc")

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Board")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Create a board for your timeline.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
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

                LureliaFormSection(title: "Board Name") {
                    TextField("e.g. Weekly Flow", text: $name)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                                    lineWidth: 1.1
                                )
                        )
                        .onSubmit { save() }
                }

                LureliaFormSection(title: "Color") {
                    ColorPicker(selection: $selectedColor, supportsOpacity: false) {
                        Text("Board Color")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(14)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                                lineWidth: 1.1
                            )
                    )
                }

                Button {
                    save()
                } label: {
                    HStack(spacing: 10) {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(.white)

                        Text("Create Board")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(LGradients.header)
                    )
                    .shadow(color: LColors.gradientPurple.opacity(0.25), radius: 18, y: 10)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard canSave else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = selectedColor.toHex() ?? "#03dbfc"

        let board = KanbanBoard(
            name: trimmedName,
            icon: icon,
            colorHex: hex,
            sortOrder: boards.count
        )

        modelContext.insert(board)
        try? modelContext.save()
        dismiss()
    }
}
