//
//  KanbanTimelineWidgetConfigurationIntent.swift
//  Lurelia
//
//  Configuration intent for `LureliaKanbanTimelineWidget`. Lets the user
//  pick a specific `KanbanBoard` — the widget only shows that board's
//  timeline. Mirrors the pattern already used by the Events widget's
//  calendar picker.
//

import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - Board AppEntity

/// Widget-side representation of a `KanbanBoard`. AppIntents can't carry
/// SwiftData `@Model` instances directly, so we serialize the fields the
/// widget needs into an `AppEntity`.
struct KanbanBoardEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    var colorHex: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Kanban Board")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name.isEmpty ? "Untitled" : name))
    }

    static var defaultQuery = KanbanBoardEntityQuery()
}

// MARK: - Query

struct KanbanBoardEntityQuery: EntityQuery {

    func entities(for identifiers: [KanbanBoardEntity.ID]) async throws -> [KanbanBoardEntity] {
        let all = try fetchAll()
        let idSet = Set(identifiers)
        return all.filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [KanbanBoardEntity] {
        try fetchAll()
    }

    private func fetchAll() throws -> [KanbanBoardEntity] {
        let container = try LureliaWidgetShared.makeModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<KanbanBoard>(sortBy: [SortDescriptor(\.sortOrder)])
        let boards = try context.fetch(descriptor)
        return boards.map { board in
            KanbanBoardEntity(
                id: board.id.uuidString,
                name: board.name,
                colorHex: board.colorHex
            )
        }
    }
}

// MARK: - Configuration Intent

struct KanbanTimelineWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Timeline"
    static var description = IntentDescription(
        "Pick which Kanban board the Timeline widget should display."
    )

    @Parameter(title: "Board")
    var board: KanbanBoardEntity?

    init() {}

    init(board: KanbanBoardEntity?) {
        self.board = board
    }
}
