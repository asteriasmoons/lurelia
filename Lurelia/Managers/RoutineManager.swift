//
//  RoutineManager.swift
//  Lurelia
//

import Foundation
import Combine
import UserNotifications
import SwiftData
import WidgetKit

@MainActor
final class RoutineManager: ObservableObject {
    static let shared = RoutineManager()
    
    private init() {}
    
    // MARK: - Daily Reset

    /// Resets routine task state and checked-off task-detail steps on day rollover.
    /// Call on app launch and when returning to foreground.
    func resetRoutinesIfNewDay(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        let descriptor = FetchDescriptor<LureliaRoutine>()
        guard let allRoutines = try? context.fetch(descriptor) else { return }

        var didModify = false
        for r in allRoutines {
            var didResetRoutine = false

            if r.refreshCurrentContractStatusIfNeeded(calendar: calendar, now: now) {
                didModify = true
            }

            for task in r.sortedTasks {
                let staleCompletedSteps = task.sortedSteps.filter {
                    $0.isCompleted && $0.updatedAt < todayStart
                }

                guard !staleCompletedSteps.isEmpty else { continue }

                for step in staleCompletedSteps {
                    step.resetCompletion()
                }

                if !task.isPending {
                    task.resetState()
                } else {
                    task.updatedAt = now
                }

                didResetRoutine = true
            }

            if !calendar.isDate(r.updatedAt, inSameDayAs: now) {
                if r.allTasksDone || (r.tasks ?? []).contains(where: { !$0.isPending }) {
                    r.resetTaskStates()
                    didResetRoutine = true
                }
            }

            if didResetRoutine {
                r.updatedAt = now
                didModify = true
            }
        }

        if didModify {
            try? context.save()
            LureliaWidgetReloads.reloadAll()
        }
    }

    // MARK: - Run a Routine
    
    func startRun(
        for routine: LureliaRoutine,
        context: ModelContext
    ) -> LureliaRoutineRun {
        
        // Reset any stale routines before starting a new run
        resetRoutinesIfNewDay(context: context)
        
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
                notes: task.notes,
                sortOrder: task.sortOrder
            )
            runTask.sourceStableTaskID = task.stableTaskID

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
    
