//
//  ChallengeProgressReport.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaChallengeProgressReport {

    var id: UUID = UUID()

    var difficultyRating: Int = 3

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var challenge: LureliaChallenge?

    @Relationship(deleteRule: .cascade, inverse: \LureliaChallengeReportResponse.report)
    var responses: [LureliaChallengeReportResponse]?

    init(
        challenge: LureliaChallenge,
        difficultyRating: Int = 3
    ) {
        self.id = UUID()
        self.challenge = challenge
        self.difficultyRating = max(1, min(5, difficultyRating))
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension LureliaChallengeProgressReport {

    var sortedResponses: [LureliaChallengeReportResponse] {
        (responses ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}
