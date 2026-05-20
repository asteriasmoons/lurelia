//
//  LureliaApp.swift
//  Lurelia
//

import SwiftUI
import SwiftData

@main
struct LureliaApp: App {
    @UIApplicationDelegateAdaptor(LureliaAppDelegate.self) var delegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserSettings.self,
            LureliaReminder.self,
            LureliaRoutine.self,
            LureliaTask.self,
            KanbanBoard.self,
            KanbanColumn.self,
            KanbanCard.self,
            LureliaHabit.self,
            LureliaHabitLog.self,
            LureliaHabitSkip.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await backfillReminderFireTimes()
                    HabitManager.shared.setup(container: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // Backfills timesOfDay and primaryHour/primaryMinute for all existing reminders
    // that were created before these fields existed. Runs once on launch, is a no-op
    // for reminders already backfilled.
    private func backfillReminderFireTimes() async {
        let context = sharedModelContainer.mainContext
        let cal = Calendar.current
        guard let reminders = try? context.fetch(FetchDescriptor<LureliaReminder>()) else { return }

        var changed = false
        for reminder in reminders {
            // Already backfilled
            if !reminder.timesOfDay.isEmpty && reminder.primaryHour != -1 { continue }

            let scheduledDate = reminder.scheduledDate

            // Derive primary hour/minute from scheduledDate
            let ph = reminder.primaryHour != -1
                ? reminder.primaryHour
                : cal.component(.hour, from: scheduledDate)
            let pm = reminder.primaryMinute != -1
                ? reminder.primaryMinute
                : cal.component(.minute, from: scheduledDate)

            if reminder.primaryHour == -1 {
                reminder.primaryHour = ph
                reminder.primaryMinute = pm
            }

            if reminder.timesOfDay.isEmpty {
                var times = [String(format: "%02d:%02d", ph, pm)]
                for ft in reminder.additionalFireTimes {
                    times.append(String(format: "%02d:%02d", ft.hour, ft.minute))
                }
                reminder.timesOfDay = times
            }

            changed = true
        }

        if changed {
            try? context.save()
            print("[Lurelia] Backfilled timesOfDay for existing reminders")
        }
    }
}
