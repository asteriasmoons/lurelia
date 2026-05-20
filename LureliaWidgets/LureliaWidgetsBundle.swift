//
//  LureliaWidgetsBundle.swift
//  LureliaWidgets
//
//  Created by Asteria Moon on 5/16/26.
//

import WidgetKit
import SwiftUI

@main
struct LureliaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LureliaWidgets()
        LureliaWidgetsControl()
        LureliaWidgetsLiveActivity()
    }
}
