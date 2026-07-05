//
//  ChallengeHelpers.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaChallengeHelpers {

    // MARK: - Dates

    static func durationDays(
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        return max(
            1,
            (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        )
    }

    static func daysRemaining(
        until endDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)

        return max(
            0,
            calendar.dateComponents([.day], from: today, to: end).day ?? 0
        )
    }

    static func isEndingSoon(
        _ challenge: LureliaChallenge,
        threshold: Int = 3
    ) -> Bool {
        challenge.status == .active &&
        challenge.daysRemaining <= threshold
    }

    static func hasExpired(
        _ challenge: LureliaChallenge,
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: challenge.endDate)

        return today > end && challenge.status != .completed
    }

    // MARK: - Progress

    static func completionPercentage(
        actions: [LureliaChallengeAction]
    ) -> Double {
        guard !actions.isEmpty else { return 0 }

        let total = actions.reduce(0.0) { partial, action in
            partial + action.progressValue
        }

        return min(max(total / Double(actions.count), 0), 1)
    }

    static func completionPercentText(
        progress: Double
    ) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
    }

    static func completedActionsCount(
        _ challenge: LureliaChallenge
    ) -> Int {
        challenge.sortedActions.filter(\.isCompleted).count
    }

    static func remainingActionsCount(
        _ challenge: LureliaChallenge
    ) -> Int {
        challenge.sortedActions.filter { !$0.isCompleted }.count
    }

    static func nextAction(
        for challenge: LureliaChallenge
    ) -> LureliaChallengeAction? {
        challenge.sortedActions.first { !$0.isCompleted }
    }

    static func totalVotesCast(
        _ challenge: LureliaChallenge
    ) -> Int {
        challenge.sortedActions.filter(\.isCompleted).count
    }

    // MARK: - Behavior Law Coverage

    static func behaviorLawCoverage(
        _ challenge: LureliaChallenge
    ) -> [LureliaBehaviorLaw: Int] {
        var counts: [LureliaBehaviorLaw: Int] = [:]

        for action in challenge.sortedActions {
            let law = action.behaviorLaw
            if law != .none {
                counts[law, default: 0] += 1
            }
        }

        return counts
    }

    static func missingBehaviorLaws(
        _ challenge: LureliaChallenge
    ) -> [LureliaBehaviorLaw] {
        let coverage = behaviorLawCoverage(challenge)
        let allLaws: [LureliaBehaviorLaw] = [.obvious, .attractive, .easy, .satisfying]

        return allLaws.filter { coverage[$0] == nil }
    }

    // MARK: - Recovery

    static func hasMissedPeriod(
        _ challenge: LureliaChallenge,
        calendar: Calendar = .current
    ) -> Bool {
        let entries = challenge.entries ?? []
        let actionEntries = entries.filter {
            $0.sourceType == .manualActionCompleted ||
            $0.sourceType == .actionCompleted ||
            $0.sourceType == .reminderCompleted ||
            $0.sourceType == .habitCompleted ||
            $0.sourceType == .routineCompleted
        }

        guard let latestAction = actionEntries.sorted(by: { $0.date > $1.date }).first else {
            return true
        }

        switch challenge.frequency {
        case .daily:
            return !calendar.isDateInToday(latestAction.date) &&
                   !calendar.isDateInYesterday(latestAction.date)

        case .weekly:
            guard let threshold = calendar.date(byAdding: .day, value: -7, to: Date()) else {
                return true
            }
            return latestAction.date < threshold

        case .monthly:
            guard let threshold = calendar.date(byAdding: .month, value: -1, to: Date()) else {
                return true
            }
            return latestAction.date < threshold
        }
    }

    // MARK: - Status

    static func refreshStatus(
        for challenge: LureliaChallenge,
        modelContext: ModelContext? = nil
    ) {
        let actions = challenge.sortedActions

        if !actions.isEmpty && actions.allSatisfy(\.isCompleted) {
            if challenge.status != .completed {
                challenge.status = .completed
                challenge.completedAt = Date()

                if let modelContext {
                    let entry = LureliaChallengeEntry(
                        challenge: challenge,
                        sourceType: .challengeCompleted,
                        sourceID: challenge.id,
                        title: "Challenge Completed",
                        note: challenge.title
                    )
                    modelContext.insert(entry)
                }
            }
        } else if hasExpired(challenge) {
            challenge.status = .expired
        } else if challenge.status != .active {
            challenge.status = .active
            challenge.completedAt = nil
        }

        challenge.updatedAt = Date()
    }

    // MARK: - Check-In

    static func latestReport(
        for challenge: LureliaChallenge
    ) -> LureliaChallengeProgressReport? {
        (challenge.progressReports ?? [])
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    static func isCheckInDue(
        for challenge: LureliaChallenge,
        calendar: Calendar = .current
    ) -> Bool {
        guard let latest = latestReport(for: challenge) else {
            return true
        }

        switch challenge.frequency {
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

    static func checkInStatusText(
        for challenge: LureliaChallenge
    ) -> String {
        isCheckInDue(for: challenge)
        ? "Check-In Due"
        : "Check-In Complete"
    }

    // MARK: - Entry Creation

    static func createEntry(
        challenge: LureliaChallenge,
        action: LureliaChallengeAction? = nil,
        sourceType: LureliaChallengeEntrySourceType,
        sourceID: UUID? = nil,
        title: String,
        note: String = "",
        modelContext: ModelContext
    ) {
        let entry = LureliaChallengeEntry(
            challenge: challenge,
            action: action,
            sourceType: sourceType,
            sourceID: sourceID,
            title: title,
            note: note
        )

        modelContext.insert(entry)
        challenge.updatedAt = Date()
    }

    // MARK: - Labels

    static func daysRemainingText(
        for challenge: LureliaChallenge
    ) -> String {
        switch challenge.status {
        case .completed:
            return "Done"

        case .expired:
            return "Expired"

        case .active:
            let days = challenge.daysRemaining

            if days == 1 {
                return "1 Day"
            }

            return "\(days) Days"
        }
    }

    static func actionSubtitle(
        _ action: LureliaChallengeAction
    ) -> String {
        switch action.linkedItemType {
        case .reminder:
            return "Linked Reminder"

        case .habit:
            return "Linked Habit"

        case .routine:
            return "Linked Routine"

        case .manual:
            return "Manual Action"
        }
    }

    static func iconName(
        for linkedType: LureliaChallengeLinkedItemType
    ) -> String {
        switch linkedType {
        case .reminder:
            return "bellfill"

        case .habit:
            return "repeatfill"

        case .routine:
            return "clockwavy"

        case .manual:
            return "checkwavy"
        }
    }

    static func timelineIconName(
        for sourceType: LureliaChallengeEntrySourceType
    ) -> String {
        switch sourceType {
        case .challengeStarted:
            return "starwavy"

        case .progressReportSubmitted:
            return "linedpages"

        case .reminderCompleted:
            return "bellfill"

        case .habitCompleted:
            return "repeatfill"

        case .routineCompleted:
            return "clockwavy"

        case .manualActionCompleted:
            return "checkwavy"

        case .actionCompleted:
            return "checkwavy"

        case .milestoneReached:
            return "starchart"

        case .challengeCompleted:
            return "startrophyfill"

        case .recoveryVote:
            return "sparkbolt"
        }
    }
}
