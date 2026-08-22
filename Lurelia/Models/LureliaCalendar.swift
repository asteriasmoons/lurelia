//
//  LureliaCalendar.swift
//  Lurelia
//
//  A real calendar entity — each event belongs to one calendar
//  (one-to-many), unlike LureliaEventTag which is many-to-many.
//  A calendar is a color-and-name grouping used to organize events
//  the way Apple Calendar / Google Calendar work.
//

import Foundation
import SwiftData

@Model
final class LureliaCalendar {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#03dbfc"
    var isHidden: Bool = false
    var createdDate: Date = Date()

    /// Inverse of `LureliaEvent.calendar`. Optional to satisfy CloudKit.
    var events: [LureliaEvent]?

    init(name: String = "", color: String = "#03dbfc", isHidden: Bool = false) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.isHidden = isHidden
        self.createdDate = Date()
    }
}
