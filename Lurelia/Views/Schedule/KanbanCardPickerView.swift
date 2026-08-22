//
//  KanbanCardPickerView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

// MARK: - KanbanCardPickerView

struct KanbanCardPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var column: KanbanColumn

    let allReminders: [LureliaReminder]
    var allRoutineTasks: [LureliaRoutineTask] = []
    var allHabits: [LureliaHabit] = []

    var onCreateReminder: () -> Void

    /// Observed so the picker excludes items pinned in ANY column of ANY
    /// board, not just the column this picker is targeting. Previously
    /// the same habit / routine task / reminder could be pinned to
    /// multiple boards simultaneously, which was confusing.
    @Query private var allBoards: [KanbanBoard]

    @State private var selectedTab = 0

    /// All KanbanCards across every column of every board. Cheap enough to
    /// recompute per body since the source arrays are already resident.
    private var allCards: [KanbanCard] {
        allBoards.flatMap { $0.columns ?? [] }.flatMap { $0.cards ?? [] }
    }

    private var pinnedReminderIDs: Set<String> {
        Set(allCards.filter { $0.cardType == .reminder }.map { $0.itemID })
    }

    private var pinnedRoutineTaskIDs: Set<String> {
        // Normalize each pinned card's `itemID` to its resolved task's
        // composite `kanbanItemID` so legacy bare-stableTaskID cards
        // still exclude the right task from the available list.
        Set(
            allCards
                .filter { $0.cardType == .routineTask }
                .map { card in
                    allRoutineTasks.first { $0.matchesKanbanItemID(card.itemID) }?.kanbanItemID ?? card.itemID
                }
        )
    }

    private var pinnedHabitIDs: Set<String> {
        Set(allCards.filter { $0.cardType == .habit }.map { $0.itemID })
    }

    private var availableReminders: [LureliaReminder] {
        allReminders.filter { !pinnedReminderIDs.contains($0.id.uuidString) }
            .sorted { $0.title < $1.title }
    }

    private var availableRoutineTasks: [LureliaRoutineTask] {
        allRoutineTasks.filter { !pinnedRoutineTaskIDs.contains($0.kanbanItemID) }
            .sorted { ($0.routine?.name ?? "") < ($1.routine?.name ?? "") }
    }

    private var availableHabits: [LureliaHabit] {
        allHabits
            .filter { !$0.isArchived && !pinnedHabitIDs.contains($0.kanbanItemID) }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        ZStack {
            LureliaBackground()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Card")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Pick a reminder, routine task, or habit to add.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Tab selector
                HStack(spacing: 8) {
                    tabButton(title: "Reminders", index: 0)
                    tabButton(title: "Routine Tasks", index: 1)
                    tabButton(title: "Habits", index: 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Divider().overlay(LColors.glassBorder)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        if selectedTab == 0 {
                            Button {
                                dismiss()
                                onCreateReminder()
                            } label: {
                                HStack(spacing: 10) {
                                    Image("bellfill")
                                        .renderingMode(.template).resizable().scaledToFit()
                                        .frame(width: 18, height: 18).foregroundStyle(LGradients.header)
                                    Text("New Reminder")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            if availableReminders.isEmpty {
                                emptyPicker(label: "No reminders available")
                            } else {
                                ForEach(availableReminders) { reminder in
                                    existingReminderRow(reminder)
                                }
                            }
                        } else if selectedTab == 1 {
                            if availableRoutineTasks.isEmpty {
                                emptyPicker(label: "No routine tasks available")
                            } else {
                                ForEach(availableRoutineTasks, id: \.kanbanItemID) { task in
                                    routineTaskRow(task)
                                }
                            }
                        } else {
                            if availableHabits.isEmpty {
                                emptyPicker(label: "No habits available")
                            } else {
                                ForEach(availableHabits) { habit in
                                    habitRow(habit)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .padding(.bottom, 60)
                }
            }
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selectedTab == index ? .white : LColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedTab == index
                    ? AnyShapeStyle(LGradients.header)
                    : AnyShapeStyle(LColors.glassSurface),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            selectedTab == index ? LColors.glassBorderStrong : LColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func existingReminderRow(_ reminder: LureliaReminder) -> some View {
        Button { addCard(type: .reminder, itemID: reminder.id.uuidString) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LColors.gradientPurple.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image("bellfill")
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 16, height: 16).foregroundStyle(LColors.gradientPurple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary).lineLimit(1)
                    Text(reminder.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(LColors.gradientPurple)
            }
            .padding(12)
            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func routineTaskRow(_ task: LureliaRoutineTask) -> some View {
        Button { addCard(type: .routineTask, itemID: task.kanbanItemID) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(lureliaHex: task.routine?.colorHex ?? "#7d19f7").opacity(0.14))
                        .frame(width: 38, height: 38)
                    LureliaIconView(iconId: task.icon, size: 16)
                        .foregroundStyle(Color(lureliaHex: task.routine?.colorHex ?? "#7d19f7"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary).lineLimit(1)
                    if let routine = task.routine {
                        Text(routine.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(Color(lureliaHex: task.routine?.colorHex ?? "#7d19f7"))
            }
            .padding(12)
            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func habitRow(_ habit: LureliaHabit) -> some View {
        Button { addCard(type: .habit, itemID: habit.kanbanItemID) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LColors.gradientBlue.opacity(0.14))
                        .frame(width: 38, height: 38)
                    LureliaIconView(iconId: habit.iconName ?? "flame", size: 16)
                        .foregroundStyle(LColors.gradientBlue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary).lineLimit(1)
                    Text("\(habit.target)x/day")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(LColors.gradientBlue)
            }
            .padding(12)
            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func emptyPicker(label: String) -> some View {
        Text(label)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(LColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private func addCard(type: KanbanCardType, itemID: String) {
        let card = KanbanCard(cardType: type, itemID: UUID(), sortOrder: (column.cards ?? []).count)
        card.itemID = itemID
        card.cardType = type
        modelContext.insert(card)
        if column.cards == nil { column.cards = [] }
        column.cards?.append(card)
        try? modelContext.save()
        dismiss()
    }
}
