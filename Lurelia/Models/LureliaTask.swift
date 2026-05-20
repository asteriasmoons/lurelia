//
//  LureliaTask.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaTask {
    
    // MARK: - Identity
    
    var id: UUID = UUID()
    var stableTaskID: String = UUID().uuidString
    
    // MARK: - Core
    
    var title: String = ""
    var category: String = ""
    var notes: String?
    var coinReward: Int = 0
    
    // MARK: - State
    
    var isCompleted: Bool = false
    var isActive: Bool = true
    var isSelectedToday: Bool = false
    var isCustom: Bool = false
    
    // MARK: - Routine Support
    
    var isRoutineTask: Bool = false
    var routineName: String?
    var routineOrder: Int = 0
    
    // MARK: - Scheduling
    
    var hasReminder: Bool = false
    var reminderDate: Date?
    
    var hasTimeBlock: Bool = false
    var startTime: Date?
    var endTime: Date?
    
    // MARK: - Completion
    
    var completedAt: Date?
    var selectedDate: Date?
    
    // MARK: - Metadata
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Init
    
    init(
        title: String,
        category: String,
        notes: String? = nil,
        coinReward: Int = 0
    ) {
        self.title = title
        self.category = category
        self.notes = notes
        self.coinReward = coinReward
        self.stableTaskID = UUID().uuidString
        
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Helpers

extension LureliaTask {
    
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedNotes: String? {
        guard let notes else { return nil }
        
        let cleaned = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? nil : cleaned
    }
    
    var isScheduled: Bool {
        hasReminder || hasTimeBlock
    }
    
    var hasRoutine: Bool {
        routineName != nil
    }
    
    func markCompleted() {
        isCompleted = true
        completedAt = Date()
        updatedAt = Date()
    }
    
    func markIncomplete() {
        isCompleted = false
        completedAt = nil
        updatedAt = Date()
    }
    
    func toggleCompleted() {
        isCompleted.toggle()
        
        completedAt = isCompleted ? Date() : nil
        updatedAt = Date()
    }
    
    func resetForNewDay() {
        isCompleted = false
        completedAt = nil
        isSelectedToday = false
        updatedAt = Date()
    }
}
