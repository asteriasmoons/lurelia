//
//  ChallengeReportResponse.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaChallengeReportResponse {

    var id: UUID = UUID()

    var question: String = ""
    var answer: String = ""

    var sortOrder: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var report: LureliaChallengeProgressReport?

    init(
        question: String,
        answer: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
