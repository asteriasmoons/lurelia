//
//  KanbanBoardView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import WidgetKit

enum KanbanCreateType { case reminder }
struct KanbanCreateRequest: Identifiable {
    let id = UUID()
    let type: KanbanCreateType
    let column: KanbanColumn
}

struct KanbanRoutineTaskCreateRequest: Identifiable {
    let id = UUID()
    let routine: LureliaRoutine
    let column: KanbanColumn
}

struct KanbanHabitCreateRequest: Identifiable {
    let id = UUID()
    let column: KanbanColumn
}

// MARK: - Kanban Column Add Menu

struct KanbanColumnAddCardMenu<LabelContent: View>: View {
    @Bindable var column: KanbanColumn

    let allReminders: [LureliaReminder]
    let allRoutines: [LureliaRoutine]
    let allHabits: [LureliaHabit]
    let onCreateReminder: () -> Void
    let onCreateHabit: () -> Void
    let onAddCard: (KanbanCardType, String) -> Void
    let onAddTask: (LureliaRoutine) -> Void
    @ViewBuilder var label: () -> LabelContent

    /// Observed so pinning excludes items pinned anywhere across every
    /// board — not just this column. Previously the same habit / routine
    /// task / reminder could be pinned to multiple boards at once.
    @Query private var allBoards: [KanbanBoard]

    private var allCards: [KanbanCard] {
        allBoards.flatMap { $0.columns ?? [] }.flatMap { $0.cards ?? [] }
    }

    private var pinnedReminderIDs: Set<String> {
        Set(allCards.filter { $0.cardType == .reminder }.map(\.itemID))
    }

    private var pinnedRoutineTaskIDs: Set<String> {
        let allTasks = allRoutines.flatMap { $0.sortedTasks }
        return Set(
            allCards
                .filter { $0.cardType == .routineTask }
                .map { card in
                    allTasks.first { $0.matchesKanbanItemID(card.itemID) }?.kanbanItemID ?? card.itemID
                }
        )
    }

    private var pinnedHabitIDs: Set<String> {
        Set(allCards.filter { $0.cardType == .habit }.map(\.itemID))
    }

    private var availableReminders: [LureliaReminder] {
        allReminders
            .filter { !pinnedReminderIDs.contains($0.id.uuidString) }
            .sorted { $0.title < $1.title }
    }

    private var availableRoutines: [LureliaRoutine] {
        allRoutines.sorted { $0.name < $1.name }
    }

