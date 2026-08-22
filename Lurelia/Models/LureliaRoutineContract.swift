//
//  LureliaRoutineContract.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaRoutineContractStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case completed = "Completed"
    case broken = "Broken"
    case renewed = "Renewed"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .active:
            return "checkwavy"
        case .completed:
            return "sparkleprogress"
        case .broken:
            return "xmarkwavy"
        case .renewed:
            return "repeatfill"
        }
    }
}

@Model
final class LureliaRoutineContract {
    // MARK: - Identity

    var persistentID: String = UUID().uuidString

    // MARK: - Routine Snapshot

    var routinePersistentID: String = ""
    var routineNameSnapshot: String = ""
    var routineIconSnapshot: String = "sparkle"
    var routineColorHexSnapshot: String = "#7d19f7"

    // MARK: - Contract

    var dateCommitted: Date = Date()
    var durationDays: Int = 30
    var contracteeName: String = ""
    var meaning: String = ""
    var decreeStatement: String = ""
    var consequences: String = ""
    var typedSignature: String = ""

    // MARK: - Status / History

    var statusRaw: String = LureliaRoutineContractStatus.active.rawValue
    var isCurrent: Bool = true
    var renewedFromContractID: String?
    var renewedAt: Date?
    var failedRoutineDayCount: Int = 0
    var failedRoutineDayKeysStorage: String = "[]"
    var brokenAt: Date?

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationship

    var routine: LureliaRoutine?

    init(
        routine: LureliaRoutine,
        dateCommitted: Date,
        durationDays: Int = 30,
        contracteeName: String,
        meaning: String,
        decreeStatement: String,
        consequences: String,
        typedSignature: String,
        renewedFromContractID: String? = nil
    ) {
        self.persistentID = UUID().uuidString
        self.routinePersistentID = routine.persistentID
        self.routineNameSnapshot = routine.name
        self.routineIconSnapshot = routine.icon
        self.routineColorHexSnapshot = routine.colorHex
        self.dateCommitted = dateCommitted
        self.durationDays = max(1, durationDays)
        self.contracteeName = contracteeName
        self.meaning = meaning
        self.decreeStatement = decreeStatement
        self.consequences = consequences
        self.typedSignature = typedSignature
        self.statusRaw = LureliaRoutineContractStatus.active.rawValue
        self.isCurrent = true
        self.renewedFromContractID = renewedFromContractID
        self.createdAt = Date()
        self.updatedAt = Date()
        self.routine = routine
    }

    var status: LureliaRoutineContractStatus {
        get {
            LureliaRoutineContractStatus(rawValue: statusRaw) ?? .active
        }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var committedDateText: String {
        dateCommitted.formatted(date: .abbreviated, time: .omitted)
    }

    var durationText: String {
        "\(durationDays) \(durationDays == 1 ? "day" : "days")"
    }

    var failedRoutineDayText: String {
        "\(failedRoutineDayCount) / 2"
    }

    var brokenDateText: String? {
        brokenAt?.formatted(date: .abbreviated, time: .shortened)
    }

    var failedRoutineDayKeys: Set<String> {
        get {
            guard let data = failedRoutineDayKeysStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return Set(decoded)
        }
        set {
            let sorted = Array(newValue).sorted()
            if let data = try? JSONEncoder().encode(sorted),
               let string = String(data: data, encoding: .utf8) {
                failedRoutineDayKeysStorage = string
                failedRoutineDayCount = sorted.count
            } else {
                failedRoutineDayKeysStorage = "[]"
                failedRoutineDayCount = 0
            }
        }
    }

    var routineDisplayName: String {
        routine?.name ?? routineNameSnapshot
    }

    var routineDisplayIcon: String {
        routine?.icon ?? routineIconSnapshot
    }

    var routineDisplayColorHex: String {
        routine?.colorHex ?? routineColorHexSnapshot
    }
}

extension LureliaRoutine {
    var sortedContracts: [LureliaRoutineContract] {
        (contracts ?? []).sorted {
            if $0.isCurrent != $1.isCurrent {
                return $0.isCurrent && !$1.isCurrent
            }
            return $0.dateCommitted > $1.dateCommitted
        }
    }

    var currentContract: LureliaRoutineContract? {
        sortedContracts.first { $0.isCurrent }
            ?? sortedContracts.first { $0.status == .active }
            ?? sortedContracts.first
    }

