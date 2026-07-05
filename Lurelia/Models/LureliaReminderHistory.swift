//
//  LureliaReminderHistory.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaReminderHistoryAction: String, Codable, CaseIterable {
    case completed = "Completed"
    case skipped = "Skipped"
    case fired = "Fired"
}

@Model
final class LureliaReminderHistory {

    var id: UUID = UUID()

    @Relationship(deleteRule: .nullify, inverse: \LureliaReminder.historyEntries)
    var reminder: LureliaReminder?

    var reminderID: UUID = UUID()
    var reminderTitle: String = ""
    var reminderIcon: String = "bellfill"
    var reminderCategory: String = ""

    var action: LureliaReminderHistoryAction = LureliaReminderHistoryAction.completed

    var occurrenceDate: Date = Date()
    var actionDate: Date = Date()

    var occurrenceYear: Int = 0
    var occurrenceMonth: Int = 0
    var occurrenceDay: Int = 0
    var occurrenceHour: Int = 0
    var occurrenceMinute: Int = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        reminder: LureliaReminder?,
        action: LureliaReminderHistoryAction,
        occurrenceDate: Date,
        actionDate: Date = Date()
    ) {
        self.id = UUID()
        self.reminder = reminder

        self.reminderID = reminder?.id ?? UUID()
        self.reminderTitle = reminder?.title ?? ""
        self.reminderIcon = reminder?.icon ?? "bellfill"
        self.reminderCategory = reminder?.category ?? ""

        self.action = action
        self.occurrenceDate = occurrenceDate
        self.actionDate = actionDate

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: occurrenceDate
        )

        self.occurrenceYear = components.year ?? 0
        self.occurrenceMonth = components.month ?? 0
        self.occurrenceDay = components.day ?? 0
        self.occurrenceHour = components.hour ?? 0
        self.occurrenceMinute = components.minute ?? 0

        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