    private var availableHabits: [LureliaHabit] {
        allHabits
            .filter { !$0.isArchived && !pinnedHabitIDs.contains($0.kanbanItemID) }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        Menu {
            Menu {
                Button {
                    onCreateReminder()
                } label: {
                    Label("New Reminder", systemImage: "plus.circle")
                }

                if availableReminders.isEmpty {
                    Text("No existing reminders")
                } else {
                    Menu {
                        ForEach(availableReminders) { reminder in
                            Button {
                                onAddCard(.reminder, reminder.id.uuidString)
                            } label: {
                                Label(reminder.title, systemImage: "bell")
                            }
                        }
                    } label: {
                        Label("Existing Reminders", systemImage: "tray")
                    }
                }
            } label: {
                Label("Reminder", systemImage: "bell")
            }

            Menu {
                if availableRoutines.isEmpty {
                    Text("No routines available")
                } else {
                    ForEach(availableRoutines) { routine in
                        routineMenu(for: routine)
                    }
                }
            } label: {
                Label("Routine", systemImage: "repeat")
            }

            Menu {
                Button {
                    onCreateHabit()
                } label: {
                    Label("New Habit", systemImage: "plus.circle")
                }

                if availableHabits.isEmpty {
                    Text("No habits available")
                } else {
                    ForEach(availableHabits) { habit in
                        Button {
                            onAddCard(.habit, habit.kanbanItemID)
                        } label: {
                            Label(habit.title, systemImage: "flame")
                        }
                    }
                }
            } label: {
                Label("Habit", systemImage: "flame")
            }
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func routineMenu(for routine: LureliaRoutine) -> some View {
        Menu {
            if routine.sortedTasks.isEmpty {
                Text("No tasks yet")
            } else {
                Menu {
                    ForEach(routine.sortedTasks, id: \.kanbanItemID) { task in
                        Button {
                            onAddCard(.routineTask, task.kanbanItemID)
                        } label: {
                            Label(
                                task.title,
                                systemImage: pinnedRoutineTaskIDs.contains(task.kanbanItemID) ? "checkmark.circle" : "circle"
                            )
                        }
                        .disabled(pinnedRoutineTaskIDs.contains(task.kanbanItemID))
                    }
                } label: {
                    Label("Add Existing Task", systemImage: "checklist")
                }
            }

            Button {
                onAddTask(routine)
            } label: {
                Label("Add New Task", systemImage: "plus")
            }
        } label: {
            Label(routine.name, systemImage: "repeat")
        }
    }
}

// MARK: - Kanban Routine Task Creation Sheet

struct KanbanRoutineTaskCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: LureliaRoutine
    let onCreated: (LureliaRoutineTask) -> Void

    var body: some View {
        AddCustomRoutineTaskView { draft in
            addTask(from: draft)
        }
    }

    private func addTask(from draft: LureliaRoutineTaskDraft) {
        let title = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let task = LureliaRoutineTask(
            title: title,
            icon: draft.icon,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: routine.sortedTasks.count
        )
        task.routine = routine
        modelContext.insert(task)

        if routine.tasks == nil {
            routine.tasks = []
        }
        routine.tasks?.append(task)

        applyTaskDraft(draft, to: task)
        routine.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("🚨 [KanbanRoutineTaskCreation] save failed: \(error)")
        }

        RoutineTaskManager.shared.sync(task: task)
        LureliaWidgetReloads.reloadAll()
        onCreated(task)
    }

    private func applyTaskDraft(_ draft: LureliaRoutineTaskDraft, to task: LureliaRoutineTask) {
        task.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        task.context = draft.context.trimmingCharacters(in: .whitespacesAndNewlines)
        task.purpose = draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        task.motivation = draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        task.trigger = draft.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        task.triggerType = draft.triggerType
        task.triggerReason = draft.triggerReason.trimmingCharacters(in: .whitespacesAndNewlines)
        task.environment = draft.environment.trimmingCharacters(in: .whitespacesAndNewlines)
        task.reward = draft.reward.trimmingCharacters(in: .whitespacesAndNewlines)
        task.consequence = draft.consequence.trimmingCharacters(in: .whitespacesAndNewlines)
        task.recoveryPlan = draft.recoveryPlan.trimmingCharacters(in: .whitespacesAndNewlines)

        task.hasDueTime = draft.hasDueTime
        task.dueHour = draft.dueHour
        task.dueMinute = draft.dueMinute
        task.estimatedDurationMinutes = max(0, draft.estimatedDurationMinutes)
        task.repeatsOnDays = draft.repeatsOnDays
        task.scheduledDays = draft.scheduledDays.sorted()

        task.notificationsEnabled = draft.notificationsEnabled && draft.hasDueTime
        task.notificationLeadMinutes = draft.notificationLeadMinutes.sorted()
        task.alarmEnabled = draft.alarmEnabled && draft.hasDueTime
        task.alarmSoundName = (draft.alarmEnabled && draft.hasDueTime) ? draft.alarmSoundName : nil

        for (index, stepDraft) in draft.steps.enumerated()
        where !stepDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let step = LureliaRoutineTaskStep(
                title: stepDraft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                isCompleted: stepDraft.isCompleted,
                sortOrder: index
            )
            step.id = stepDraft.id
            step.task = task
            modelContext.insert(step)
            if task.stepItems == nil { task.stepItems = [] }
            task.stepItems?.append(step)
        }

