//
//  LureliaJourneyCheckIn.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaJourneyCheckInResponse: String, Codable, CaseIterable {
    case yes = "Yes"
    case notToday = "Not Today"
    case no = "No"

    var displayName: String {
        rawValue
    }
}

@Model
final class LureliaJourneyCheckIn {

    var id: UUID = UUID()

    var responseRaw: String = LureliaJourneyCheckInResponse.yes.rawValue

    var date: Date = Date()
    var dayStart: Date = Calendar.current.startOfDay(for: Date())

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var journey: LureliaJourney?

    init(
        journey: LureliaJourney,
        response: LureliaJourneyCheckInResponse,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.journey = journey
        self.responseRaw = response.rawValue
        self.date = date
        self.dayStart = Calendar.current.startOfDay(for: date)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension LureliaJourneyCheckIn {

    var response: LureliaJourneyCheckInResponse {
        get {
            LureliaJourneyCheckInResponse(rawValue: responseRaw) ?? .yes
        }
        set {
            responseRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}
