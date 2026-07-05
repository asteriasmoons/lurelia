//
//  LureliaJourneyNote.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaJourneyNote {

    var id: UUID = UUID()

    // Core
    var title: String = ""
    var body: String = ""

    // Optional links
    var linkedMilestoneID: UUID?
    var linkedStepID: UUID?

    // Dates
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationship
    var journey: LureliaJourney?

    init(title: String, body: String = "") {
        self.title = title
        self.body = body
    }
}