        for (index, supplyDraft) in draft.supplies.enumerated()
        where !supplyDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let supply = LureliaRoutineTaskSupply(
                name: supplyDraft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: index
            )
            supply.id = supplyDraft.id
            supply.task = task
            modelContext.insert(supply)
            if task.supplyItems == nil { task.supplyItems = [] }
            task.supplyItems?.append(supply)
        }

        for (index, obstacleDraft) in draft.obstacles.enumerated()
        where !obstacleDraft.obstacle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let obstacle = LureliaRoutineTaskObstacle(
                obstacle: obstacleDraft.obstacle.trimmingCharacters(in: .whitespacesAndNewlines),
                solution: obstacleDraft.solution.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: index
            )
            obstacle.id = obstacleDraft.id
            obstacle.task = task
            modelContext.insert(obstacle)
            if task.obstacleItems == nil { task.obstacleItems = [] }
            task.obstacleItems?.append(obstacle)
        }
    }
}

// MARK: - KanbanBoardView

struct KanbanBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var board: KanbanBoard

    @Query private var allReminders: [LureliaReminder]
    @Query private var allRoutines: [LureliaRoutine]
    @Query private var allHabits: [LureliaHabit]
    @Query private var allBoards: [KanbanBoard]

    @State private var showAddColumn = false
    @State private var editingColumn: KanbanColumn?
    @State private var createRequest: KanbanCreateRequest?
    @State private var taskCreateRequest: KanbanRoutineTaskCreateRequest?
    @State private var habitCreateRequest: KanbanHabitCreateRequest?
    @State private var showCompletionBanner = false

    private func triggerBanner() {
        showCompletionBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCompletionBanner = false
        }
    }

    private var accentColor: Color { Color(lureliaHex: board.colorHex) }

    private var allRoutineTasks: [LureliaRoutineTask] {
        allRoutines.flatMap { $0.sortedTasks }
    }

    private var pinnedReminderIDs: Set<String> {
        let columns = allBoards.flatMap { $0.columns ?? [] }
        let cards = columns.flatMap { $0.cards ?? [] }
        let reminderCards = cards.filter { $0.cardType == .reminder }
        return Set(reminderCards.map { $0.itemID })
    }

    private var pinnedHabitIDsForBoard: Set<String> {
        // App-wide scope: a habit pinned on any board (not just this one)
        // should stop appearing in this board's habit inbox so the same
        // habit can't get pinned to multiple boards at once.
        let columns = allBoards.flatMap { $0.columns ?? [] }
        let cards = columns.flatMap { $0.cards ?? [] }
        return Set(cards.filter { $0.cardType == .habit }.map(\.itemID))
    }

    private var inboxReminders: [LureliaReminder] {
        allReminders
            .filter { $0.kind == .standalone && !pinnedReminderIDs.contains($0.id.uuidString) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var inboxHabits: [LureliaHabit] {
        allHabits
            .filter { !$0.isArchived && !pinnedHabitIDsForBoard.contains($0.kanbanItemID) }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        NavigationStack {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 0) {
                HStack {
                    Text(board.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
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
                .padding(.bottom, 4)

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

                            if !allRoutines.isEmpty {
                                KanbanRoutineTaskSourceColumnView(
                                    board: board,
                                    routines: allRoutines,
                                    boardAccent: accentColor,
                                    onAddRoutineTask: { task, column in
                                        pinCard(type: .routineTask, itemID: task.kanbanItemID, in: column)
                                    },
                                    onAddNewTask: { routine, column in
                                        taskCreateRequest = KanbanRoutineTaskCreateRequest(routine: routine, column: column)
                                    }
                                )
                            }

                            if !inboxHabits.isEmpty {
                                KanbanHabitSourceColumnView(
                                    board: board,
                                    habits: inboxHabits,
                                    boardAccent: accentColor,
                                    onAddHabit: { habit, column in
                                        pinCard(type: .habit, itemID: habit.kanbanItemID, in: column)
                                    }
                                )
                            }

                            ForEach(board.sortedColumns) { column in
                                KanbanColumnView(
                                    column: column,
                                    allReminders: allReminders,
                                    allRoutines: allRoutines,
                                    allRoutineTasks: allRoutineTasks,
                                    allHabits: allHabits,
                                    onCreateReminder: {
                                        createRequest = KanbanCreateRequest(type: .reminder, column: column)
                                    },
                                    onCreateHabit: {
                                        habitCreateRequest = KanbanHabitCreateRequest(column: column)
                                    },
                                    onAddCard: { type, itemID in
                                        pinCard(type: type, itemID: itemID, in: column)
                                    },
                                    onAddTask: { routine in
                                        taskCreateRequest = KanbanRoutineTaskCreateRequest(routine: routine, column: column)
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
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 120)
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
        .sheet(item: $createRequest) { req in
            AddReminderView(onCreated: { reminder in
                pinCard(type: .reminder, itemID: reminder.id.uuidString, in: req.column)
            })
        }
        .sheet(item: $taskCreateRequest) { request in
            KanbanRoutineTaskCreationSheet(routine: request.routine) { task in
                pinCard(type: .routineTask, itemID: task.kanbanItemID, in: request.column)
            }
        }
        .sheet(item: $habitCreateRequest) { request in
            LureliaHabitFormSheet(
                habit: nil,
                onSaved: { habit in
                    pinCard(type: .habit, itemID: habit.kanbanItemID, in: request.column)
                },
                onClose: {
                    habitCreateRequest = nil
                }
            )
        }
        .navigationDestination(for: UUID.self) { reminderID in
            if let reminder = allReminders.first(where: { $0.id == reminderID }) {
                ReminderDetailView(reminder: reminder)
            } else if let habit = allHabits.first(where: { $0.id == reminderID }) {
                HabitBlueprintDetailView(habit: habit)
            }
            }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            if allRoutines.contains(where: { $0.id == id }) {
                RoutineDetailView(routineID: id)
            } else if let task = allRoutineTasks.first(where: { $0.id == id }) {
                RoutineTaskDetailView(
                    task: task,
                    routineTint: task.routine.map { Color(lureliaHex: $0.colorHex) } ?? LColors.gradientPurple
                )
            }
        }
        }
    }

    private func pinCard(type: KanbanCardType, itemID: String, in col: KanbanColumn) {
        let alreadyExists = (col.cards ?? []).contains {
            $0.cardType == type && $0.itemID == itemID
        }
        guard !alreadyExists else { return }

        let card = KanbanCard(cardType: type, itemID: UUID(), sortOrder: (col.cards ?? []).count)
        card.itemID = itemID
        card.cardType = type
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
                    .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(LColors.textPrimary)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background { LureliaNeutralGlassSurface(cornerRadius: 20) }
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
    let allRoutines: [LureliaRoutine]
    let allRoutineTasks: [LureliaRoutineTask]
    let allHabits: [LureliaHabit]
    let onCreateReminder: () -> Void
    let onCreateHabit: () -> Void
    let onAddCard: (KanbanCardType, String) -> Void
    let onAddTask: (LureliaRoutine) -> Void
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
                KanbanColumnAddCardMenu(
                    column: column,
                    allReminders: allReminders,
                    allRoutines: allRoutines,
                    allHabits: allHabits,
                    onCreateReminder: onCreateReminder,
                    onCreateHabit: onCreateHabit,
                    onAddCard: onAddCard,
                    onAddTask: onAddTask
                ) {
                    Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 18, height: 18).foregroundStyle(LGradients.header)
                }
            }
            .padding(.horizontal, 14).padding(.top, 14)

            Divider().overlay(LColors.glassBorder).padding(.horizontal, 10)

            VStack(spacing: 10) {
                ForEach(column.sortedCards) { card in
                    KanbanItemCard(
                        card: card,
                        allReminders: allReminders,
                        allRoutines: allRoutines,
                        allRoutineTasks: allRoutineTasks,
                        allHabits: allHabits,
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

            Divider()

            Button(role: .destructive) {
                deleteColumn()
            } label: {
                Label("Delete Column", systemImage: "trash")
            }
        }
    }

    private func deleteCard(_ card: KanbanCard) { modelContext.delete(card); try? modelContext.save() }

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
        for (i, c) in (column.cards ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() { c.sortOrder = i }
        for (i, c) in (targetColumn.cards ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() { c.sortOrder = i }
        try? modelContext.save()
    }
}

// MARK: - KanbanItemCard

struct KanbanItemCard: View {
    let card: KanbanCard
    let allReminders: [LureliaReminder]
    let allRoutines: [LureliaRoutine]
    let allRoutineTasks: [LureliaRoutineTask]
    let allHabits: [LureliaHabit]
    let columnAccent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    var body: some View {
        if let reminder = reminder {
            NavigationLink(value: reminder.id) {
                KanbanReminderCard(
                    reminder: reminder,
                    accent: columnAccent,
                    onDelete: onDelete,
                    onComplete: onComplete
                )
            }
            .buttonStyle(.plain)
        } else if let routine = routine {
            NavigationLink(value: routine.id) {
                KanbanRoutineCard(
                    routine: routine,
                    accent: columnAccent,
                    onDelete: onDelete
                )
            }
            .buttonStyle(.plain)
        } else if let routineTask = routineTask {
            NavigationLink(value: routineTask.id) {
                KanbanRoutineTaskCard(
                    task: routineTask,
                    accent: columnAccent,
                    onDelete: onDelete
                )
            }
            .buttonStyle(.plain)
        } else if let habit = habit {
            NavigationLink(value: habit.id) {
                KanbanHabitCard(
                    habit: habit,
                    accent: columnAccent,
                    onDelete: onDelete,
                    onComplete: onComplete
                )
            }
            .buttonStyle(.plain)
        } else {
            orphanCard
        }
    }

    private var reminder: LureliaReminder? {
        guard card.cardType == .reminder else { return nil }
        return allReminders.first { $0.id.uuidString == card.itemID }
    }

    private var routine: LureliaRoutine? {
        guard card.cardType == .routine else { return nil }
        return allRoutines.first { $0.persistentID == card.itemID }
    }

    private var routineTask: LureliaRoutineTask? {
        guard card.cardType == .routineTask else { return nil }
        return allRoutineTasks.first { $0.matchesKanbanItemID(card.itemID) }
    }

    private var habit: LureliaHabit? {
        guard card.cardType == .habit else { return nil }
        return allHabits.first { $0.matchesKanbanItemID(card.itemID) }
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

// MARK: - Kanban Routine Card

struct KanbanRoutineCard: View {
    @Bindable var routine: LureliaRoutine
    let accent: Color
    let onDelete: () -> Void

    private var progressText: String {
        let total = routine.sortedTasks.count
        guard total > 0 else { return "No tasks" }
        return "\(routine.completedTaskCount)/\(total) done"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 36, height: 36)

                LureliaIconView(iconId: routine.icon, size: 19)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(routine.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    badge(routine.scheduleEnabled ? routine.formattedTimeRange : "Ready")
                    badge(progressText)
                }
            }

            Spacer(minLength: 8)
            deleteButton
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
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
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
}

// MARK: - Kanban Routine Task Card

struct KanbanRoutineTaskCard: View {
    @Bindable var task: LureliaRoutineTask
    let accent: Color
    let onDelete: () -> Void

    private var statusText: String {
        if task.isCompleted { return "Completed" }
        if task.isSkipped { return "Skipped" }
        return task.hasDueTime ? task.formattedDueTime : "Pending"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 36, height: 36)

                LureliaIconView(iconId: task.icon, size: 19)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(task.isPending ? LColors.textPrimary : LColors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let routineName = task.routine?.name, !routineName.isEmpty {
                        badge(routineName)
                    }
                    badge(statusText)
                }
            }

            Spacer(minLength: 8)
            deleteButton
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
        .opacity(task.isPending ? 1 : 0.72)
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
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
}

// MARK: - Kanban Habit Card

struct KanbanHabitCard: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var habit: LureliaHabit
    let accent: Color
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var todaysLog: LureliaHabitLog? {
        habit.log(on: Date())
    }

    private var todaysSkip: LureliaHabitSkip? {
        habit.skip(on: Date())
    }

    private var statusText: String {
        if habit.isCompletedToday { return "Completed" }
        if todaysSkip != nil { return "Skipped" }
        if let next = nextFireToday {
            return next <= Date() ? "Due Now" : "Soon"
        }
        return "\(habit.todaysCount)/\(habit.target)"
    }

    private var nextFireToday: Date? {
        habit.fireDates(on: Date()).first { fireDate in
            fireDate >= Date() || !habit.isCompletedToday
        }
    }

    private var scheduleText: String {
        let dates = habit.fireDates(on: Date())
        guard let first = dates.first else { return "Flexible" }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        if dates.count == 1 {
            return formatter.string(from: first)
        }

        return "\(formatter.string(from: first)) +\(dates.count - 1)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 36, height: 36)

                LureliaIconView(iconId: habit.iconName ?? "flame", size: 19)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(habit.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle((habit.isArchived || habit.isCompletedToday || todaysSkip != nil) ? LColors.textSecondary : LColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    badge(scheduleText)
                    badge(statusText)
                    badge("\(habit.todaysCount)/\(habit.target)")
                }
            }

            Spacer(minLength: 8)
            deleteButton
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
        .opacity((habit.isArchived || habit.isCompletedToday || todaysSkip != nil) ? 0.72 : 1)
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1))
    }

    private var completionButton: some View {
        Button {
            quickLog()
        } label: {
            ZStack {
                Circle()
                    .fill(habit.isCompletedToday ? AnyShapeStyle(accent) : AnyShapeStyle(Color.clear))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(accent.opacity(0.85), lineWidth: 2))

                if habit.isCompletedToday {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(habit.isCompletedToday || todaysSkip != nil)
        .opacity((habit.isCompletedToday || todaysSkip != nil) ? 0.55 : 1)
    }

    private var skipButton: some View {
        Button {
            toggleSkip()
        } label: {
            Image("skipwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(LColors.glassSurface, in: Circle())
                .overlay(Circle().strokeBorder(LColors.glassBorder.opacity(0.75), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(habit.isCompletedToday)
        .opacity(habit.isCompletedToday ? 0.55 : 1)
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

    private func quickLog() {
        let cap = habit.target

        if let existingSkip = todaysSkip {
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter {
                $0.persistentModelID != existingSkip.persistentModelID
            }
        }

        if let existing = todaysLog {
            if existing.count < cap {
                existing.count = min(cap, existing.count + 1)
                existing.updatedAt = Date()
                habit.updatedAt = Date()
            }
        } else {
            let log = LureliaHabitLog(habit: habit, dayStart: todayStart, count: 1)
            modelContext.insert(log)
            habit.logs = (habit.logs ?? []) + [log]
            habit.updatedAt = Date()
        }

        try? modelContext.save()
        LureliaWidgetReloads.reloadAll()

        if habit.isCompletedToday {
            onComplete?()
        }
    }

    private func toggleSkip() {
        if let existing = todaysSkip {
            modelContext.delete(existing)
            habit.skips = (habit.skips ?? []).filter {
                $0.persistentModelID != existing.persistentModelID
            }
            habit.updatedAt = Date()
            try? modelContext.save()
            LureliaWidgetReloads.reloadAll()
            return
        }

        guard todaysLog?.count ?? 0 == 0 else { return }

        let skip = LureliaHabitSkip(habit: habit, dayStart: todayStart)
        modelContext.insert(skip)
        habit.skips = (habit.skips ?? []) + [skip]
        habit.updatedAt = Date()

        try? modelContext.save()
        LureliaWidgetReloads.reloadAll()
    }
}

// MARK: - Kanban Routine Task Source Column

struct KanbanRoutineTaskSourceColumnView: View {
    let board: KanbanBoard
    let routines: [LureliaRoutine]
    let boardAccent: Color
    let onAddRoutineTask: (LureliaRoutineTask, KanbanColumn) -> Void
    let onAddNewTask: (LureliaRoutine, KanbanColumn) -> Void

    /// Observed so this "already pinned" filter reflects every board's
    /// cards, not just this board's. Prevents the same routine task from
    /// being pinnable on multiple boards.
    @Query private var allBoards: [KanbanBoard]

    private var pinnedRoutineTaskIDs: Set<String> {
        // Broken into explicit steps so the type-checker doesn't blow up
        // on the nested flatMap chain (Swift chokes on deep inference in
        // one expression).
        let allTasks: [LureliaRoutineTask] = routines.flatMap { $0.sortedTasks }
        let allColumns: [KanbanColumn] = allBoards.flatMap { $0.columns ?? [] }
        let allCards: [KanbanCard] = allColumns.flatMap { $0.cards ?? [] }
        let routineTaskCards: [KanbanCard] = allCards.filter { $0.cardType == .routineTask }

        var result: Set<String> = []
        for card in routineTaskCards {
            let match = allTasks.first { $0.matchesKanbanItemID(card.itemID) }
            result.insert(match?.kanbanItemID ?? card.itemID)
        }
        return result
    }

    private var availableRoutines: [LureliaRoutine] {
        routines
            .filter { !availableTasks(for: $0).isEmpty }
            .sorted { $0.name < $1.name }
    }

    private var availableTaskCount: Int {
        availableRoutines.reduce(0) { $0 + availableTasks(for: $1).count }
    }

    private func availableTasks(for routine: LureliaRoutine) -> [LureliaRoutineTask] {
        routine.sortedTasks.filter { !pinnedRoutineTaskIDs.contains($0.kanbanItemID) }
    }

    var body: some View {
        if availableTaskCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image("repeatfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(boardAccent)

                    Text("Routine Tasks")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                }

                Spacer()

                Text("\(availableTaskCount)")
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

            VStack(spacing: 12) {
                ForEach(availableRoutines) { routine in
                    routineSection(routine)
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

    private func routineSection(_ routine: LureliaRoutine) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 34, height: 34)

                    LureliaIconView(iconId: routine.icon, size: 16)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(1)

                    Text(routine.scheduleEnabled ? routine.formattedTimeRange : "\(availableTasks(for: routine).count) task\(availableTasks(for: routine).count == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                addNewTaskMenu(for: routine)
            }

            VStack(spacing: 7) {
                ForEach(availableTasks(for: routine), id: \.kanbanItemID) { task in
                    routineTaskSourceRow(task)
                }
            }
        }
        .padding(12)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(boardAccent.opacity(0.18), lineWidth: 1)
        }
    }

    private func routineTaskSourceRow(_ task: LureliaRoutineTask) -> some View {
        HStack(alignment: .center, spacing: 9) {
            ZStack {
                Circle()
                    .fill(boardAccent.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(boardAccent.opacity(0.28), lineWidth: 1))

                LureliaIconView(iconId: task.icon, size: 13)
                    .foregroundStyle(boardAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(2)

                Text(task.hasDueTime ? task.formattedDueTime : "No due time")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            addTaskMenu(task)
        }
        .padding(9)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(LColors.glassBorder.opacity(0.7), lineWidth: 1)
        }
        .contextMenu {
            taskColumnMenu(task)
        }
    }

    private func addTaskMenu(_ task: LureliaRoutineTask) -> some View {
        Menu {
            taskColumnMenu(task)
        } label: {
            Image("addwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(boardAccent)
                .frame(width: 30, height: 30)
                .background(boardAccent.opacity(0.12), in: Circle())
                .overlay(Circle().strokeBorder(boardAccent.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func addNewTaskMenu(for routine: LureliaRoutine) -> some View {
        Menu {
            if board.sortedColumns.isEmpty {
                Text("Add a column first")
            } else {
                ForEach(board.sortedColumns) { column in
                    Button {
                        onAddNewTask(routine, column)
                    } label: {
                        Label("Add to \(column.name)", systemImage: "plus")
                    }
                }
            }
        } label: {
            Image("addwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(boardAccent)
                .frame(width: 30, height: 30)
                .background(LColors.glassSurface, in: Circle())
                .overlay(Circle().strokeBorder(LColors.glassBorder.opacity(0.75), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func taskColumnMenu(_ task: LureliaRoutineTask) -> some View {
        if board.sortedColumns.isEmpty {
            Text("Add a column first")
        } else {
            ForEach(board.sortedColumns) { column in
                Button {
                    onAddRoutineTask(task, column)
                } label: {
                    Label("Add to \(column.name)", systemImage: "arrow.right.circle")
                }
            }
        }
    }
}

// MARK: - Kanban Habit Source Column

struct KanbanHabitSourceColumnView: View {
    let board: KanbanBoard
    let habits: [LureliaHabit]
    let boardAccent: Color
    let onAddHabit: (LureliaHabit, KanbanColumn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image("flame")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(boardAccent)

                    Text("Habits")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                }

                Spacer()

                Text("\(habits.count)")
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
                ForEach(habits) { habit in
                    habitSourceRow(habit)
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

    private func habitSourceRow(_ habit: LureliaHabit) -> some View {
        HStack(alignment: .center, spacing: 9) {
            ZStack {
                Circle()
                    .fill(boardAccent.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(boardAccent.opacity(0.28), lineWidth: 1))

                LureliaIconView(iconId: habit.iconName ?? "flame", size: 13)
                    .foregroundStyle(boardAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(2)

                Text(habitScheduleSummary(habit))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            addHabitMenu(habit)
        }
        .padding(9)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(LColors.glassBorder.opacity(0.7), lineWidth: 1)
        }
        .contextMenu {
            habitColumnMenu(habit)
        }
    }

    private func addHabitMenu(_ habit: LureliaHabit) -> some View {
        Menu {
            habitColumnMenu(habit)
        } label: {
            Image("addwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(boardAccent)
                .frame(width: 30, height: 30)
                .background(boardAccent.opacity(0.12), in: Circle())
                .overlay(Circle().strokeBorder(boardAccent.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func habitColumnMenu(_ habit: LureliaHabit) -> some View {
        if board.sortedColumns.isEmpty {
            Text("Add a column first")
        } else {
            ForEach(board.sortedColumns) { column in
                Button {
                    onAddHabit(habit, column)
                } label: {
                    Label("Add to \(column.name)", systemImage: "arrow.right.circle")
                }
            }
        }
    }

    private func habitScheduleSummary(_ habit: LureliaHabit) -> String {
        let targetText = "\(habit.target)x/day"
        let weekdayText = habit.activeWeekdays.count >= 7 ? "Every day" : "\(habit.activeWeekdays.count) days/week"
        return "\(targetText) • \(weekdayText)"
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
            await ReminderActionManager.completeReminderOccurrence(
                reminder,
                in: modelContext
            )

            await MainActor.run {
                onComplete?()
            }
        }
    }

    private func skipReminderOccurrence() {
        Task {
            await ReminderActionManager.skipReminderOccurrence(
                reminder,
                in: modelContext
            )
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
                            .foregroundStyle(LColors.textPrimary)
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
                                .strokeBorder(LColors.glassBorder, lineWidth: 1.1)
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
                            .strokeBorder(LColors.glassBorder, lineWidth: 1.1)
                    )
                }

                Button { save() } label: {
                    HStack(spacing: 10) {
                        Image(isEditing ? "checkwavy" : "addwavy").renderingMode(.template).resizable().scaledToFit().frame(width: 14, height: 14).foregroundStyle(.white)
                        Text(isEditing ? "Save Changes" : "Add Column").font(.system(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(LColors.textPrimary).frame(maxWidth: .infinity).frame(height: 60)
                    .background { LureliaNeutralGlassSurface(cornerRadius: 22) }
                    .shadow(color: LColors.neutralPearl.opacity(0.10), radius: 18, y: 10)
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
