//
//  LureliaHabitLog.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaHabitLog {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core

    var dayStart: Date = Date()
    var count: Int = 1

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationship

    var habit: LureliaHabit?

    // MARK: - Init

    init(habit: LureliaHabit, dayStart: Date, count: Int = 1) {
        self.id = UUID()
        self.habit = habit
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.count = max(1, count)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
