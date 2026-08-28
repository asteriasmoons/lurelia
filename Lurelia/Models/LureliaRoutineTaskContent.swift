//
//  LureliaRoutineTaskContent.swift
//  Lurelia
//
//  Child models owned by an individual routine task: ordered Steps, Supplies,
//  paired Obstacles/Solutions, and Completion History entries.
//
//  All types are CloudKit-safe:
//   • every stored property has a default value
//   • the back-reference relationship (`task`) is optional
//   • the parent side uses an optional to-many with cascade delete + inverse
//   • no unique constraints
//

import Foundation
import SwiftData

// MARK: - Step

@Model
final class LureliaRoutineTaskStep {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var task: LureliaRoutineTask?

    init(
        title: String = "",
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func resetCompletion() {
        guard isCompleted else { return }
        isCompleted = false
        updatedAt = Date()
    }
}

// MARK: - Supply

@Model
final class LureliaRoutineTaskSupply {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var task: LureliaRoutineTask?

    init(
        name: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Obstacle & Solution

@Model
final class LureliaRoutineTaskObstacle {
    var id: UUID = UUID()
    var obstacle: String = ""
    var solution: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var task: LureliaRoutineTask?

    init(
        obstacle: String = "",
        solution: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.obstacle = obstacle
        self.solution = solution
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Completion History Entry

@Model
final class LureliaRoutineTaskHistoryEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationSeconds: Int = 0
    var wasCompleted: Bool = true
    var skipReason: String = ""
    var note: String = ""
    var routineTaskIDString: String = ""

    var task: LureliaRoutineTask?

    init(
        date: Date = Date(),
        durationSeconds: Int = 0,
        wasCompleted: Bool = true,
        skipReason: String = "",
        note: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.durationSeconds = durationSeconds
        self.wasCompleted = wasCompleted
        self.skipReason = skipReason
        self.note = note
    }
}
