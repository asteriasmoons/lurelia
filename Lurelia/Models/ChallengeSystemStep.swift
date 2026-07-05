//
//  ChallengeSystemStep.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaChallengeSystemStep {

    var id: UUID = UUID()

    var title: String = ""
    var notes: String = ""

    var sortOrder: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var challenge: LureliaChallenge?

    init(
        title: String,
        notes: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
