//
//  RoutineStats.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaRoutineStats {
    var id: UUID = UUID()

    // MARK: - Totals

    var routineTimeSpentMinutes: Int = 0
    var routineTimeMissedMinutes: Int = 0
    var routineTimeCreditMinutes: Int = 0

    // MARK: - Buyback Tracking

    var totalBuybacksUsed: Int = 0
    var totalCoinsSpentOnBuybacks: Int = 0
    var lastBuybackAt: Date?

    // MARK: - Dates

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        routineTimeSpentMinutes: Int = 0,
        routineTimeMissedMinutes: Int = 0,
        routineTimeCreditMinutes: Int = 0,
        totalBuybacksUsed: Int = 0,
        totalCoinsSpentOnBuybacks: Int = 0,
        lastBuybackAt: Date? = nil
    ) {
        self.id = UUID()
        self.routineTimeSpentMinutes = routineTimeSpentMinutes
        self.routineTimeMissedMinutes = routineTimeMissedMinutes
        self.routineTimeCreditMinutes = routineTimeCreditMinutes
        self.totalBuybacksUsed = totalBuybacksUsed
        self.totalCoinsSpentOnBuybacks = totalCoinsSpentOnBuybacks
        self.lastBuybackAt = lastBuybackAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
