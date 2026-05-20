//
//  RoutineManager.swift
//  Lurelia
//

import Foundation
import Combine
import UserNotifications
import SwiftData

@MainActor
final class RoutineManager: ObservableObject {
    static let shared = RoutineManager()
    
    private init() {}
    
    // MARK: - Run a Routine
    
    func startRun(
        for routine: LureliaRoutine,
        context: ModelContext
    ) -> LureliaRoutineRun {
        
        // Keep active session alive if already running
        if let existing = (routine.runs ?? []).first(where: { $0.endedAt == nil }) {
            // Reset corrupt totalPausedSeconds if it exceeds the routine duration
            let maxPausedSeconds = TimeInterval(routine.durationMinutes * 60)
            if existing.totalPausedSeconds > maxPausedSeconds {
                existing.totalPausedSeconds = 0
                existing.pausedAt = nil
                existing.isPaused = false
            }
            
            LureliaLiveActivityBridge.shared.update(
                routine: routine,
                run: existing
            )
            
            return existing
        }
        
        let run = LureliaRoutineRun(routine: routine)
        context.insert(run)

        for (index, task) in routine.sortedTasks.enumerated() {
            let runTask = LureliaRoutineRunTask(
                name: task.title,
                sortOrder: index
            )

            context.insert(runTask)
            runTask.run = run
            if run.tasks == nil {
                run.tasks = []
            }
            run.tasks?.append(runTask)
        }

        do {
            try context.save()
        } catch {
            print("[RoutineManager] Failed saving new routine run: \(error)")
        }

        LureliaLiveActivityBridge.shared.start(
            routine: routine,
            run: run
        )

        return run
    }
    
    // MARK: - Pause / Resume
    
    func pauseRun(
        run: LureliaRoutineRun,
        routine: LureliaRoutine
    ) {
        guard run.endedAt == nil else { return }
        
        run.pause()
        
        LureliaLiveActivityBridge.shared.update(
            routine: routine,
            run: run
        )
    }
    
    func resumeRun(
        run: LureliaRoutineRun,
        routine: LureliaRoutine
    ) {
        guard run.endedAt == nil else { return }
        
        run.resume()
        
        LureliaLiveActivityBridge.shared.update(
            routine: routine,
            run: run
        )
    }
    
    // MARK: - Task Actions
    
    func completeTask(
        _ runTask: LureliaRoutineRunTask,
        run: LureliaRoutineRun,
        routine: LureliaRoutine
    ) {
        guard !run.isPaused else { return }
        
        runTask.state = "completed"
        do {
            try runTask.modelContext?.save()
        } catch {
            print("[RoutineManager] Failed saving completed routine task: \(error)")
        }
        
        LureliaLiveActivityBridge.shared.update(
            routine: routine,
            run: run
        )
        
        if run.allDone {
            finishRun(
                run: run,
                routine: routine,
                wasCompleted: true
            )
        }
    }
    
    func skipTask(
        _ runTask: LureliaRoutineRunTask,
        run: LureliaRoutineRun,
        routine: LureliaRoutine
    ) {
        guard !run.isPaused else { return }
        
        runTask.state = "skipped"
        do {
            try runTask.modelContext?.save()
        } catch {
            print("[RoutineManager] Failed saving skipped routine task: \(error)")
        }
        
        LureliaLiveActivityBridge.shared.update(
            routine: routine,
            run: run
        )
        
        if run.allDone {
            finishRun(
                run: run,
                routine: routine,
                wasCompleted: true
            )
        }
    }
    
    // MARK: - Finish
    
