//
//  TimelineWidgetShortcuts.swift
//  LureliaWidgets
//
//  Forces iOS to register the Timeline widget's Complete / Skip intents
//  at extension launch by declaring them through an
//  `AppShortcutsProvider`. Without this, freshly-added AppIntents can
//  sit undiscovered by the widget-button pipeline — Button(intent:)
//  taps route to an unknown intent and get silently dropped.
//

import AppIntents

struct LureliaWidgetsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteTimelineItemWidgetIntent(),
            phrases: ["Complete \(.applicationName) Timeline item"],
            shortTitle: "Complete Timeline Item",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: SkipTimelineItemWidgetIntent(),
            phrases: ["Skip \(.applicationName) Timeline item"],
            shortTitle: "Skip Timeline Item",
            systemImageName: "forward"
        )
    }
}
