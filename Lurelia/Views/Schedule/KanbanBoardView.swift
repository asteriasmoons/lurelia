//
//  KanbanBoardView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

enum KanbanCreateType { case reminder }
struct KanbanCreateRequest: Identifiable {
    let id = UUID()
    let type: KanbanCreateType
    let column: KanbanColumn
}

// MARK: - KanbanBoardView

struct KanbanBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var board: KanbanBoard

    @Query private var allReminders: [LureliaReminder]
    @Query private var allBoards: [KanbanBoard]

    @State private var showAddColumn = false
    @State private var targetColumn: KanbanColumn?
    @State private var editingColumn: KanbanColumn?
    @State private var createRequest: KanbanCreateRequest?
    @State private var showCompletionBanner = false

    private func triggerBanner() {
        showCompletionBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCompletionBanner = false
        }
    }

    private var accentColor: Color { Color(lureliaHex: board.colorHex) }

    private var pinnedReminderIDs: Set<String> {
        let columns = allBoards.flatMap { $0.columns ?? [] }
        let cards = columns.flatMap { $0.cards ?? [] }
        let reminderCards = cards.filter { $0.cardType == .reminder }
        return Set(reminderCards.map { $0.itemID })
    }

    private var inboxReminders: [LureliaReminder] {
        allReminders
            .filter { $0.kind == .standalone && !pinnedReminderIDs.contains($0.id.uuidString) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 0) {
                HStack {
                    Text(board.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 14) {
                        Button { showAddColumn = true } label: {
                            Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 28, height: 28).foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)

                        Button { dismiss() } label: {
                            Image("xmarkwavy").renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 28, height: 28).foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 59)
                .padding(.bottom, 16)

                if board.sortedColumns.isEmpty {
                    emptyState.padding(.top, 40)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            if !inboxReminders.isEmpty {
                                KanbanInboxColumnView(
                                    board: board,
                                    reminders: inboxReminders,
                                    boardAccent: accentColor,
                                    onMoveReminder: { reminder, col in
                                        pinCard(type: .reminder, itemID: reminder.id.uuidString, in: col)
                                    }
                                )
                            }

                            ForEach(board.sortedColumns) { column in
                                KanbanColumnView(
                                    column: column,
                                    allReminders: allReminders,
                                    onAddCard: {
                                        createRequest = KanbanCreateRequest(type: .reminder, column: column)
                                    },
                                    onEditColumn: {
                                        editingColumn = column
                                    },
                                    onComplete: { triggerBanner() }
                                )
                            }

                            Button { showAddColumn = true } label: {
                                HStack(spacing: 10) {
                                    Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                                        .frame(width: 20, height: 20).foregroundStyle(LGradients.header)
                                    Text("Add Column")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16).padding(.vertical, 18)
                                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16).padding(.bottom, 120)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .completionBanner(isShowing: showCompletionBanner, message: "Reminder completed!")
        .sheet(isPresented: $showAddColumn) { AddColumnView(board: board) }
        .sheet(item: $editingColumn) { col in
            AddColumnView(board: board, column: col)
        }
        .sheet(item: $targetColumn) { col in
            KanbanCardPickerView(column: col, allReminders: allReminders, onCreateReminder: {
                createRequest = KanbanCreateRequest(type: .reminder, column: col)
            })
        }
        .sheet(item: $createRequest) { req in
            AddReminderView(onCreated: { reminder in
                pinCard(type: .reminder, itemID: reminder.id.uuidString, in: req.column)
            })
        }
    }

    private func pinCard(type: KanbanCardType, itemID: String, in col: KanbanColumn) {
        let card = KanbanCard(cardType: type, itemID: UUID(), sortOrder: (col.cards ?? []).count)
        card.itemID = itemID
        modelContext.insert(card)
        if col.cards == nil {
            col.cards = []
        }
        col.cards?.append(card)
        try? modelContext.save()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(board.icon).renderingMode(.template).resizable().scaledToFit()
                .frame(width: 48, height: 48).foregroundStyle(accentColor)
            Text("No Columns Yet")
                .font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(LColors.textPrimary)
            Text("Add columns to organize your board.")
                .font(.system(size: 14, design: .rounded)).foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Button { showAddColumn = true } label: {
                Text("Add Column")
                    .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LGradients.header))
            }
            .buttonStyle(.plain).padding(.horizontal, 40).padding(.top, 4)
        }
    }
}

