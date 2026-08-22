//
//  DailyTaskPickerView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit

struct DailyTaskPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allTasks: [LureliaTask]
    @Query private var settings: [UserSettings]
    
    let isAddingMore: Bool
    let onComplete: () -> Void
    
    @State private var currentCategoryIndex = 0
    @State private var selectedTaskIDs: Set<String> = []
    
    var userSettings: UserSettings? {
        settings.first
    }
    
    var userCategories: [String] {
        let selected = userSettings?.selectedCategories ?? []
        
        let base = selected.isEmpty ? LureliaTaskBank.categories : selected.sorted()
        
        return base.filter { $0 != "Routines" }
    }
    
    var currentCategory: String {
        guard currentCategoryIndex < userCategories.count else { return "" }
        return userCategories[currentCategoryIndex]
    }
    
    var currentCategoryTasks: [LureliaTaskBankItem] {
        LureliaTaskBank.items(for: currentCategory)
            .sorted { $0.title < $1.title }
    }
    
    var currentCategorySelected: [String] {
        selectedTaskIDs.filter { id in
            currentCategoryTasks.contains { $0.id == id }
        }
    }
    
    var canAdvance: Bool {
        !currentCategorySelected.isEmpty
    }
    
    var isLastCategory: Bool {
        currentCategoryIndex == userCategories.count - 1
    }
    
    var progress: Double {
        guard !userCategories.isEmpty else { return 0 }
        return Double(currentCategoryIndex + 1) / Double(userCategories.count)
    }
    
    var categoryInfo: (icon: String, description: String) {
        switch currentCategory {
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
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            VStack(spacing: 0) {
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                VStack(spacing: 8) {
                    HStack {
                        Text(isAddingMore ? "Add More Tasks" : "Choose Tasks")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("\(currentCategoryIndex + 1) of \(userCategories.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.1))
                                .frame(height: 5)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LGradients.header)
                                .frame(
                                    width: geo.size.width * progress,
                                    height: 5
                                )
                                .animation(.spring(duration: 0.4), value: currentCategoryIndex)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 24)
                
                HStack(spacing: 14) {
                    Group {
                        if UIImage(named: categoryInfo.icon) != nil {
                            Image(categoryInfo.icon)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                        } else {
                            Image(systemName: categoryInfo.icon)
                                .font(.system(size: 22))
                        }
                    }
                    .foregroundStyle(LGradients.header)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentCategory)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text(categoryInfo.description)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.85))
                    
                    Text("Pick at least one task from this category")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    
                    Spacer()
                    
                    if !currentCategorySelected.isEmpty {
                        Text("\(currentCategorySelected.count) selected")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(currentCategoryTasks) { task in
                            let isSelected = selectedTaskIDs.contains(task.id)
                            
                            GlassCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                isSelected
                                                ? AnyShapeStyle(LGradients.header)
                                                : AnyShapeStyle(Color.clear)
                                            )
                                            .frame(width: 26, height: 26)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        isSelected ? Color.clear : Color.white.opacity(0.3),
                                                        lineWidth: 1.5
                                                    )
                                            )
                                        
                                        if isSelected {
                                            Image("checkwavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 10, height: 10)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.leading)
                                        
                                        if let notes = task.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.45))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        Text(task.category)
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.85))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.85).opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    
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
                                        .foregroundStyle(Color(lureliaHex: "#f1d38a"))
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(
                                            Capsule()
                                                .fill(Color(lureliaHex: "#4a3412").opacity(0.42))
                                        )
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color(lureliaHex: "#d4a63c").opacity(0.55), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.2)) {
                                    if isSelected {
                                        selectedTaskIDs.remove(task.id)
                                    } else {
                                        selectedTaskIDs.insert(task.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                
                Spacer(minLength: 0)
                
                VStack(spacing: 12) {
                    if currentCategoryIndex > 0 {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                currentCategoryIndex -= 1
                            }
                        } label: {
                            Text("Back")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    
                    LureliaGradientButton(
                        title: isLastCategory ? "Add Tasks" : "Next",
                        action: advance
                    )
                    .disabled(!canAdvance)
                    .opacity(canAdvance ? 1 : 0.45)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            LureliaDailyTaskStore.clearOldDailyTaskSelections(in: allTasks, context: context)
            if isAddingMore {
                let selectedBankIDs = LureliaTaskBank.allItems.compactMap { bankTask -> String? in
                    allTasks.contains { existingTask in
                        existingTask.isActive &&
                        existingTask.isSelectedToday &&
                        (
                            existingTask.stableTaskID == bankTask.id ||
                            (
                                existingTask.title == bankTask.title &&
                                existingTask.category == bankTask.category
                            )
                        )
                    } ? bankTask.id : nil
                }
                selectedTaskIDs = Set(selectedBankIDs)
            }
        }
    }
    
    func advance() {
        guard canAdvance else { return }
        
        if isLastCategory {
            commitSelections()
            onComplete()
            dismiss()
        } else {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                currentCategoryIndex += 1
            }
        }
    }
    
    func commitSelections() {
        let selectedBankTasks = LureliaTaskBank.allItems.filter {
            selectedTaskIDs.contains($0.id)
        }
        
        if !isAddingMore {
            for task in allTasks {
                task.isSelectedToday = false
            }
        }
        
        for bankTask in selectedBankTasks {
            if let existingTask = allTasks.first(where: {
                $0.stableTaskID == bankTask.id ||
                (
                    $0.title == bankTask.title &&
                    $0.category == bankTask.category
                )
            }) {
                existingTask.stableTaskID = bankTask.id
                existingTask.coinReward = bankTask.coinReward
                existingTask.isSelectedToday = true
                existingTask.selectedDate = Date()
                existingTask.isActive = true
                existingTask.updatedAt = Date()
            } else {
                let newTask = LureliaTask(
                    title: bankTask.title,
                    category: bankTask.category,
                    notes: bankTask.notes,
                    coinReward: bankTask.coinReward
                )
                
                newTask.stableTaskID = bankTask.id
                newTask.isSelectedToday = true
                newTask.selectedDate = Date()
                newTask.isActive = true
                
                context.insert(newTask)
            }
        }
        
        try? context.save()
        LureliaDailyTaskStore.markPickedToday()
    }
}

