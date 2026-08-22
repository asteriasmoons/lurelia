//
//  RoutineTaskTemplate.swift
//  Lurelia
//
//  A blueprint for a routine task. Reusable, standalone — never references
//  a routine or a phase. Creating a task from a template makes a full
//  independent copy: no live link, no cascading updates, no shared IDs.
//
//  Structured children (steps, supplies, obstacles) are stored as JSON on
//  the template rather than as separate @Model classes. That keeps the
//  schema migration additive (one new entity) and matches Lurelia's
//  existing pattern of Data-backed list storage on models.
//

import Foundation
import SwiftData

// MARK: - Value types (Codable payloads for JSON storage)

struct RoutineTaskTemplateStep: Codable, Hashable {
    var title: String
}

struct RoutineTaskTemplateSupply: Codable, Hashable {
    var name: String
}

struct RoutineTaskTemplateObstacle: Codable, Hashable {
    var obstacle: String
    var solution: String
}

// MARK: - Model

@Model
final class RoutineTaskTemplate {

    // MARK: Identity
    var id: UUID = UUID()

    // MARK: Core
    var title: String = ""
    var notes: String = ""
    /// User-provided goal / context (mirrors `LureliaRoutineTask.context`).
    var context: String = ""
    var icon: String = "sparkle"

    // MARK: Blueprint
    var purpose: String = ""
    var motivation: String = ""
    var trigger: String = ""
    var triggerTypeRaw: String?
    var triggerReason: String = ""
    var environment: String = ""
    var friction: String = ""
    var reward: String = ""
    var consequence: String = ""
    var recoveryPlan: String = ""

    // MARK: Schedule defaults
    var hasDueTime: Bool = false
    var dueHour: Int = 8
    var dueMinute: Int = 0
    var estimatedDurationMinutes: Int = 0
    var repeatsOnDays: Bool = false
    /// JSON-encoded `[Int]`. 1 = Sunday ... 7 = Saturday.
    var scheduledDaysStorage: Data?

    // MARK: Notifications & alarm defaults
    var notificationsEnabled: Bool = false
    /// JSON-encoded `[Int]`.
    var notificationLeadMinutesStorage: Data?
    var alarmEnabled: Bool = false
    var alarmSoundName: String?

    // MARK: Structured content — JSON-encoded value-type arrays
    var stepsStorage: Data?
    var suppliesStorage: Data?
    var obstaclesStorage: Data?

    // MARK: Dates
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        title: String = "",
        icon: String = "sparkle"
    ) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.createdDate = Date()
        self.updatedDate = Date()
    }
}

// MARK: - JSON storage helpers

extension RoutineTaskTemplate {

    var scheduledDays: [Int] {
        get { decode([Int].self, from: scheduledDaysStorage) ?? [] }
        set {
            scheduledDaysStorage = encode(newValue)
            updatedDate = Date()
        }
    }

    var notificationLeadMinutes: [Int] {
        get { decode([Int].self, from: notificationLeadMinutesStorage) ?? [] }
        set {
            notificationLeadMinutesStorage = encode(newValue)
            updatedDate = Date()
        }
    }

    var steps: [RoutineTaskTemplateStep] {
        get { decode([RoutineTaskTemplateStep].self, from: stepsStorage) ?? [] }
        set {
            stepsStorage = encode(newValue)
            updatedDate = Date()
        }
    }

    var supplies: [RoutineTaskTemplateSupply] {
        get { decode([RoutineTaskTemplateSupply].self, from: suppliesStorage) ?? [] }
        set {
            suppliesStorage = encode(newValue)
            updatedDate = Date()
        }
    }

