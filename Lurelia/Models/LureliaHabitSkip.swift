//
//  LureliaHabitSkip.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaHabitSkip {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core

    var dayStart: Date = Date()

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationship

    var habit: LureliaHabit?

    // MARK: - Init

    init(habit: LureliaHabit, dayStart: Date) {
        self.id = UUID()
        self.habit = habit
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
