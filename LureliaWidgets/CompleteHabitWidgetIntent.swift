//
//  CompleteHabitWidgetIntent.swift
//  Lurelia
//

import Foundation
import AppIntents
import WidgetKit
import SwiftData

struct CompleteHabitWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Logs a completion for a habit from the widget.")

    @Parameter(title: "Habit ID")
    var habitID: String

    init() { }

    init(habitID: String) {
        self.habitID = habitID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else {
            return .result()
        }

        let container = try LureliaWidgetShared.makeModelContainer()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LureliaHabit>(
            predicate: #Predicate<LureliaHabit> { habit in
                habit.id == id
            }
        )

        guard let habit = try context.fetch(descriptor).first else {
            return .result()
        }

        logHabitCompletion(habit, in: context)
        try context.save()

        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")

        return .result()
    }

    private func logHabitCompletion(_ habit: LureliaHabit, in context: ModelContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let target = habit.target

        // Find today's existing log via relationship
        let existingLog = (habit.logs ?? []).first { log in
            calendar.isDate(log.dayStart, inSameDayAs: todayStart)
        }

        if let existingLog {
            guard existingLog.count < target else { return }
            existingLog.count += 1
            existingLog.updatedAt = Date()
        } else {
            let log = LureliaHabitLog(habit: habit, dayStart: todayStart, count: 1)
            context.insert(log)
        }

        // If completing, remove any skip for today
        if let todaySkip = (habit.skips ?? []).first(where: { skip in
            calendar.isDate(skip.dayStart, inSameDayAs: todayStart)
        }) {
            context.delete(todaySkip)
        }

        habit.updatedAt = Date()
    }
}