    var obstacles: [RoutineTaskTemplateObstacle] {
        get { decode([RoutineTaskTemplateObstacle].self, from: obstaclesStorage) ?? [] }
        set {
            obstaclesStorage = encode(newValue)
            updatedDate = Date()
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
}

// MARK: - Task ↔ Template conversions

extension RoutineTaskTemplate {

    /// Snapshots a live `LureliaRoutineTask` into a new template. Called by
    /// the "Save as Template" flow in the task editor.
    static func fromTask(_ task: LureliaRoutineTask) -> RoutineTaskTemplate {
        let template = RoutineTaskTemplate(title: task.title, icon: task.icon)
        template.notes = task.notes
        template.context = task.context

        template.purpose = task.purpose
        template.motivation = task.motivation
        template.trigger = task.trigger
        template.triggerTypeRaw = task.triggerTypeRaw
        template.triggerReason = task.triggerReason
        template.environment = task.environment
        template.friction = task.friction
        template.reward = task.reward
        template.consequence = task.consequence
        template.recoveryPlan = task.recoveryPlan

        template.hasDueTime = task.hasDueTime
        template.dueHour = task.dueHour
        template.dueMinute = task.dueMinute
        template.estimatedDurationMinutes = max(0, task.estimatedDurationMinutes)
        template.repeatsOnDays = task.repeatsOnDays
        template.scheduledDays = task.scheduledDays

        template.notificationsEnabled = task.notificationsEnabled
        template.notificationLeadMinutes = task.notificationLeadMinutes
        template.alarmEnabled = task.alarmEnabled
        template.alarmSoundName = task.alarmSoundName

        template.steps = (task.stepItems ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { RoutineTaskTemplateStep(title: $0.title) }
        template.supplies = (task.supplyItems ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { RoutineTaskTemplateSupply(name: $0.name) }
        template.obstacles = (task.obstacleItems ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { RoutineTaskTemplateObstacle(obstacle: $0.obstacle, solution: $0.solution) }

        return template
    }

    /// Builds a brand new `LureliaRoutineTask` from this template. The task
    /// is independent — no reference back to the template. Child items
    /// (steps, supplies, obstacles) are freshly-created @Model instances
    /// with new UUIDs. Caller is responsible for inserting into a routine
    /// (setting `routine`, `phaseID`, `sortOrder`) and saving the context.
    func makeTask(sortOrder: Int) -> (task: LureliaRoutineTask,
                                       steps: [LureliaRoutineTaskStep],
                                       supplies: [LureliaRoutineTaskSupply],
                                       obstacles: [LureliaRoutineTaskObstacle]) {
        let task = LureliaRoutineTask(
            title: title,
            icon: icon,
            notes: notes,
            sortOrder: sortOrder
        )
        task.context = context

        task.purpose = purpose
        task.motivation = motivation
        task.trigger = trigger
        task.triggerTypeRaw = triggerTypeRaw
        task.triggerReason = triggerReason
        task.environment = environment
        task.friction = friction
        task.reward = reward
        task.consequence = consequence
        task.recoveryPlan = recoveryPlan

        task.hasDueTime = hasDueTime
        task.dueHour = dueHour
        task.dueMinute = dueMinute
        task.estimatedDurationMinutes = max(0, estimatedDurationMinutes)
        task.repeatsOnDays = repeatsOnDays
        task.scheduledDays = scheduledDays

        task.notificationsEnabled = notificationsEnabled
        task.notificationLeadMinutes = notificationLeadMinutes
        task.alarmEnabled = alarmEnabled
        task.alarmSoundName = alarmSoundName

        let stepChildren: [LureliaRoutineTaskStep] = steps.enumerated().map { index, seed in
            LureliaRoutineTaskStep(title: seed.title, isCompleted: false, sortOrder: index)
        }
        let supplyChildren: [LureliaRoutineTaskSupply] = supplies.enumerated().map { index, seed in
            LureliaRoutineTaskSupply(name: seed.name, sortOrder: index)
        }
        let obstacleChildren: [LureliaRoutineTaskObstacle] = obstacles.enumerated().map { index, seed in
            LureliaRoutineTaskObstacle(obstacle: seed.obstacle, solution: seed.solution, sortOrder: index)
        }

        return (task, stepChildren, supplyChildren, obstacleChildren)
    }
}
