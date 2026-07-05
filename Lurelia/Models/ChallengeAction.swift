//
//  ChallengeAction.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaChallengeLinkedItemType: String, Codable, CaseIterable {
    case reminder = "Reminder"
    case habit = "Habit"
    case routine = "Routine"
    case manual = "Manual"

    var displayName: String { rawValue }
}

enum LureliaBehaviorLaw: String, Codable, CaseIterable {
    case obvious = "Make it Obvious"
    case attractive = "Make it Attractive"
    case easy = "Make it Easy"
    case satisfying = "Make it Satisfying"
    case none = "None"

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .obvious: return "Obvious"
        case .attractive: return "Attractive"
        case .easy: return "Easy"
        case .satisfying: return "Satisfying"
        case .none: return "None"
        }
    }

    var iconName: String {
        switch self {
        case .obvious: return "eyewavy"
        case .attractive: return "heartwavy"
        case .easy: return "sparkbolt"
        case .satisfying: return "starwavy"
        case .none: return "minuswavy"
        }
    }
}

@Model
final class LureliaChallengeAction {

    var id: UUID = UUID()

    var title: String = ""
    var notes: String = ""

    var linkedItemTypeRaw: String = LureliaChallengeLinkedItemType.manual.rawValue
    var linkedItemID: UUID?

    var behaviorLawRaw: String = LureliaBehaviorLaw.none.rawValue
    var twoMinuteVersion: String = ""
    var habitStackCue: String = ""

    var currentValue: Int = 0

    var isCompleted: Bool = false
    var completedAt: Date?

    var sortOrder: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var challenge: LureliaChallenge?

    @Relationship(deleteRule: .cascade, inverse: \LureliaChallengeEntry.action)
    var entries: [LureliaChallengeEntry]?

    init(
        title: String,
        notes: String = "",
        linkedItemType: LureliaChallengeLinkedItemType = .manual,
        linkedItemID: UUID? = nil,
        behaviorLaw: LureliaBehaviorLaw = .none,
        twoMinuteVersion: String = "",
        habitStackCue: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.linkedItemTypeRaw = linkedItemType.rawValue
        self.linkedItemID = linkedItemID
        self.behaviorLawRaw = behaviorLaw.rawValue
        self.twoMinuteVersion = twoMinuteVersion
        self.habitStackCue = habitStackCue
        self.currentValue = 0
        self.isCompleted = false
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension LureliaChallengeAction {

    var linkedItemType: LureliaChallengeLinkedItemType {
        get { LureliaChallengeLinkedItemType(rawValue: linkedItemTypeRaw) ?? .manual }
        set {
            linkedItemTypeRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var behaviorLaw: LureliaBehaviorLaw {
        get { LureliaBehaviorLaw(rawValue: behaviorLawRaw) ?? .none }
        set {
            behaviorLawRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var progressValue: Double {
        isCompleted ? 1 : 0
    }

    func addProgress(_ amount: Int = 1) {
        currentValue += max(1, amount)
        isCompleted = true
        completedAt = completedAt ?? Date()
        updatedAt = Date()
    }

    func markCompleted() {
        currentValue = max(1, currentValue)
        isCompleted = true
        completedAt = Date()
        updatedAt = Date()
    }

    func markIncomplete() {
        isCompleted = false
        completedAt = nil
        currentValue = 0
        updatedAt = Date()
    }
}
