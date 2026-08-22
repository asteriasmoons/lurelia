//
//  LureliaEventNotification.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaEventNotificationOffset: Int, Codable, CaseIterable, Identifiable {
    case atTime = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case oneDay = 1440

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .atTime: return "At time"
        case .fiveMinutes: return "5 min before"
        case .tenMinutes: return "10 min before"
        case .fifteenMinutes: return "15 min before"
        case .thirtyMinutes: return "30 min before"
        case .oneHour: return "1 hour before"
        case .oneDay: return "1 day before"
        }
    }
}

@Model
final class LureliaEventNotification {
    var id: UUID = UUID()
    var offsetMinutes: Int = LureliaEventNotificationOffset.tenMinutes.rawValue
    var title: String?
    var body: String?
    var isEnabled: Bool = true
    var createdDate: Date = Date()
    var event: LureliaEvent?

    init(offset: LureliaEventNotificationOffset = .tenMinutes, title: String? = nil, body: String? = nil) {
        self.id = UUID()
        self.offsetMinutes = offset.rawValue
        self.title = title
        self.body = body
        self.isEnabled = true
        self.createdDate = Date()
    }
}
