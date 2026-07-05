//
//  LureliaJourney.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaJourney {

    var id: UUID = UUID()

    // Core
    var title: String = ""
    var summary: String = ""
    var vision: String = ""

    // Appearance
    var iconName: String = "journey"
    var colorHex: String = "#8B5CF6"

    // Status
    var statusRaw: String = LureliaJourneyStatus.active.rawValue

    // Dates
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var targetDate: Date?

    // Settings
    var isArchived: Bool = false

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \LureliaJourneyMilestone.journey)
    var milestones: [LureliaJourneyMilestone]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaJourneyTimelineItem.journey)
    var timelineItems: [LureliaJourneyTimelineItem]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaJourneyNote.journey)
    var notes: [LureliaJourneyNote]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaJourneyCheckIn.journey)
    var checkIns: [LureliaJourneyCheckIn]?

    init(
        title: String,
        summary: String = "",
        vision: String = ""
    ) {
        self.title = title
        self.summary = summary
        self.vision = vision
    }
}

extension LureliaJourney {

    var status: LureliaJourneyStatus {
        get { LureliaJourneyStatus(rawValue: statusRaw) ?? .active }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

enum LureliaJourneyStatus: String, Codable, CaseIterable {
    case active
    case completed
    case paused
    case abandoned

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .paused: return "Paused"
        case .abandoned: return "Abandoned"
        }
    }
}