    @discardableResult
    func refreshCurrentContractStatusIfNeeded(
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard let contract = currentContract,
              contract.status == .active,
              contract.isCurrent else {
            return false
        }

        return evaluateActiveContract(contract, calendar: calendar, now: now)
    }

    private func evaluateActiveContract(
        _ contract: LureliaRoutineContract,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let firstDay = calendar.startOfDay(for: contract.dateCommitted)
        let lastDay = calendar.startOfDay(for: now)
        guard firstDay <= lastDay else { return false }

        var currentStreak = 0
        var failedDayKeys = contract.failedRoutineDayKeys
        var cursor = firstDay
        var didModify = false

        while cursor <= lastDay {
            guard let requiredTasks = requiredContractTasks(on: cursor, calendar: calendar) else {
                cursor = nextContractDay(after: cursor, calendar: calendar)
                continue
            }

            let dayKey = contractDayKey(cursor, calendar: calendar)
            if offDayKeys.contains(dayKey) {
                cursor = nextContractDay(after: cursor, calendar: calendar)
                continue
            }

            if routineTasksWereCompleted(on: cursor, tasks: requiredTasks, calendar: calendar) {
                currentStreak += 1

                if currentStreak >= max(1, contract.durationDays) {
                    contract.status = .completed
                    contract.updatedAt = now
                    return true
                }
            } else if shouldCountFailedRoutineDay(
                cursor,
                tasks: requiredTasks,
                calendar: calendar,
                now: now
            ) {
                currentStreak = 0

                if !failedDayKeys.contains(dayKey) {
                    failedDayKeys.insert(dayKey)
                    contract.failedRoutineDayKeys = failedDayKeys
                    didModify = true
                }

                if contract.failedRoutineDayCount >= 2 {
                    contract.status = .broken
                    contract.brokenAt = contract.brokenAt ?? now
                    contract.updatedAt = now
                    return true
                }
            }

            cursor = nextContractDay(after: cursor, calendar: calendar)
        }

        if didModify {
            contract.updatedAt = now
        }

        return didModify
    }

    private func requiredContractTasks(
        on day: Date,
        calendar: Calendar
    ) -> [LureliaRoutineTask]? {
        let dayStart = calendar.startOfDay(for: day)
        let weekday = calendar.component(.weekday, from: dayStart)

        if scheduleEnabled,
           !scheduledDays.isEmpty,
           !scheduledDays.contains(weekday) {
            return nil
        }

        let tasks = sortedTasks.filter { task in
            guard calendar.startOfDay(for: task.createdAt) <= dayStart else {
                return false
            }

            if task.repeatsOnDays,
               !task.scheduledDays.isEmpty,
               !task.scheduledDays.contains(weekday) {
                return false
            }

            return true
        }

        return tasks.isEmpty ? nil : tasks
    }

    private func routineTasksWereCompleted(
        on day: Date,
        tasks: [LureliaRoutineTask],
        calendar: Calendar
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)

        return tasks.allSatisfy { task in
            task.wasCompleted(on: dayStart, calendar: calendar)
        }
    }

    private func shouldCountFailedRoutineDay(
        _ day: Date,
        tasks: [LureliaRoutineTask],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: now)

        if dayStart < todayStart {
            return true
        }

        return tasks.contains { task in
            task.wasSkipped(on: dayStart, calendar: calendar)
        }
    }

    private func nextContractDay(
        after day: Date,
        calendar: Calendar
    ) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
    }

    private func contractDayKey(
        _ day: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

extension LureliaRoutineTask {
    func wasCompleted(
        on day: Date,
        calendar: Calendar = .current
    ) -> Bool {
        if let completedAt,
           calendar.isDate(completedAt, inSameDayAs: day) {
            return true
        }

        return (historyItems ?? []).contains { entry in
            entry.wasCompleted && calendar.isDate(entry.date, inSameDayAs: day)
        }
    }

    func wasSkipped(
        on day: Date,
        calendar: Calendar = .current
    ) -> Bool {
        if let skippedAt,
           calendar.isDate(skippedAt, inSameDayAs: day) {
            return true
        }

        return (historyItems ?? []).contains { entry in
            !entry.wasCompleted && calendar.isDate(entry.date, inSameDayAs: day)
        }
    }
}
