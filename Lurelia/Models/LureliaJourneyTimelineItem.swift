//
//  LureliaJourneyTimelineItem.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaJourneyTimelineItem {

    var id: UUID = UUID()

    // Core
    var title: String = ""
    var details: String = ""

    // Type
    var itemTypeRaw: String = LureliaJourneyTimelineItemType.step.rawValue

    // Scheduling
    var scheduledDate: Date?
    var startTime: Date?
    var endTime: Date?

    // Ordering
    var sortOrder: Int = 0

    // State
    var isCompleted: Bool = false

    // Linking
    var linkedReminderIDsStorage: String = "[]"
    var linkedRoutineIDsStorage: String = "[]"

    // Relationships
    var journey: LureliaJourney?

    var milestone: LureliaJourneyMilestone?
    var step: LureliaJourneyStep?

    init(
        title: String,
        details: String = ""
    ) {
        self.title = title
        self.details = details
    }
}

extension LureliaJourneyTimelineItem {

    var itemType: LureliaJourneyTimelineItemType {
        get {
            LureliaJourneyTimelineItemType(rawValue: itemTypeRaw) ?? .step
        }
        set {
            itemTypeRaw = newValue.rawValue
        }
    }

    var linkedReminderIDs: [UUID] {
        get {
            decodeUUIDArray(from: linkedReminderIDsStorage)
        }
        set {
            linkedReminderIDsStorage = encodeUUIDArray(newValue)
        }
    }

    var linkedRoutineIDs: [UUID] {
        get {
            decodeUUIDArray(from: linkedRoutineIDsStorage)
        }
        set {
            linkedRoutineIDsStorage = encodeUUIDArray(newValue)
        }
    }

    private func decodeUUIDArray(from storage: String) -> [UUID] {
        guard let data = storage.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }

        return strings.compactMap { UUID(uuidString: $0) }
    }

    private func encodeUUIDArray(_ values: [UUID]) -> String {
        let uniqueStrings = Array(Set(values.map { $0.uuidString })).sorted()

        guard let data = try? JSONEncoder().encode(uniqueStrings),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return json
    }
}

enum LureliaJourneyTimelineItemType: String, Codable, CaseIterable {
    case milestone
    case step
    case reminder
    case routine
    case note
}
