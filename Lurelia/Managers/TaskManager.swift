//
//  TaskManager.swift
//  Lurelia
//

import Foundation
import SwiftData
import Combine

@MainActor
final class TaskManager: ObservableObject {
    static let shared = TaskManager()
    @Published var dailyPickerRequestID = UUID()
    
    private let dailyPickerDayKey = "lurelia_daily_tasks_picked_day_key"
    private let legacyDailyPickerDateKey = "lurelia_daily_tasks_picked_date"
    
    private init() {}
    
    // MARK: - Daily Picker Tracking
    
    func markPickedToday() {
        UserDefaults.standard.set(currentDayKey(), forKey: dailyPickerDayKey)
    }

    func hasPickedToday() -> Bool {
        guard let savedDayKey = UserDefaults.standard.string(forKey: dailyPickerDayKey) else {
            return false
        }
        
        if savedDayKey == currentDayKey() {
            return true
        }
        
        resetPickedToday()
        return false
    }

    func resetPickedToday() {
        UserDefaults.standard.removeObject(forKey: dailyPickerDayKey)
        UserDefaults.standard.removeObject(forKey: legacyDailyPickerDateKey)
    }

    func shouldShowDailyPicker(
        tasks: [LureliaTask],
        autoClearTasks: Bool,
        context: ModelContext
    ) -> Bool {
        guard autoClearTasks else { return false }

        prepareTasksForNewDay(
            tasks: tasks,
            autoClearTasks: autoClearTasks,
            context: context
        )

        let hasCurrentDayTasks = tasks.contains { task in
            task.isActive && isTaskSelectedForToday(task)
        }

        return !hasCurrentDayTasks
    }

    func requestDailyPickerIfNeeded(
        tasks: [LureliaTask],
        autoClearTasks: Bool,
        context: ModelContext
    ) {
        guard shouldShowDailyPicker(
            tasks: tasks,
            autoClearTasks: autoClearTasks,
            context: context
        ) else {
            return
        }

        dailyPickerRequestID = UUID()
    }

    func isTaskSelectedForToday(_ task: LureliaTask) -> Bool {
        guard task.isSelectedToday,
              let selectedDate = task.selectedDate else {
            return false
        }
        
        return dayKey(for: selectedDate) == currentDayKey()
    }
    
    func currentDayKey() -> String {
        dayKey(for: Date())
    }
    
    func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Stable Task Identity
    
    func stableTaskID(
        bankID: String?,
        title: String,
        category: String
    ) -> String {
        if let bankID,
           !bankID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bankID
        }
        
        return fallbackStableTaskID(title: title, category: category)
    }
    
    func applyStableTaskID(
        to task: LureliaTask,
        bankID: String? = nil
    ) {
        let resolvedStableID = stableTaskID(
            bankID: bankID,
            title: task.title,
            category: task.category
        )
        
        if bankID != nil || task.stableTaskID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.stableTaskID = resolvedStableID
            task.updatedAt = Date()
        }
    }
    
    private func fallbackStableTaskID(
        title: String,
        category: String
    ) -> String {
        let normalizedCategory = normalizedStableComponent(category)
        let normalizedTitle = normalizedStableComponent(title)
        return "custom::\(normalizedCategory)::\(normalizedTitle)"
    }
    
    private func normalizedStableComponent(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
    
    // MARK: - Completion
    
    func complete(task: LureliaTask, context: ModelContext) {
        guard !task.isCompleted else { return }
        
        task.markCompleted()
        awardCoinsIfNeeded(for: task, context: context)
        
        try? context.save()
    }
    
    func uncomplete(task: LureliaTask, context: ModelContext) {
        guard task.isCompleted else { return }
        
        task.markIncomplete()
        removeCoinsIfNeeded(for: task, context: context)
        
        try? context.save()
    }
    
    func toggle(task: LureliaTask, context: ModelContext) {
        let wasCompleted = task.isCompleted
        task.toggleCompleted()
        
        if !wasCompleted && task.isCompleted {
            awardCoinsIfNeeded(for: task, context: context)
        } else if wasCompleted && !task.isCompleted {
            removeCoinsIfNeeded(for: task, context: context)
        }
        
        try? context.save()
    }
    
    // MARK: - Coins
    
    private func awardCoinsIfNeeded(for task: LureliaTask, context: ModelContext) {
        guard task.coinReward > 0 else { return }
        
        let userSettings = resolvedUserSettings(context: context)
        userSettings.coinBalance += task.coinReward
        userSettings.updatedAt = Date()
    }
    
    private func removeCoinsIfNeeded(for task: LureliaTask, context: ModelContext) {
        guard task.coinReward > 0 else { return }
        
        let userSettings = resolvedUserSettings(context: context)
        userSettings.coinBalance = max(0, userSettings.coinBalance - task.coinReward)
        userSettings.updatedAt = Date()
    }
    
    private func resolvedUserSettings(context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let newSettings = UserSettings()
        context.insert(newSettings)
        return newSettings
    }
    
    // MARK: - Daily Reset
    
    func prepareTasksForNewDay(
        tasks: [LureliaTask],
        autoClearTasks: Bool,
        context: ModelContext
    ) {
        guard autoClearTasks else { return }
        
        let todayKey = currentDayKey()
        var changed = false
        var hasCurrentSelection = false
        
        for task in tasks {
            applyStableTaskID(to: task)

            guard task.isSelectedToday else { continue }
            
            guard let selectedDate = task.selectedDate else {
                task.resetForNewDay()
                changed = true
                continue
            }
            
            if dayKey(for: selectedDate) == todayKey {
                if task.isActive {
                    hasCurrentSelection = true
                }
            } else {
                task.resetForNewDay()
                changed = true
            }
        }
        
        if !hasCurrentSelection {
            resetPickedToday()
            dailyPickerRequestID = UUID()
        }
        
        if changed {
            try? context.save()
        }
    }
    
    // MARK: - Category Progress
    
    private var autoClearingProgressMode: Bool {
        true
    }

    func progress(
        for category: String,
        tasks: [LureliaTask]
    ) -> (done: Int, total: Int) {
        let categoryTasks = tasks.filter {
            $0.category == category &&
            $0.isActive &&
            (!autoClearingProgressMode || isTaskSelectedForToday($0))
        }
        
        let done = categoryTasks.filter {
            $0.isCompleted
        }.count
        
        return (done, categoryTasks.count)
    }
    
    // MARK: - Task Filters
    
    func visibleTasks(
        from tasks: [LureliaTask],
        autoClearTasks: Bool
    ) -> [LureliaTask] {
        tasks.filter { task in
            guard task.isActive else { return false }
            
            if autoClearTasks {
                return isTaskSelectedForToday(task)
            } else {
                return true
            }
        }
    }
    
    func tasks(
        for category: String,
        tasks: [LureliaTask],
        autoClearTasks: Bool
    ) -> [LureliaTask] {
        visibleTasks(from: tasks, autoClearTasks: autoClearTasks)
            .filter { $0.category == category }
            .sorted {
                if $0.isCompleted == $1.isCompleted {
                    return $0.title < $1.title
                }
                
                return !$0.isCompleted && $1.isCompleted
            }
    }
}
