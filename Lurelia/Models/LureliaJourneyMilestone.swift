//
//  LureliaJourneyMilestone.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaJourneyMilestone {

    var id: UUID = UUID()

    // Core
    var title: String = ""
    var details: String = ""

    // Ordering
    var sortOrder: Int = 0

    // Status
    var statusRaw: String = LureliaJourneyMilestoneStatus.notStarted.rawValue

    // Reward
    var reward: String?

    // Dates
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var targetDate: Date?
    var completedAt: Date?

    // Relationships
    var journey: LureliaJourney?

    @Relationship(deleteRule: .cascade, inverse: \LureliaJourneyStep.milestone)
    var steps: [LureliaJourneyStep]?

    @Relationship(deleteRule: .nullify, inverse: \LureliaJourneyTimelineItem.milestone)
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

extension LureliaJourneyMilestone {

    var status: LureliaJourneyMilestoneStatus {
        get { LureliaJourneyMilestoneStatus(rawValue: statusRaw) ?? .notStarted }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

enum LureliaJourneyMilestoneStatus: String, Codable, CaseIterable {
    case notStarted
    case inProgress
    case completed

    var displayName: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        }
    }
}
