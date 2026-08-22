//
//  LureliaContentWidgetConfigurationIntent.swift
//  Lurelia
//

import AppIntents
import WidgetKit

struct LureliaContentWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Lurelia Content" }
    static var description: IntentDescription {
        "Shows current Lurelia content without extra configuration."
    }
}
