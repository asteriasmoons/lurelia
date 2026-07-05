//
//  Challenge.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaChallengeStatus: String, Codable, CaseIterable {
    case active = "Active"
    case completed = "Completed"
    case expired = "Expired"

    var displayName: String { rawValue }
}

enum LureliaChallengeFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var displayName: String { rawValue }
}

enum LureliaChallengeTargetUnit: String, Codable, CaseIterable {
    case completions = "Completions"
    case pages = "Pages"
    case entries = "Entries"
    case minutes = "Minutes"
    case hours = "Hours"
    case steps = "Steps"
    case walks = "Walks"
    case workouts = "Workouts"
    case tasks = "Tasks"
    case applications = "Applications"
    case books = "Books"
    case lessons = "Lessons"
    case sessions = "Sessions"
    case custom = "Custom"

    var displayName: String {
        rawValue
    }
}

@Model
final class LureliaChallenge {

    var id: UUID = UUID()

    var title: String = ""
    var identityStatement: String = ""
    var details: String = ""
    var iconName: String = "trophystar"

    var startDate: Date = Date()
    var endDate: Date = Date()

    var frequencyRaw: String = LureliaChallengeFrequency.daily.rawValue
    var targetValue: Int = 1
    var currentValue: Int = 0
    var targetUnitRaw: String = LureliaChallengeTargetUnit.completions.rawValue
    var customTargetUnit: String = ""
    var statusRaw: String = LureliaChallengeStatus.active.rawValue

    var rewardName: String = ""
    var rewardDescription: String = ""
    var rewardAlignmentNote: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \LureliaChallengeAction.challenge)
    var actions: [LureliaChallengeAction]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaChallengeSystemStep.challenge)
    var systemSteps: [LureliaChallengeSystemStep]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaChallengeProgressReport.challenge)
    var progressReports: [LureliaChallengeProgressReport]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaChallengeEntry.challenge)
    var entries: [LureliaChallengeEntry]?

    init(
        title: String,
        identityStatement: String = "",
        details: String = "",
        iconName: String = "trophystar",
        startDate: Date = Date(),
        endDate: Date = Date(),
        frequency: LureliaChallengeFrequency = .daily,
        targetValue: Int = 1,
        targetUnit: LureliaChallengeTargetUnit = .completions,
        customTargetUnit: String = "",
        rewardName: String = "",
        rewardDescription: String = "",
        rewardAlignmentNote: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.identityStatement = identityStatement
        self.details = details
        self.iconName = iconName
        self.startDate = startDate
        self.endDate = endDate
        self.frequencyRaw = frequency.rawValue
        self.targetValue = max(1, targetValue)
        self.currentValue = 0
        self.targetUnitRaw = targetUnit.rawValue
        self.customTargetUnit = customTargetUnit
        self.statusRaw = LureliaChallengeStatus.active.rawValue
        self.rewardName = rewardName
        self.rewardDescription = rewardDescription
        self.rewardAlignmentNote = rewardAlignmentNote
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension LureliaChallenge {

    var frequency: LureliaChallengeFrequency {
        get { LureliaChallengeFrequency(rawValue: frequencyRaw) ?? .daily }
        set {
            frequencyRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var targetUnit: LureliaChallengeTargetUnit {
        get {
            LureliaChallengeTargetUnit(rawValue: targetUnitRaw) ?? .completions
        }
        set {
            targetUnitRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var targetUnitLabel: String {
        targetUnit == .custom
            ? (customTargetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : customTargetUnit)
            : targetUnit.displayName
    }

    var effectiveTargetValue: Int {
        max(targetValue, sortedActions.count, 1)
    }

    var progressText: String {
        "\(currentValue) / \(effectiveTargetValue) \(targetUnitLabel)"
    }

    var targetProgressValue: Double {
        guard effectiveTargetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(effectiveTargetValue), 1)
    }

    var status: LureliaChallengeStatus {
        get { LureliaChallengeStatus(rawValue: statusRaw) ?? .active }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
            if newValue == .completed {
                completedAt = completedAt ?? Date()
            }
        }
    }

    var durationDays: Int {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return max(1, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    var daysRemaining: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: endDate)
        return max(0, Calendar.current.dateComponents([.day], from: today, to: end).day ?? 0)
    }

    var sortedActions: [LureliaChallengeAction] {
        (actions ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedSystemSteps: [LureliaChallengeSystemStep] {
        (systemSteps ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var completionPercentage: Double {
        targetProgressValue
    }

    var progressRingValue: Double {
        completionPercentage
    }

    var completionPercentText: String {
        "\(Int((completionPercentage * 100).rounded()))%"
    }

    var remainingActionsCount: Int {
        sortedActions.filter { !$0.isCompleted }.count
    }

    var totalVotesCast: Int {
        sortedActions.filter(\.isCompleted).count
    }

    var isCheckInDue: Bool {
        let reports = progressReports ?? []
        let calendar = Calendar.current

        guard let latest = reports.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            return true
        }

        switch frequency {
        case .daily:
            return !calendar.isDateInToday(latest.createdAt)

        case .weekly:
            guard let nextDue = calendar.date(byAdding: .day, value: 7, to: latest.createdAt) else {
                return true
            }
            return Date() >= nextDue

        case .monthly:
            guard let nextDue = calendar.date(byAdding: .month, value: 1, to: latest.createdAt) else {
                return true
            }
            return Date() >= nextDue
        }
    }

    func addProgress(_ amount: Int = 1) {
        currentValue = min(targetValue, currentValue + max(1, amount))

        if currentValue >= targetValue {
            status = .completed
            completedAt = completedAt ?? Date()
        }

        updatedAt = Date()
    }

    func markIncomplete() {
        status = .active
        completedAt = nil
        currentValue = min(currentValue, max(0, targetValue - 1))
        updatedAt = Date()
    }

    func resetProgress() {
        currentValue = 0
        status = .active
        completedAt = nil
        updatedAt = Date()
    }
}
