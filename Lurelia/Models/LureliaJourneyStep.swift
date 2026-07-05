//
//  LureliaJourneyStep.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaJourneyStep {

    var id: UUID = UUID()

    // Core
    var title: String = ""
    var details: String = ""

    // Ordering
    var sortOrder: Int = 0

    // Status
    var statusRaw: String = LureliaJourneyStepStatus.notStarted.rawValue

    // Dates
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var targetDate: Date?
    var completedAt: Date?

    // Linking
    var linkedReminderIDsStorage: String = "[]"
    var linkedRoutineIDsStorage: String = "[]"
    var linkedHabitIDsStorage: String = "[]"

    // Relationships
    var milestone: LureliaJourneyMilestone?

    @Relationship(deleteRule: .nullify, inverse: \LureliaJourneyTimelineItem.step)
    var timelineItems: [LureliaJourneyTimelineItem]?

    init(
        title: String,
        details: String = "",
        sortOrder: Int = 0
    ) {
        self.title = title
        self.details = details
        self.sortOrder = sortOrder
    }
}

extension LureliaJourneyStep {

    var status: LureliaJourneyStepStatus {
        get { LureliaJourneyStepStatus(rawValue: statusRaw) ?? .notStarted }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var isCompleted: Bool {
        status == .completed
    }

    func markCompleted() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
        updateMilestoneCompletionState()
    }

    func markIncomplete() {
        status = .inProgress
        completedAt = nil
        updatedAt = Date()
        updateMilestoneCompletionState()
    }

    func toggleCompletion() {
        if isCompleted {
            markIncomplete()
        } else {
            markCompleted()
        }
    }

    private func updateMilestoneCompletionState() {
        guard let milestone else { return }

        let steps = milestone.steps ?? []
        guard !steps.isEmpty else {
            milestone.status = .notStarted
            milestone.completedAt = nil
            milestone.updatedAt = Date()
            return
        }

        let completedCount = steps.filter { $0.status == .completed }.count

        if completedCount == steps.count {
            milestone.status = .completed
            milestone.completedAt = Date()
        } else if completedCount > 0 {
            milestone.status = .inProgress
            milestone.completedAt = nil
        } else {
            milestone.status = .notStarted
            milestone.completedAt = nil
        }

        milestone.updatedAt = Date()
    }

    var linkedReminderIDs: [UUID] {
        get { decodeUUIDArray(from: linkedReminderIDsStorage) }
        set {
            linkedReminderIDsStorage = encodeUUIDArray(newValue)
            updatedAt = Date()
        }
    }

    var linkedRoutineIDs: [UUID] {
        get { decodeUUIDArray(from: linkedRoutineIDsStorage) }
        set {
            linkedRoutineIDsStorage = encodeUUIDArray(newValue)
            updatedAt = Date()
        }
    }

    var linkedHabitIDs: [UUID] {
        get { decodeUUIDArray(from: linkedHabitIDsStorage) }
        set {
            linkedHabitIDsStorage = encodeUUIDArray(newValue)
            updatedAt = Date()
        }
    }

    private func decodeUUIDArray(from storage: String) -> [UUID] {
        guard let data = storage.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return strings.compactMap { UUID(uuidString: $0) }
    }

    private func encodeUUIDArray(_ values: [UUID]) -> String {
        let uniqueStrings = Array(Set(values.map { $0.uuidString })).sorted()
        guard let data = try? JSONEncoder().encode(uniqueStrings),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }
}

enum LureliaJourneyStepStatus: String, Codable, CaseIterable {
    case notStarted
    case inProgress
    case completed

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
}
