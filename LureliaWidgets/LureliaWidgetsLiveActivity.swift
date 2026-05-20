//
//  LureliaWidgetsLiveActivity.swift
//  LureliaWidgets
//
//  Created by Asteria Moon on 5/16/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LureliaWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LureliaWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LureliaWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LureliaWidgetsAttributes {
    fileprivate static var preview: LureliaWidgetsAttributes {
        LureliaWidgetsAttributes(name: "World")
    }
}

extension LureliaWidgetsAttributes.ContentState {
    fileprivate static var smiley: LureliaWidgetsAttributes.ContentState {
        LureliaWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LureliaWidgetsAttributes.ContentState {
         LureliaWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LureliaWidgetsAttributes.preview) {
   LureliaWidgetsLiveActivity()
} contentStates: {
    LureliaWidgetsAttributes.ContentState.smiley
    LureliaWidgetsAttributes.ContentState.starEyes
}
