//
//  ChallengeEntry.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaChallengeEntrySourceType: String, Codable, CaseIterable {
    case challengeStarted = "Challenge Started"
    case progressReportSubmitted = "Progress Report Submitted"
    case reminderCompleted = "Reminder Completed"
    case habitCompleted = "Habit Completed"
    case routineCompleted = "Routine Completed"
    case manualActionCompleted = "Manual Action Completed"
    case actionCompleted = "Action Completed"
    case milestoneReached = "Milestone Reached"
    case challengeCompleted = "Challenge Completed"
    case recoveryVote = "Recovery Vote"

    var displayName: String { rawValue }
}

@Model
final class LureliaChallengeEntry {

    var id: UUID = UUID()

    var date: Date = Date()
    var sourceTypeRaw: String = LureliaChallengeEntrySourceType.manualActionCompleted.rawValue
    var sourceID: UUID?

    var title: String = ""
    var note: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var challenge: LureliaChallenge?
    var action: LureliaChallengeAction?

    init(
        challenge: LureliaChallenge,
        action: LureliaChallengeAction? = nil,
        sourceType: LureliaChallengeEntrySourceType,
        sourceID: UUID? = nil,
        title: String,
        note: String = "",
        date: Date = Date()
    ) {
        self.id = UUID()
        self.challenge = challenge
        self.action = action
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceID = sourceID
        self.title = title
        self.note = note
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension LureliaChallengeEntry {

    var sourceType: LureliaChallengeEntrySourceType {
        get { LureliaChallengeEntrySourceType(rawValue: sourceTypeRaw) ?? .manualActionCompleted }
        set {
            sourceTypeRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}
