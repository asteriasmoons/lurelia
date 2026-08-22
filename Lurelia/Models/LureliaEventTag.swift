//
//  LureliaEventTag.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaEventTag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#03dbfc"
    var createdDate: Date = Date()
    var events: [LureliaEvent]?

    init(name: String = "", color: String = "#03dbfc") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdDate = Date()
    }
}
