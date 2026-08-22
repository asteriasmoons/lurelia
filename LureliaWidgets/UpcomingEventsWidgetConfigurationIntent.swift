//
//  UpcomingEventsWidgetConfigurationIntent.swift
//  Lurelia
//
//  Configuration intent for LureliaUpcomingEventsWidget. Lets the user
//  pick a specific Lurelia calendar or Apple calendar to show in the widget
//  (or leave it unset to include every visible calendar).
//

import AppIntents
import SwiftData
import Foundation
import WidgetKit

// MARK: - Calendar AppEntity

/// Widget-side representation of either a Lurelia calendar or an Apple
/// calendar. We can't hand SwiftData `@Model` / EventKit instances directly
/// to AppIntents, so we serialize the id + display fields into an `AppEntity`.
struct LureliaCalendarEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    var colorHex: String
    var source: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Calendar")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name.isEmpty ? "Untitled" : name),
            subtitle: LocalizedStringResource(stringLiteral: source)
        )
    }

    static var defaultQuery = LureliaCalendarEntityQuery()

    static let applePrefix = "apple:"

    static func appleID(for calendarIdentifier: String) -> String {
        "\(applePrefix)\(calendarIdentifier)"
    }

    static func appleCalendarIdentifier(from entityID: String) -> String? {
        guard entityID.hasPrefix(applePrefix) else { return nil }
        let value = String(entityID.dropFirst(applePrefix.count))
        return value.isEmpty ? nil : value
    }
}

// MARK: - Query (drives the picker options)

struct LureliaCalendarEntityQuery: EntityQuery {

    /// Called when the picker needs to resolve previously-selected ids
    /// back into entities.
    func entities(for identifiers: [LureliaCalendarEntity.ID]) async throws -> [LureliaCalendarEntity] {
        let all = try fetchAll()
        let idSet = Set(identifiers)
        return all.filter { idSet.contains($0.id) }
    }

    /// Called when the user opens the picker for the first time — returns
    /// every non-hidden Lurelia calendar plus every cached Apple calendar.
    func suggestedEntities() async throws -> [LureliaCalendarEntity] {
        try fetchAll()
    }

    private func fetchAll() throws -> [LureliaCalendarEntity] {
        let container = try LureliaWidgetShared.makeModelContainer()
        let context = ModelContext(container)
        let calendars = try context.fetch(FetchDescriptor<LureliaCalendar>())
        let lureliaCalendars = calendars
            .filter { !$0.isHidden }
            .map { cal in
                LureliaCalendarEntity(
                    id: cal.id.uuidString,
                    name: cal.name,
                    colorHex: cal.color,
                    source: "Lurelia"
                )
            }

        let appleCalendars = LureliaWidgetShared.loadAppleCalendarSnapshots()
            .map { calendar in
                LureliaCalendarEntity(
                    id: LureliaCalendarEntity.appleID(for: calendar.id),
                    name: calendar.title,
                    colorHex: calendar.colorHex,
                    source: "Apple Calendar"
                )
            }

        return (lureliaCalendars + appleCalendars)
            .sorted {
                if $0.source == $1.source {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.source.localizedCaseInsensitiveCompare($1.source) == .orderedDescending
            }
    }
}

// MARK: - Configuration Intent

struct UpcomingEventsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Upcoming Events"
    static var description = IntentDescription(
        "Choose which calendar the Upcoming Events widget should show. Leave blank to include every visible calendar."
    )

    /// Optional single-select. `nil` means "all visible calendars".
    @Parameter(title: "Calendar")
    var calendar: LureliaCalendarEntity?

    init() {}

    init(calendar: LureliaCalendarEntity?) {
        self.calendar = calendar
    }
}
