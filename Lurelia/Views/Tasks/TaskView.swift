//
//  TaskView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var taskManager = TaskManager.shared
    
    @Query private var tasks: [LureliaTask]
    @Query private var settings: [UserSettings]
    
    @State private var showDailyPicker = false
    @State private var showAddMore = false
    @State private var showCreateTask = false
    @State private var hasCheckedDailyPickerOnAppear = false
    
    var userSettings: UserSettings? {
        settings.first
    }
    
    var userCategories: [String] {
        let selected = userSettings?.selectedCategories ?? []
        
        if selected.isEmpty {
            return LureliaTaskBank.categories
        }
        
        return selected.sorted()
    }
    
    var autoClearTasks: Bool {
        true
    }
    
    var visibleTasks: [LureliaTask] {
        taskManager.visibleTasks(
            from: tasks,
            autoClearTasks: autoClearTasks
        )
    }
    
    var tasksByCategory: [(category: String, tasks: [LureliaTask])] {
        userCategories.compactMap { category in
            let categoryTasks = currentVisibleTasks.filter { $0.category == category }
            guard !categoryTasks.isEmpty else { return nil }
            return (category: category, tasks: categoryTasks)
        }
    }

    var currentVisibleTasks: [LureliaTask] {
        if autoClearTasks {
            return tasks.filter { task in
                task.isActive &&
                task.isSelectedToday &&
                isCurrentDailyTask(task)
            }
        }

        return visibleTasks
    }

    private var dailySelectionSignature: String {
        tasks
            .map { task in
                "\(task.id.uuidString)-\(task.isActive)-\(task.isSelectedToday)-\(task.selectedDate?.timeIntervalSince1970 ?? 0)"
            }
            .joined(separator: "|")
    }
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // MARK: - Header
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tasks")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text(autoClearTasks ? "Today’s selected tasks" : "Your active task list")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button {
                            showCreateTask = true
                        } label: {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(LGradients.header)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // MARK: - Task Bank Button
                    
                    Button {
                        if autoClearTasks {
                            clearStaleDailyTasks()

                            if shouldPresentDailyPickerNow() {
                                presentDailyPicker()
                            } else {
                                showDailyPicker = false
                                showAddMore = true
                            }
                        } else {
                            showAddMore = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text(tasksByCategory.isEmpty ? "Choose Tasks From Bank" : "Add From Task Bank")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.85).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.85).opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    
                    // MARK: - Task Categories / Empty State
                    
                    if tasksByCategory.isEmpty {
                        LureliaEmptyTasksView {
                            if autoClearTasks {
                                presentDailyPicker()
                            } else {
                                showAddMore = true
                            }
                        } createCustomTask: {
                            showCreateTask = true
                        }
                        .padding(.top, 28)
                        .padding(.horizontal, 32)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(tasksByCategory, id: \.category) { group in
                                LureliaTaskCategoryCard(
                                    category: group.category,
                                    tasks: group.tasks
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                        .frame(height: 110)
                }
            }
        }
        .sheet(isPresented: $showDailyPicker) {
            DailyTaskPickerView(isAddingMore: false) {
                showDailyPicker = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showAddMore) {
            DailyTaskPickerView(isAddingMore: true) {
                showAddMore = false
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreateTask) {
            CreateCustomTaskView()
        }
        .onAppear {
            guard !hasCheckedDailyPickerOnAppear else { return }
            hasCheckedDailyPickerOnAppear = true
            prepareTasksOnAppear()
        }
        .onChange(of: autoClearTasks) { _, newValue in
            guard newValue else { return }
            prepareTasksOnAppear()
        }
        .onChange(of: dailySelectionSignature) {
            guard autoClearTasks else { return }
            presentDailyPickerIfNeeded()
        }
        .onChange(of: taskManager.dailyPickerRequestID) {
            guard autoClearTasks else { return }
            showAddMore = false
            presentDailyPicker()
        }
    }
    
    // MARK: - Prepare
    private func prepareTasksOnAppear() {
        print("[DAILY] prepareTasksOnAppear — autoClearTasks=\(autoClearTasks) userCategories=\(userCategories.count) tasks=\(tasks.count) settings=\(settings.count)")
        guard !userCategories.isEmpty else {
            print("[DAILY] BAILED — userCategories is empty")
            return
        }

        backfillTaskCoinRewardsIfNeeded()

        if autoClearTasks {
            presentDailyPickerIfNeeded()
        } else {
            print("[DAILY] autoClearTasks is false, skipping daily picker path")
            if visibleTasks.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showAddMore = true
                }
            }
        }
        taskManager.prepareTasksForNewDay(
            tasks: tasks,
            autoClearTasks: autoClearTasks,
            context: context
        )
    }

    private func backfillTaskCoinRewardsIfNeeded() {
        var didChange = false

        for task in tasks where task.coinReward == 0 {
            guard let bankItem = LureliaTaskBank.allItems.first(where: { item in
                item.title == task.title && item.category == task.category
            }) else { continue }

            guard bankItem.coinReward > 0 else { continue }
            task.coinReward = bankItem.coinReward
            task.updatedAt = Date()
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }

    private func presentDailyPickerIfNeeded() {
        print("[DAILY] presentDailyPickerIfNeeded — autoClearTasks=\(autoClearTasks) showDailyPicker=\(showDailyPicker)")
        guard autoClearTasks else {
            print("[DAILY] BAILED — autoClearTasks is false")
            return
        }

        let should = taskManager.shouldShowDailyPicker(
            tasks: tasks,
            autoClearTasks: autoClearTasks,
            context: context
        )
        print("[DAILY] shouldShowDailyPicker=\(should) tasks=\(tasks.count) selectedToday=\(tasks.filter { $0.isSelectedToday }.count)")
        if should {
            taskManager.resetPickedToday()
            presentDailyPicker()
        }
    }

    private func shouldPresentDailyPickerNow() -> Bool {
        currentVisibleTasks.isEmpty
    }

    private func presentDailyPicker() {
        print("[DAILY] presentDailyPicker called — showDailyPicker=\(showDailyPicker) showAddMore=\(showAddMore)")
        showAddMore = false

        DispatchQueue.main.async {
            print("[DAILY] async block — showDailyPicker=\(self.showDailyPicker)")
            guard !self.showDailyPicker else {
                print("[DAILY] BAILED — showDailyPicker already true")
                return
            }
            self.showDailyPicker = true
            print("[DAILY] showDailyPicker SET TO TRUE")
        }
    }

    private func clearStaleDailyTasks() {
        var didChange = false

        for task in tasks {
            guard task.isSelectedToday else { continue }

            if !isCurrentDailyTask(task) {
                task.isSelectedToday = false
                task.isCompleted = false
                task.updatedAt = Date()
                didChange = true
            }
        }

        if didChange {
            try? context.save()
        }
    }

    private func isCurrentDailyTask(_ task: LureliaTask) -> Bool {
        guard let selectedDate = task.selectedDate else {
            return false
        }

        return dailyTaskDayKey(for: selectedDate) == dailyTaskDayKey(for: Date())
    }

    private func dailyTaskDayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

// MARK: - Empty State

struct LureliaEmptyTasksView: View {
    let chooseFromBank: () -> Void
    let createCustomTask: () -> Void
    
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 54))
                .foregroundStyle(LGradients.header)
            
            VStack(spacing: 8) {
                Text("No Tasks Yet")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Choose tasks from the bank or create your own custom task to begin building your daily structure.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 10) {
                Button {
                    chooseFromBank()
                } label: {
                    Text("Choose From Task Bank")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.adaptivePrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LGradients.header)
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    createCustomTask()
                } label: {
                    Text("Create Custom Task")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LColors.glassSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Task Category Card

struct LureliaTaskCategoryCard: View {
    let category: String
    let tasks: [LureliaTask]
    @StateObject private var taskManager = TaskManager.shared
    @State private var isExpanded = false
    
    var categoryInfo: (icon: String, description: String) {
        switch category {
        case "Health":
            return ("health", "Medication, hydration, sleep, and body care")
        case "Fitness":
            return ("weight", "Movement, stretching, exercise, and physical strength")
        case "Home":
            return ("houseoutline", "Cleaning, meals, chores, and home maintenance")
        case "Work":
            return ("casemagic", "Work tasks, focus sessions, and admin upkeep")
        case "Study":
            return ("book.fill", "Lessons, notes, review, and learning sessions")
        case "Care":
            return ("heartfill", "Supportive tasks for comfort and emotional steadiness")
        case "Spirituality":
            return ("crystalball", "Rituals, devotion, reflection, and spiritual practice")
        case "Relationships":
            return ("chatsparkle", "Loved ones, pets, connection, and quality time")
        case "Finances":
            return ("walletfill", "Bills, budgeting, balances, and spending check-ins")
        case "Intention":
            return ("sparkle", "Daily focus, reflection, and mindful direction")
        case "Productivity":
            return ("bolt", "Planning, organizing, focus, and follow-through")
        case "Habits":
            return ("flame", "Recurring actions and consistency builders")
        case "Hygiene":
            return ("towel", "Personal care, grooming, and hygiene routines")
        case "Routines":
            return ("clock.arrow.circlepath", "Repeatable flows that can be started and completed")
        case "Creativity":
            return ("artboard", "Creative sessions, design, writing, and ideas")
        default:
            return ("star.circle.fill", "Tasks for this part of your life")
        }
    }
    
    var progress: (done: Int, total: Int) {
        taskManager.progress(
            for: category,
            tasks: tasks
        )
    }
    
    var progressPercent: Double {
        guard progress.total > 0 else { return 0 }
        return Double(progress.done) / Double(progress.total)
    }
    
    var sortedTasks: [LureliaTask] {
        tasks.sorted {
            if $0.isCompleted == $1.isCompleted {
                return $0.title < $1.title
            }
            
            return !$0.isCompleted && $1.isCompleted
        }
    }
    
    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
            
            // MARK: - Collapsed Header
            
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                        Group {
                            if UIImage(named: categoryInfo.icon) != nil {
                                Image(categoryInfo.icon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            } else {
                                Image(systemName: categoryInfo.icon)
                                    .font(.system(size: 20))
                            }
                        }
                        .foregroundStyle(LGradients.header)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.85).opacity(0.95),
                                                    Color.white.opacity(0.85).opacity(0.95),
                                                    Color.white.opacity(0.45)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.2
                                        )
                                )
                        )
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text(categoryInfo.description)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text("\(progress.done)/\(progress.total)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(isExpanded ? "chevup" : "chevdown")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Progress Bar
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.1))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LGradients.header)
                                .frame(
                                    width: geo.size.width * progressPercent,
                                    height: 6
                                )
                                .animation(.spring(duration: 0.4), value: progressPercent)
                        }
                    }
                    .frame(height: 6)
                }
            
            // MARK: - Expanded Tasks
            
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.white.opacity(0.09))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    ForEach(sortedTasks) { task in
                        LureliaTaskRow(task: task)
                        
                        if task.id != sortedTasks.last?.id {
                            Rectangle()
                                .fill(.white.opacity(0.07))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
           }
        }
    }
}