// MARK: - KanbanColumnView

struct KanbanColumnView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var column: KanbanColumn

    let allReminders: [LureliaReminder]
    let onAddCard: () -> Void
    let onEditColumn: () -> Void
    var onComplete: (() -> Void)? = nil

    private var accentColor: Color { Color(lureliaHex: column.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(column.name)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Spacer()
                Text("\(column.sortedCards.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(accentColor.opacity(0.14), in: Capsule())
                Button { onAddCard() } label: {
                    Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 18, height: 18).foregroundStyle(LGradients.header)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.top, 14)

            Divider().overlay(LColors.glassBorder).padding(.horizontal, 10)

            VStack(spacing: 10) {
                ForEach(column.sortedCards) { card in
                    if card.cardType == .reminder {
                        KanbanItemCard(
                            card: card,
                            allReminders: allReminders,
                            columnAccent: accentColor,
                            onDelete: { deleteCard(card) },
                            onComplete: onComplete
                        )
                        .contextMenu {
                            ForEach(availableMoveColumns(for: card)) { targetColumn in
                                Button { moveCard(card, to: targetColumn) } label: {
                                    Label("Move to \(targetColumn.name)", systemImage: "arrow.right.circle")
                                }
                            }
                            Divider()
                            Button(role: .destructive) { deleteCard(card) } label: {
                                Label("Delete Card", systemImage: "trash")
                            }
                        }
                    }
                }

                if column.sortedCards.isEmpty {
                    VStack(spacing: 8) {
                        Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 20, height: 20).foregroundStyle(LColors.textSecondary.opacity(0.4))
                        Text("No cards yet")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(accentColor.opacity(0.10))
                .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(accentColor.opacity(0.35), lineWidth: 1) }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            Button { onEditColumn() } label: {
                Label("Edit Column", systemImage: "pencil")
            }
        }
    }

    private func deleteCard(_ card: KanbanCard) { modelContext.delete(card); try? modelContext.save() }

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
        for (i, c) in (column.cards ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() { c.sortOrder = i }
        for (i, c) in (targetColumn.cards ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() { c.sortOrder = i }
        try? modelContext.save()
    }
}

// MARK: - KanbanItemCard

struct KanbanItemCard: View {
    let card: KanbanCard
    let allReminders: [LureliaReminder]
    let columnAccent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    var body: some View {
        if card.cardType == .reminder,
           let reminder = allReminders.first(where: { $0.id.uuidString == card.itemID }) {
            KanbanReminderCard(reminder: reminder, accent: columnAccent, onDelete: onDelete, onComplete: onComplete)
        } else {
            orphanCard
        }
    }

    private var orphanCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(LColors.textSecondary)
            Text("Item deleted").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image("trash").renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 14, height: 14).foregroundStyle(Color(lureliaHex: "#0db7d9"))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - KanbanInboxColumnView

struct KanbanInboxColumnView: View {
    let board: KanbanBoard
    let reminders: [LureliaReminder]
    let boardAccent: Color
    let onMoveReminder: (LureliaReminder, KanbanColumn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image("inbox").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 16, height: 16).foregroundStyle(boardAccent)
                    Text("Inbox").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(LColors.textPrimary)
                }
                Spacer()
                Text("\(reminders.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(boardAccent)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(boardAccent.opacity(0.14), in: Capsule())
            }
            .padding(.horizontal, 14).padding(.top, 14)

            Divider().overlay(LColors.glassBorder).padding(.horizontal, 10)

            VStack(spacing: 10) {
                ForEach(reminders) { reminder in
                    KanbanInboxReminderCard(reminder: reminder, accent: boardAccent)
                        .contextMenu {
                            if board.sortedColumns.isEmpty {
                                Label {
                                    Text("Add a column first")
                                } icon: {
                                    Image("inbox")
                                        .renderingMode(.template)
                                }
                            } else {
                                ForEach(board.sortedColumns) { col in
                                    Button { onMoveReminder(reminder, col) } label: {
                                        Label("Move to \(col.name)", systemImage: "arrow.right.circle")
                                    }
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(boardAccent.opacity(0.08))
                .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(boardAccent.opacity(0.28), lineWidth: 1) }
        }
    }
}

// MARK: - KanbanInboxReminderCard

struct KanbanInboxReminderCard: View {
    let reminder: LureliaReminder
    let accent: Color

    private var reminderIcon: String {
        reminder.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bellfill" : reminder.icon
    }

    private func resolvedTimesOfDay() -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        if !stored.isEmpty { return stored }
        let cal = Calendar.current
        let anchor = reminder.nextFireAt ?? reminder.scheduledDate
        let ph = reminder.primaryHour != -1 ? reminder.primaryHour : cal.component(.hour, from: anchor)
        let pm = reminder.primaryMinute != -1 ? reminder.primaryMinute : cal.component(.minute, from: anchor)
        var times = [String(format: "%02d:%02d", ph, pm)]
        for ft in reminder.additionalFireTimes { times.append(String(format: "%02d:%02d", ft.hour, ft.minute)) }
        return times
    }

    private var allFireDates: [Date] {
        let cal = Calendar.current
        let anchor = reminder.nextFireAt ?? reminder.scheduledDate
        let dayComponents = cal.dateComponents([.year, .month, .day], from: anchor)
        return resolvedTimesOfDay().compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            var c = dayComponents; c.hour = h; c.minute = m; c.second = 0
            return cal.date(from: c)
        }.sorted()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Color.white.opacity(0.10)).frame(width: 36, height: 36)
                LureliaIconView(iconId: reminderIcon, size: 19).foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(reminder.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(reminder.isEnabled ? LColors.textPrimary : LColors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ForEach(Array(allFireDates.prefix(2).enumerated()), id: \.offset) { _, d in
                        Text(d.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.75)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(accent.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
                    }
                    if allFireDates.count > 2 {
                        Text("+\(allFireDates.count - 2)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
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
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(accent.opacity(0.22), lineWidth: 1) }
        }
        .opacity(reminder.isEnabled ? 1 : 0.65)
    }
}

// MARK: - KanbanReminderCard

struct KanbanReminderCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var reminder: LureliaReminder
    let accent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    private var reminderIcon: String {
        reminder.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bellfill" : reminder.icon
    }

    // All configured fire times displayed on the card — read from timesOfDay (source of truth)
    private var allFireDates: [Date] {
        let cal = Calendar.current
        let anchor = reminder.nextFireAt ?? reminder.scheduledDate
        let dayComponents = cal.dateComponents([.year, .month, .day], from: anchor)
        let times = resolvedTimesOfDay()

        return times.compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            var c = dayComponents
            c.hour = h
            c.minute = m
            c.second = 0
            return cal.date(from: c)
        }.sorted()
    }

    private func resolvedTimesOfDay() -> [String] {
        let stored = reminder.timesOfDay.filter { !$0.isEmpty }
        if !stored.isEmpty { return stored }
        let cal = Calendar.current
        let ph = reminder.primaryHour != -1 ? reminder.primaryHour : cal.component(.hour, from: reminder.scheduledDate)
        let pm = reminder.primaryMinute != -1 ? reminder.primaryMinute : cal.component(.minute, from: reminder.scheduledDate)
        var times = [String(format: "%02d:%02d", ph, pm)]
        for ft in reminder.additionalFireTimes { times.append(String(format: "%02d:%02d", ft.hour, ft.minute)) }
        return times
    }

    private var isDoneToday: Bool {
        // Recurring reminders are never "done" — they always show status badges
        // This matches the main RemindersView behavior exactly.
        guard reminder.repeatUnit == .none else { return false }
        let cal = Calendar.current
        if let completedAt = reminder.completedAt, cal.isDateInToday(completedAt) { return true }
        return reminder.completionTimestamps.contains { cal.isDateInToday($0) }
    }

    private func isOverdue(now: Date) -> Bool {
        guard !isDoneToday && reminder.isEnabled else { return false }
        if reminder.repeatUnit == .none && reminder.isCompleted { return false }
        let startOfToday = Calendar.current.startOfDay(for: now)
        return (reminder.nextFireAt ?? reminder.scheduledDate) < startOfToday
    }

    private func isDueNow(now: Date) -> Bool {
        guard !isDoneToday && reminder.isEnabled else { return false }
        if reminder.repeatUnit == .none && reminder.isCompleted { return false }
        let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
        // Recurring reminders missed on a prior day should not stay stuck on Due Now
        if reminder.repeatUnit != .none {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if nextFire < startOfToday { return false }
        }
        return nextFire <= now
    }

    private func isUpcoming(now: Date) -> Bool {
        guard !isDoneToday && reminder.isEnabled else { return false }
        if reminder.repeatUnit == .none && reminder.isCompleted { return false }
        let nextFire = reminder.nextFireAt ?? reminder.scheduledDate
        guard nextFire > now else { return false }
        return nextFire <= now.addingTimeInterval(24 * 60 * 60)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            cardContent(
                overdue:  isOverdue(now: now),
                dueNow:   isDueNow(now: now),
                upcoming: isUpcoming(now: now)
            )
        }
    }

    @ViewBuilder
    private func cardContent(overdue: Bool, dueNow: Bool, upcoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.10)).frame(width: 36, height: 36)
                    LureliaIconView(iconId: reminderIcon, size: 19).foregroundStyle(.white)
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
                if let notes = reminder.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        Button { completeReminderOccurrence() } label: {
            ZStack {
                Circle()
                    .fill(reminder.isCompleted && reminder.repeatUnit == .none ? accent.opacity(0.18) : Color.clear)
                    .frame(width: 30, height: 30)
                    .overlay { Circle().strokeBorder(accent.opacity(0.75), lineWidth: 2) }
                if reminder.isCompleted && reminder.repeatUnit == .none {
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
                .overlay(Circle().strokeBorder(LColors.glassBorder.opacity(0.75), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func badgeRow(overdue: Bool, dueNow: Bool, upcoming: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(Array(allFireDates.prefix(2).enumerated()), id: \.offset) { _, d in
                Text(d.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
            }

            if allFireDates.count > 2 {
                Text("+\(allFireDates.count - 2)")
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

    // MARK: Actions

    private func completeReminderOccurrence() {
        Task {
            await LureliaNotificationManager.shared.cancelReminder(reminder)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                reminder.updatedAt = Date()
                let completedAt = reminder.nextFireAt ?? reminder.scheduledDate
                var timestamps = reminder.completionTimestamps
                timestamps.append(completedAt)
                reminder.completionTimestamps = timestamps

                if reminder.repeatUnit != .none, let next = nextScheduledDate(after: completedAt) {
                    reminder.nextFireAt = next
                    if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                        reminder.scheduledDate = primaryFireDate(onSameDayAs: next)
                    }
                } else {
                    reminder.isCompleted = true
                    reminder.completedAt = Date()
                }
            }
            try? modelContext.save()
            if reminder.repeatUnit != .none && reminder.isEnabled {
                await LureliaNotificationManager.shared.scheduleReminder(reminder)
            }
            await MainActor.run { onComplete?() }
        }
    }

    private func skipReminderOccurrence() {
        Task {
            await LureliaNotificationManager.shared.cancelReminder(reminder)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                reminder.updatedAt = Date()
                let skippedAt = reminder.nextFireAt ?? reminder.scheduledDate
                var timestamps = reminder.skippedTimestamps
                timestamps.append(skippedAt)
                reminder.skippedTimestamps = timestamps

                if let next = nextScheduledDate(after: skippedAt) {
                    reminder.nextFireAt = next
                    if !Calendar.current.isDate(next, inSameDayAs: reminder.scheduledDate) {
                        reminder.scheduledDate = primaryFireDate(onSameDayAs: next)
                    }
                } else {
                    reminder.isEnabled = false
                }
            }
            try? modelContext.save()
            if reminder.isEnabled {
                await LureliaNotificationManager.shared.scheduleReminder(reminder)
            }
        }
    }

    private func primaryFireDate(onSameDayAs date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.dateComponents([.year, .month, .day], from: date)
        let time = cal.dateComponents([.hour, .minute, .second], from: reminder.scheduledDate)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second ?? 0
        return cal.date(from: day) ?? date
    }

    private func nextScheduledDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        let allTodayFires = allFireTimesOnSameDay(as: reminder.scheduledDate, using: calendar)
        if let nextToday = allTodayFires.filter({ $0 > date }).min() { return nextToday }
        return nextOccurrenceAfter(date: date, calendar: calendar)
    }

    private func allFireTimesOnSameDay(as refDate: Date, using calendar: Calendar) -> [Date] {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: refDate)
        let times = resolvedTimesOfDay()

        return times.compactMap { timeStr -> Date? in
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            var c = dayComponents
            c.hour = h
            c.minute = m
            c.second = 0
            return calendar.date(from: c)
        }.sorted()
    }

    private func nextOccurrenceAfter(date: Date, calendar: Calendar) -> Date? {
        let interval = max(1, reminder.repeatInterval)
        var next = reminder.scheduledDate

        func earliestFireOn(_ d: Date) -> Date? {
            allFireTimesOnSameDay(as: d, using: calendar).filter { $0 > date }.min()
        }

        switch reminder.repeatUnit {
        case .minutes:
            repeat {
                guard let d = calendar.date(byAdding: .minute, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return next

        case .hours:
            repeat {
                guard let d = calendar.date(byAdding: .hour, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return next

        case .days:
            repeat {
                guard let d = calendar.date(byAdding: .day, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return earliestFireOn(next) ?? next

        case .weeks:
            if reminder.repeatWeekdays.isEmpty {
                repeat {
                    guard let d = calendar.date(byAdding: .weekOfYear, value: interval, to: next) else { return nil }
                    next = d
                } while next <= date
                return earliestFireOn(next) ?? next
            }
            let wds = Set(reminder.repeatWeekdays)
            let start = calendar.startOfDay(for: date)
            for offset in 1...370 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                guard wds.contains(calendar.component(.weekday, from: day)) else { continue }
                if let fire = earliestFireOn(day) { return fire }
            }
            return nil

        case .months:
            repeat {
                guard let d = calendar.date(byAdding: .month, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return earliestFireOn(next) ?? next

        case .years:
            repeat {
                guard let d = calendar.date(byAdding: .year, value: interval, to: next) else { return nil }
                next = d
            } while next <= date
            return earliestFireOn(next) ?? next

        case .none:
            return nil
        }
    }
}

// MARK: - AddColumnView

struct AddColumnView: View {
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
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEditing ? "Edit Column" : "New Column")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(isEditing ? "Update this column’s name and color." : "Add a column to \(board.name).")
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
                }
                .padding(.horizontal, 24)

                LureliaFormSection(title: "Column Name") {
                    TextField("e.g. To Do, In Progress, Done", text: $name)
                        .font(.system(size: 15, design: .rounded)).foregroundStyle(.white)
                        .padding(14).background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
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
                        Text("Column Color").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(LColors.textPrimary)
                    }
                    .padding(14)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
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

                Button { save() } label: {
                    HStack(spacing: 10) {
                        Image(isEditing ? "checkwavy" : "addwavy").renderingMode(.template).resizable().scaledToFit().frame(width: 14, height: 14).foregroundStyle(.white)
                        Text(isEditing ? "Save Changes" : "Add Column").font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 60)
                    .background(RoundedRectangle(cornerRadius: 22).fill(LGradients.header))
                    .shadow(color: LColors.gradientPurple.opacity(0.25), radius: 18, y: 10)
                }
                .buttonStyle(.plain).disabled(!canSave).opacity(canSave ? 1 : 0.45).padding(.horizontal, 24)

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
            let col = KanbanColumn(name: trimmedName, colorHex: hex, sortOrder: (board.columns ?? []).count)
            modelContext.insert(col)
            if board.columns == nil {
                board.columns = []
            }
            board.columns?.append(col)
        }

        try? modelContext.save()
        dismiss()
    }
}
