//
//  LureliaRoutinePhase.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaRoutinePhase {
    
    // MARK: - Identity
    
    var id: UUID = UUID()

    var persistentID: String {
        id.uuidString
    }
    
    // MARK: - Core
    
    var name: String = ""
    var icon: String = "sparkle"
    var sortOrder: Int = 0
    
    // MARK: - Schedule (per-phase, optional)
    
    var scheduleEnabled: Bool = false
    var scheduledDays: [Int] = []
    var startHour: Int = 8
    var startMinute: Int = 0
    var endHour: Int = 8
    var endMinute: Int = 30
    var durationMode: Bool = false
    var durationMinutesOverride: Int = 30
    
    // MARK: - Metadata
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Relationship
    
    var routine: LureliaRoutine?
    
    // MARK: - Init
    
    init(
        name: String,
        icon: String = "sparkle",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Helpers
    
    var durationMinutes: Int {
        if durationMode {
            return max(1, durationMinutesOverride)
        }
        let startMins = startHour * 60 + startMinute
        let endMins = endHour * 60 + endMinute
        let difference = endMins - startMins
        return max(1, difference > 0 ? difference : difference + 1440)
    }
    
    var formattedTimeRange: String {
        "\(formattedTime(hour: startHour, minute: startMinute)) - \(formattedTime(hour: endHour, minute: endMinute))"
    }
    
    var formattedDuration: String {
        let minutes = durationMinutes
        let hours = minutes / 60
        let rem = minutes % 60
        if hours > 0 && rem > 0 { return "\(hours)h \(rem)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(rem)m"
    }
    
    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):\(String(format: "%02d", minute))"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
