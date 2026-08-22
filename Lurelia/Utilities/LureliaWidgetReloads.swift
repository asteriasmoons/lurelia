//
//  LureliaWidgetReloads.swift
//  Lurelia
//
//  Single source of truth for telling widgets to refresh after an in-app
//  mutation. Any time a habit / reminder / routine task / event / kanban
//  card is created, edited, completed, un-completed, skipped, un-skipped,
//  or deleted, call `LureliaWidgetReloads.reloadAll()` — which reloads
//  every content-bearing widget kind at once.
//
//  Why one function instead of picking the "right" widget per mutation:
//  the Kanban Timeline widget can display habits, reminders, and routine
//  tasks all together, so any mutation to any of those has to refresh it
//  even if the mutation happened from a UI surface that "logically"
//  belongs to a different widget. The same applies in reverse — un-
//  completing a habit from the habits screen must refresh the Timeline
//  widget so the habit reappears there.
//
//  Cost is trivial (WidgetCenter debounces reload requests), and the
//  correctness win — no more "the widget didn't update" bugs when we
//  wire a new mutation site — is worth centralizing.
//

import Foundation
import WidgetKit

enum LureliaWidgetReloads {

    /// Widget kinds that render user content and therefore need to be
    /// reloaded whenever any tracked mutation happens.
    private static let contentWidgetKinds: [String] = [
        "LureliaDueRemindersWidget",
        "LureliaDueRoutinesWidget",
        "LureliaHabitsWidget",
        "LureliaUpcomingEventsWidget",
        "LureliaKanbanTimelineWidget",
    ]

    /// Reload every content-bearing widget. Safe to call from any thread
    /// — `WidgetCenter` handles marshaling internally.
    static func reloadAll() {
        for kind in contentWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