    // MARK: - RUN PHASE ROUTINE
    func startPhaseRun(
        for routine: LureliaRoutine,
        phase: LureliaRoutinePhase,
        context: ModelContext
    ) -> LureliaRoutineRun {

        if let existing = (routine.runs ?? []).first(where: { $0.endedAt == nil }) {
            LureliaLiveActivityBridge.shared.update(
                routine: routine,
                run: existing
            )

            return existing
        }

        let run = LureliaRoutineRun(routine: routine)

        run.routineName = phase.name.isEmpty ? routine.name : phase.name
        run.routineIcon = phase.icon
        run.routineColorHex = routine.colorHex
        run.routineTimeOfDayRaw = routine.timeOfDay.rawValue

        context.insert(run)

        let phaseTasks = routine.tasksForPhase(phase)

        for (index, task) in phaseTasks.enumerated() {
            let runTask = LureliaRoutineRunTask(
                name: task.title,
                notes: task.notes,
                sortOrder: task.sortOrder
            )

            runTask.sourceStableTaskID = task.stableTaskID

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
            print("[RoutineManager] Failed saving new phase run: \(error)")
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

        let sourceStableTaskID = runTask.sourceStableTaskID

        if let sourceTask = routineTask(
            for: runTask,
            sourceStableTaskID: sourceStableTaskID,
            routine: routine
        ) {
            if let context = runTask.modelContext {
                RoutineTaskManager.shared.recordCompletion(
                    task: sourceTask,
                    context: context
                )
            } else {
                sourceTask.markCompleted()
                routine.refreshCurrentContractStatusIfNeeded()
            }
        }

        routine.updatedAt = Date()

        do {
            try runTask.modelContext?.save()
            LureliaWidgetReloads.reloadAll()
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

        let sourceStableTaskID = runTask.sourceStableTaskID

        if let sourceTask = routineTask(
            for: runTask,
            sourceStableTaskID: sourceStableTaskID,
            routine: routine
        ) {
            if let context = runTask.modelContext {
                RoutineTaskManager.shared.recordSkip(
                    task: sourceTask,
                    context: context
                )
            } else {
                sourceTask.markSkipped()
                routine.refreshCurrentContractStatusIfNeeded()
            }
        }

        routine.updatedAt = Date()

        do {
            try runTask.modelContext?.save()
            LureliaWidgetReloads.reloadAll()
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

    func completeRoutine(
        _ routine: LureliaRoutine,
        occurredAt: Date = Date(),
        context: ModelContext
    ) {
        for task in routine.sortedTasks where task.isPending {
            RoutineTaskManager.shared.recordCompletion(
                task: task,
                occurredAt: occurredAt,
                context: context
            )
        }

        routine.lastCompletedAt = occurredAt
        routine.updatedAt = Date()
        routine.refreshCurrentContractStatusIfNeeded()

        do {
            try context.save()
            LureliaWidgetReloads.reloadAll()
        } catch {
            print("[RoutineManager] Failed saving completed routine: \(error)")
        }
    }

    private func routineTask(
        for runTask: LureliaRoutineRunTask,
        sourceStableTaskID: String,
        routine: LureliaRoutine
    ) -> LureliaRoutineTask? {
        routine.sortedTasks.first { $0.stableTaskID == sourceStableTaskID }
            ?? routine.sortedTasks.first {
                $0.title == runTask.taskName && $0.sortOrder == runTask.sortOrder
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
    
    // MARK: - Permanent Routine Shutdown

    func deleteAndStopAllRoutinesForever(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()

        let routineDescriptor = FetchDescriptor<LureliaRoutine>()
        let reminderDescriptor = FetchDescriptor<LureliaReminder>()

        let routines = (try? context.fetch(routineDescriptor)) ?? []
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []

        let routineReminders = reminders.filter { $0.kind == .routine }

        let pendingRequests = await center.pendingNotificationRequests()
        let routinePendingIDs = pendingRequests
            .filter {
                $0.content.categoryIdentifier == "routine" ||
                $0.content.threadIdentifier.hasPrefix("routine-") ||
                $0.identifier.contains("-start-wd") ||
                $0.identifier.contains("-halfway-wd") ||
                $0.identifier.contains("-end-wd")
            }
            .map(\.identifier)

        let deliveredNotifications = await center.deliveredNotifications()
        let routineDeliveredIDs = deliveredNotifications
            .filter {
                $0.request.content.categoryIdentifier == "routine" ||
                $0.request.content.threadIdentifier.hasPrefix("routine-") ||
                $0.request.identifier.contains("-start-wd") ||
                $0.request.identifier.contains("-halfway-wd") ||
                $0.request.identifier.contains("-end-wd")
            }
            .map { $0.request.identifier }

        center.removePendingNotificationRequests(withIdentifiers: routinePendingIDs)
        center.removeDeliveredNotifications(withIdentifiers: routineDeliveredIDs)

        for routine in routines {
            await cancelNotifications(for: routine)

            routine.remindersEnabled = false
            routine.scheduledDays = []
            routine.startReminderNotificationIDs = []
            routine.halfwayReminderNotificationIDs = []
            routine.endReminderNotificationIDs = []

            context.delete(routine)
        }

        for reminder in routineReminders {
            LureliaNotificationManager.shared.cancelReminder(reminder)
            context.delete(reminder)
        }

        do {
            try context.save()
            LureliaWidgetReloads.reloadAll()
            LureliaWidgetReloads.reloadAll()
            print("✅ Deleted all routines and stopped routine schedules forever.")
        } catch {
            print("❌ Failed deleting routines forever: \(error)")
        }
    }
    
    func deleteAllRoutineNotifications(context: ModelContext) async {
        guard let routines = try? context.fetch(FetchDescriptor<LureliaRoutine>()) else {
            return
        }

        for routine in routines {
            await LureliaNotificationManager.shared.cancelRoutine(routine)
        }

        print("🧹 Deleted all routine notifications.")
    }

    // MARK: - Notifications
    
    func scheduleNotifications(
        for routine: LureliaRoutine
    ) async {
        // NOTE: Routine notification scheduling was permanently disabled here.
        // Commented out (kept for reference) so it can be restored if needed.
        //
        // await cancelNotifications(for: routine)
        //
        // routine.remindersEnabled = false
        // routine.scheduledDays = []
        // routine.startReminderNotificationIDs = []
        // routine.halfwayReminderNotificationIDs = []
        // routine.endReminderNotificationIDs = []
        //
        // print("[RoutineManager] Routine scheduling is permanently disabled.")
    }
    
    func cancelNotifications(
        for routine: LureliaRoutine
    ) async {
        
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers:
                    routine.startReminderNotificationIDs
                    + routine.halfwayReminderNotificationIDs
                    + routine.endReminderNotificationIDs
            )
        
        routine.startReminderNotificationIDs = []
        routine.halfwayReminderNotificationIDs = []
        routine.endReminderNotificationIDs = []
    }
}