    func finishRun(
        run: LureliaRoutineRun,
        routine: LureliaRoutine,
        wasCompleted: Bool
    ) {
        if run.isPaused {
            run.resume()
        }
        
        run.endedAt = Date()
        run.wasCompleted = wasCompleted

        if let context = run.modelContext {
            applyRoutineTimeStats(
                routine: routine,
                wasCompleted: wasCompleted,
                context: context
            )

            do {
                try context.save()
            } catch {
                print("[RoutineManager] Failed saving finished routine run: \(error)")
            }
        } else {
            do {
                try run.modelContext?.save()
            } catch {
                print("[RoutineManager] Failed saving finished routine run: \(error)")
            }
        }

        LureliaLiveActivityBridge.shared.end()
    }
    
    // MARK: - Routine Stats

    private func applyRoutineTimeStats(
        routine: LureliaRoutine,
        wasCompleted: Bool,
        context: ModelContext
    ) {
        let stats = routineStats(in: context)
        let minutes = max(0, routine.durationMinutes)

        if wasCompleted {
            stats.routineTimeSpentMinutes += minutes
        } else {
            stats.routineTimeMissedMinutes += minutes
        }

        stats.updatedAt = Date()
    }

    private func routineStats(in context: ModelContext) -> LureliaRoutineStats {
        let descriptor = FetchDescriptor<LureliaRoutineStats>()

        do {
            if let existing = try context.fetch(descriptor).first {
                return existing
            }
        } catch {
            print("[RoutineManager] Failed fetching routine stats: \(error)")
        }

        let stats = LureliaRoutineStats()
        context.insert(stats)
        return stats
    }

    // MARK: - Notifications
    
    func scheduleNotifications(
        for routine: LureliaRoutine
    ) async {
        
        await cancelNotifications(for: routine)
        
        guard routine.scheduleEnabled else { return }
        guard !routine.scheduledDays.isEmpty else { return }
        
        var startIDs: [String] = []
        var endIDs: [String] = []
        
        for weekday in routine.scheduledDays {
            
            let startID = "\(routine.persistentModelID.hashValue)-start-wd\(weekday)"
            let endID = "\(routine.persistentModelID.hashValue)-end-wd\(weekday)"
            
            startIDs.append(startID)
            endIDs.append(endID)
            
            var startComps = DateComponents()
            startComps.weekday = weekday
            startComps.hour = routine.startHour
            startComps.minute = routine.startMinute
            
            var endComps = DateComponents()
            endComps.weekday = weekday
            endComps.hour = routine.endHour
            endComps.minute = routine.endMinute
            
            // MARK: - Start Notification
            
            let startContent = UNMutableNotificationContent()
            startContent.title = routine.name
            startContent.body = "Your \(routine.timeOfDay.rawValue.lowercased()) routine starts now."
            startContent.sound = .default
            
            startContent.userInfo = [
                "type": "routine",
                "routineID": routine.persistentModelID.hashValue
            ]
            
            // MARK: - End Notification
            
            let endContent = UNMutableNotificationContent()
            endContent.title = routine.name
            endContent.body = "Time's up on your \(routine.timeOfDay.rawValue.lowercased()) routine."
            endContent.sound = .default
            
            endContent.userInfo = [
                "type": "routine",
                "routineID": routine.persistentModelID.hashValue
            ]
            
            let startRequest = UNNotificationRequest(
                identifier: startID,
                content: startContent,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: startComps,
                    repeats: true
                )
            )
            
            let endRequest = UNNotificationRequest(
                identifier: endID,
                content: endContent,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: endComps,
                    repeats: true
                )
            )
            
            do {
                try await UNUserNotificationCenter.current()
                    .add(startRequest)
                
                try await UNUserNotificationCenter.current()
                    .add(endRequest)
                
            } catch {
                print(
                    "[RoutineManager] Failed scheduling weekday \(weekday): \(error)"
                )
            }
        }
        
        routine.startNotificationIDs = startIDs
        routine.endNotificationIDs = endIDs
    }
    
    func cancelNotifications(
        for routine: LureliaRoutine
    ) async {
        
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers:
                    routine.startNotificationIDs
                    + routine.endNotificationIDs
            )
        
        routine.startNotificationIDs = []
        routine.endNotificationIDs = []
    }
}
