//
//  LureliaLiveActivityBridge.swift
//  Lurelia
//
//
//  Wraps ActivityKit calls so the main app target compiles even before
//  the Widget Extension target is configured. Once you add LureliaWidgets
//  and include LureliaRoutineLiveActivity.swift there, everything lights up.
//

import Foundation
import SwiftData

#if canImport(ActivityKit)
import ActivityKit
#endif

final class LureliaLiveActivityBridge {
    static let shared = LureliaLiveActivityBridge()
    
    private init() {}
    
    #if canImport(ActivityKit)
    private var currentActivity: Activity<LureliaRoutineActivityAttributes>?
    #endif
    
    // MARK: - Start
    
    func start(
        routine: LureliaRoutine,
        run: LureliaRoutineRun
    ) {
        
        #if canImport(ActivityKit)
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        
        let endDate = endDateFor(routine: routine)
        
        let state = LureliaRoutineActivityAttributes.ContentState(
            routineName: routine.name,
            completedCount: 0,
            totalCount: run.totalCount,
            endDate: endDate,
            isFinished: false,
            colorHex: routine.colorHex
        )
        
        let attributes = LureliaRoutineActivityAttributes(
            routineID: routine.persistentModelID.hashValue.description
        )
        
        let content = ActivityContent(
            state: state,
            staleDate: endDate.addingTimeInterval(300)
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            #if !targetEnvironment(simulator)
            print("[LureliaLiveActivityBridge] start failed: \(error)")
            #endif
        }
        
        #endif
    }
    
    // MARK: - Update
    
    func update(
        routine: LureliaRoutine,
        run: LureliaRoutineRun
    ) {
        
        #if canImport(ActivityKit)
        
        guard let activity = currentActivity else {
            return
        }
        
        let endDate = endDateFor(routine: routine)
        
        let state = LureliaRoutineActivityAttributes.ContentState(
            routineName: routine.name,
            completedCount: run.completedCount,
            totalCount: run.totalCount,
            endDate: endDate,
            isFinished: run.allDone,
            colorHex: routine.colorHex
        )
        
        let content = ActivityContent(
            state: state,
            staleDate: endDate.addingTimeInterval(300)
        )
        
        Task {
            await activity.update(content)
        }
        
        #endif
    }
    
    // MARK: - End
    
    func end() {
        
        #if canImport(ActivityKit)
        
        guard let activity = currentActivity else {
            return
        }
        
        Task {
            await activity.end(
                nil,
                dismissalPolicy: .after(
                    Date().addingTimeInterval(5)
                )
            )
        }
        
        currentActivity = nil
        
        #endif
    }
    
    // MARK: - Helpers
    
    private func endDateFor(
        routine: LureliaRoutine
    ) -> Date {
        
        let calendar = Calendar.current
        
        var components = calendar.dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        
        components.hour = routine.endHour
        components.minute = routine.endMinute
        components.second = 0
        
        return calendar.date(from: components)
        ?? Date().addingTimeInterval(1800)
    }
}