// MARK: - Daily Task Store

enum LureliaDailyTaskStore {
    private static let pickedDayKey = "lurelia_daily_tasks_picked_day_key"

    static func markPickedToday() {
        UserDefaults.standard.set(currentDayKey(), forKey: pickedDayKey)
    }

    static func hasPickedToday() -> Bool {
        guard let savedDayKey = UserDefaults.standard.string(forKey: pickedDayKey) else {
            return false
        }

        if savedDayKey == currentDayKey() {
            return true
        }

        resetPickedToday()
        return false
    }

    static func resetPickedToday() {
        UserDefaults.standard.removeObject(forKey: pickedDayKey)
    }

    static func clearOldDailyTaskSelections(
        in tasks: [LureliaTask],
        context: ModelContext
    ) {
        let activeDayKey = currentDayKey()
        var didChange = false
        var hasCurrentDaySelection = false

        for task in tasks {
            guard task.isSelectedToday else { continue }

            guard let selectedDate = task.selectedDate else {
                task.isSelectedToday = false
                task.isCompleted = false
                task.updatedAt = Date()
                didChange = true
                continue
            }

            if dayKey(for: selectedDate) == activeDayKey {
                hasCurrentDaySelection = true
            } else {
                task.isSelectedToday = false
                task.isCompleted = false
                task.updatedAt = Date()
                didChange = true
            }
        }

        if !hasCurrentDaySelection {
            resetPickedToday()
        }

        if didChange {
            try? context.save()
        }
    }

    static func shouldShowDailyPicker(for tasks: [LureliaTask]) -> Bool {
        let activeDayKey = currentDayKey()

        let hasCurrentDaySelection = tasks.contains { task in
            guard task.isActive,
                  task.isSelectedToday,
                  let selectedDate = task.selectedDate else {
                return false
            }

            return dayKey(for: selectedDate) == activeDayKey
        }

        if !hasCurrentDaySelection {
            resetPickedToday()
            return true
        }

        return !hasPickedToday()
    }

    private static func currentDayKey() -> String {
        dayKey(for: Date())
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

// MARK: - Gradient Button

struct LureliaGradientButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.adaptivePrimaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LGradients.header)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(
                    color: Color.white.opacity(0.85).opacity(0.25),
                    radius: 18,
                    y: 10
                )
        }
        .buttonStyle(.plain)
    }
}