// MARK: - Task Row

struct LureliaTaskRow: View {
    let task: LureliaTask

    @Environment(\.modelContext) private var context
    @StateObject private var taskManager = TaskManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingRemoveAction = false

    var subtitleText: String {
        if let notes = task.trimmedNotes {
            return notes
        }
        return task.isCustom ? "Custom task" : "Task bank"
    }

    var statusLabel: String {
        task.isCustom ? "Custom" : "Task Bank"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                removeFromTaskList()
            } label: {
                ZStack {
                    Circle()
                        .fill(LGradients.header)
                        .frame(width: 38, height: 38)

                    Image("xmarkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                }
                .frame(width: 76, height: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .opacity(isShowingRemoveAction ? 1 : 0)

            taskRowContent
                .offset(x: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 32)
                        .onChanged { value in
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)

                            guard horizontalAmount > 65 else { return }
                            guard horizontalAmount > verticalAmount * 2.4 else { return }
                            guard value.translation.width < 0 else { return }

                            dragOffset = max(value.translation.width, -86)
                            isShowingRemoveAction = dragOffset < -30
                        }
                        .onEnded { value in
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)

                            guard horizontalAmount > 65,
                                  horizontalAmount > verticalAmount * 2.4 else {
                                withAnimation(.spring(duration: 0.28, bounce: 0.12)) {
                                    dragOffset = 0
                                    isShowingRemoveAction = false
                                }
                                return
                            }

                            withAnimation(.spring(duration: 0.28, bounce: 0.12)) {
                                if value.translation.width < -110 {
                                    dragOffset = -78
                                    isShowingRemoveAction = true
                                } else {
                                    dragOffset = 0
                                    isShowingRemoveAction = false
                                }
                            }
                        }
                )
        }
        .clipShape(Rectangle())
        .animation(.spring(duration: 0.25), value: task.isCompleted)
    }

    private var taskRowContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        task.isCompleted || task.isMarkedIncomplete
                        ? AnyShapeStyle(LGradients.header)
                        : AnyShapeStyle(Color.clear)
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(
                                task.isCompleted || task.isMarkedIncomplete ? Color.clear : Color.white.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )

                if task.isMarkedIncomplete {
                    Image("xmarkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(.white)
                } else if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    task.isMarkedIncomplete = true
                    task.isCompleted = false
                    task.updatedAt = Date()
                    try? context.save()
                }
            }
            .onTapGesture(count: 1) {
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    task.isMarkedIncomplete = false
                    toggleComplete()
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 10) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(task.isCompleted || task.isMarkedIncomplete ? .white.opacity(0.4) : .white)
                        .strikethrough(task.isCompleted || task.isMarkedIncomplete, color: .white.opacity(0.3))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if task.coinReward > 0 {
                        HStack(spacing: 4) {
                            Image("sparkle")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)

                            Text("+\(task.coinReward)")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Color(lureliaHex: "#6a1eff"))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            Capsule()
                                .fill(Color(lureliaHex: "#6a1eff").opacity(0.14))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(lureliaHex: "#6a1eff").opacity(0.55), lineWidth: 1)
                        )
                    }
                }

                HStack(spacing: 6) {
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.85).opacity(0.12))
                        .clipShape(Capsule())

                    Text("· \(subtitleText)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    func toggleComplete() {
        task.isMarkedIncomplete = false
        taskManager.toggle(task: task, context: context)
    }

    func removeFromTaskList() {
        task.isSelectedToday = false
        task.isCompleted = false
        task.isMarkedIncomplete = false
        task.updatedAt = Date()
        dragOffset = 0
        isShowingRemoveAction = false
        try? context.save()
    }

}

