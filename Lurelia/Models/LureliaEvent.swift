//
//  LureliaEvent.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaEvent {
    var id: UUID = UUID()
    var title: String = ""
    var eventDescription: String?
    var icon: String?
    var color: String = "#03dbfc"
    var categoryName: String?
    var startDate: Date = Date()
    var endDate: Date?
    var startTime: Date?
    var endTime: Date?
    var duration: TimeInterval = 3600
    var isAllDay: Bool = false
    var locationName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var notes: String?
    var appleEventIdentifier: String?
    /// Stable Lurelia-side key for an imported Apple event shadow. For
    /// one-off Apple events this is based on the EventKit event identifier.
    /// For recurring Apple occurrences this also includes the occurrence's
    /// start/end timestamps, so assigning one occurrence does not collapse the
    /// entire recurring series into a single local shadow.
    var appleOccurrenceKey: String?
    var appleCalendarIdentifier: String?
    /// Display title of the source Apple calendar (e.g. "Rare Days").
    /// Cached on the event at import time so the events list can show
    /// which Apple calendar an imported shadow event belongs to without
    /// needing to hit EventKit on every row render. Nil for events not
    /// imported from Apple, or for older records that predate this field —
    /// those will populate on the next Apple sync.
    var appleCalendarTitle: String?
    /// Hex color of the source Apple calendar. Imported Apple events do not
    /// have a Lurelia primary calendar, so this cache is the color authority
    /// for those shadow records in the app and widgets.
    var appleCalendarColor: String?
    var syncsWithAppleCalendar: Bool = false
    /// The `EKEvent.lastModifiedDate` we last synced with. Used by
    /// `LureliaEventService.importAppleEvents` to skip re-writing this row
    /// when Apple's copy hasn't changed since our last import — the check
    /// that keeps navigation snappy and stops needless writes on every tab
    /// switch. Nil for events that have never been synced.
    var lastAppleSyncAt: Date?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()

    /// JSON-encoded UUID list of *additional* calendars this event also
    /// belongs to. Stored as a String rather than an inverse many-to-many
    /// relationship so it plays nicely with CloudKit and preserves the
    /// existing single-relationship `calendar` (the Primary Calendar) — no
    /// destructive migration needed. Defaults to "[]" so existing events
    /// load safely with no additional calendars.
    var additionalCalendarIDsStorage: String = "[]"

    @Relationship(deleteRule: .cascade, inverse: \LureliaEventRecurrence.event)
    var recurrence: LureliaEventRecurrence?

    @Relationship(deleteRule: .cascade, inverse: \LureliaEventNotification.event)
    var notifications: [LureliaEventNotification]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaEventAttachment.event)
    var attachments: [LureliaEventAttachment]?

    @Relationship(deleteRule: .nullify, inverse: \LureliaEventTag.events)
    var tags: [LureliaEventTag]?

    @Relationship(deleteRule: .nullify, inverse: \LureliaCalendar.events)
    var calendar: LureliaCalendar?

    init(
        title: String = "",
        eventDescription: String? = nil,
        icon: String? = "starcal",
        color: String = "#03dbfc",
        categoryName: String? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        duration: TimeInterval = 3600,
        isAllDay: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.eventDescription = eventDescription
        self.icon = icon
        self.color = color
        self.categoryName = categoryName
        self.startDate = startDate
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.duration = max(0, duration)
        self.isAllDay = isAllDay
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
}

struct LureliaEventOccurrence: Identifiable, Hashable {
    let eventID: UUID
    let title: String
    let icon: String
    let colorHex: String
    let categoryName: String?
    /// Name of the Lurelia calendar this event belongs to, if any. Used by
    /// row / detail views so the user can see the calendar assignment at a
    /// glance. `nil` when the event isn't assigned to a calendar.
    let calendarName: String?
    let start: Date
    let end: Date
    let isAllDay: Bool
    let isAppleCalendarEvent: Bool

    var id: String {
        "\(eventID.uuidString)-\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)-\(isAppleCalendarEvent)"
    }
}

extension LureliaEvent {

    // MARK: - Primary + Additional Calendars
    //
    // `calendar` is the Primary Calendar — always single, always the color
    // authority. `additionalCalendarIDs` is a many-to-many-style extra list
    // stored as JSON so an event can also belong to other calendars for
    // filtering/navigation without changing its color.

    /// Additional (non-primary) calendars this event is a member of.
    /// The primary calendar's ID is never included here — enforced when
    /// writing via `setAdditionalCalendars(...)`.
    var additionalCalendarIDs: [UUID] {
        get {
            guard let data = additionalCalendarIDsStorage.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return raw.compactMap { UUID(uuidString: $0) }
        }
        set {
            let strings = newValue.map { $0.uuidString }
            if let data = try? JSONEncoder().encode(strings),
               let json = String(data: data, encoding: .utf8) {
                additionalCalendarIDsStorage = json
            } else {
                additionalCalendarIDsStorage = "[]"
            }
        }
    }

    /// Resolve `additionalCalendarIDs` against the supplied catalog of
    /// calendars. Missing IDs are silently skipped (e.g. calendar deleted).
    func additionalCalendars(from catalog: [LureliaCalendar]) -> [LureliaCalendar] {
        let ids = Set(additionalCalendarIDs)
        return catalog.filter { ids.contains($0.id) }
    }

    /// Write additional calendars in a single call while:
    ///   1. deduplicating,
    ///   2. dropping the current primary calendar's ID if present so the
    ///      primary is never also listed as an additional,
    ///   3. filtering out the event's own primary if the caller forgets.
    /// Callers use this any time either the primary OR the additionals list
    /// changes so the invariants hold.
    func setAdditionalCalendars(
        _ calendars: [LureliaCalendar],
        primaryOverride: LureliaCalendar? = nil
    ) {
        let primaryID = (primaryOverride ?? calendar)?.id
        var seen = Set<UUID>()
        var result: [UUID] = []
        for cal in calendars {
            if let pid = primaryID, cal.id == pid { continue }
            if seen.insert(cal.id).inserted {
                result.append(cal.id)
            }
        }
        additionalCalendarIDs = result
    }

    var displayIcon: String {
        icon?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? icon! : "starcal"
    }

    var colorHex: String {
        color.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "#03dbfc" : color
    }

    var resolvedAppleOccurrenceKey: String? {
        if let key = appleOccurrenceKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }

        guard let identifier = appleEventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty
        else {
            return nil
        }

        return LureliaEvent.appleShadowKey(
            appleEventIdentifier: identifier,
            occurrenceStart: startDate,
            occurrenceEnd: endDate ?? startDate.addingTimeInterval(max(0, duration)),
            isRecurring: false
        )
    }

    /// Preferred display color:
    /// - Lurelia-authored events use their Lurelia primary calendar color.
    /// - Apple-imported shadow events use their source Apple calendar color.
    /// - Older/unassigned rows fall back to the event's own stored color.
    var displayColorHex: String {
        if appleEventIdentifier != nil || appleCalendarIdentifier != nil,
           let appleColor = appleCalendarColor?.trimmingCharacters(in: .whitespacesAndNewlines),
           !appleColor.isEmpty {
            return appleColor
        }
        if let calendarColor = calendar?.color.trimmingCharacters(in: .whitespacesAndNewlines),
           !calendarColor.isEmpty {
            return calendarColor
        }
        return colorHex
    }

    func occurrenceStart(on day: Date? = nil, calendar: Calendar = .current) -> Date {
        let sourceDay = day ?? startDate
        if isAllDay {
            return calendar.startOfDay(for: sourceDay)
        }

        let timeSource = startTime ?? startDate
        return combinedDate(day: sourceDay, time: timeSource, calendar: calendar) ?? startDate
    }

    func occurrenceEnd(for start: Date, calendar: Calendar = .current) -> Date {
        if isAllDay {
            let sourceEnd = endDate ?? startDate
            let daySpan = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: sourceEnd)).day ?? 0)
            return calendar.date(byAdding: .day, value: daySpan + 1, to: calendar.startOfDay(for: start)) ?? start
        }

        if let endTime {
            return combinedDate(day: start, time: endTime, calendar: calendar) ?? start.addingTimeInterval(duration)
        }

        if let endDate, endDate > startDate {
            let delta = endDate.timeIntervalSince(startDate)
            return start.addingTimeInterval(delta)
        }

        return start.addingTimeInterval(max(0, duration))
    }

    func occurrences(in interval: DateInterval, calendar: Calendar = .current) -> [LureliaEventOccurrence] {
        if let recurrence {
            return recurringOccurrences(in: interval, recurrence: recurrence, calendar: calendar)
        }

        let start = occurrenceStart(calendar: calendar)
        let end = occurrenceEnd(for: start, calendar: calendar)
        let eventInterval = DateInterval(start: start, end: max(end, start.addingTimeInterval(60)))

        guard eventInterval.intersects(interval) else { return [] }
        return [makeOccurrence(start: start, end: end)]
    }

    private func recurringOccurrences(
        in interval: DateInterval,
        recurrence: LureliaEventRecurrence,
        calendar: Calendar
    ) -> [LureliaEventOccurrence] {
        var occurrences: [LureliaEventOccurrence] = []
        var candidateDay = calendar.startOfDay(for: startDate)
        let searchEnd = interval.end
        let excluded = Set(recurrence.excludedDates.map { calendar.startOfDay(for: $0) })
        var generatedCount = 0

        while candidateDay <= searchEnd {
            if matches(candidateDay, recurrence: recurrence, calendar: calendar) {
                generatedCount += 1

                if shouldStopRecurrence(
                    candidateDay: candidateDay,
                    generatedCount: generatedCount,
                    recurrence: recurrence,
                    calendar: calendar
                ) {
                    break
                }

                if !excluded.contains(calendar.startOfDay(for: candidateDay)) {
                    let start = occurrenceStart(on: candidateDay, calendar: calendar)
                    let end = occurrenceEnd(for: start, calendar: calendar)
                    let eventInterval = DateInterval(start: start, end: max(end, start.addingTimeInterval(60)))
                    if eventInterval.intersects(interval) {
                        occurrences.append(makeOccurrence(start: start, end: end))
                    }
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: candidateDay) else { break }
            candidateDay = next
        }

        return occurrences
    }

    private func shouldStopRecurrence(
        candidateDay: Date,
        generatedCount: Int,
        recurrence: LureliaEventRecurrence,
        calendar: Calendar
    ) -> Bool {
        switch recurrence.endType {
        case .never:
            return false
        case .onDate:
            guard let endDate = recurrence.endDate else { return false }
            return calendar.startOfDay(for: candidateDay) > calendar.startOfDay(for: endDate)
        case .afterOccurrences:
            guard let occurrenceCount = recurrence.occurrenceCount else { return false }
            return generatedCount > max(0, occurrenceCount)
        }
    }

    private func matches(_ day: Date, recurrence: LureliaEventRecurrence, calendar: Calendar) -> Bool {
        let startDay = calendar.startOfDay(for: startDate)
        guard day >= startDay else { return false }

        switch recurrence.frequency {
        case .daily:
            let days = calendar.dateComponents([.day], from: startDay, to: day).day ?? 0
            return days % max(1, recurrence.interval) == 0
        case .weekly:
            let weeks = calendar.dateComponents([.weekOfYear], from: startDay, to: day).weekOfYear ?? 0
            guard weeks % max(1, recurrence.interval) == 0 else { return false }
            let weekday = calendar.component(.weekday, from: day)
            let selected = recurrence.weekdays.map(\.rawValue)
            return selected.isEmpty ? weekday == calendar.component(.weekday, from: startDay) : selected.contains(weekday)
        case .monthly:
            let months = calendar.dateComponents([.month], from: startDay, to: day).month ?? 0
            guard months % max(1, recurrence.interval) == 0 else { return false }
            if let dayOfMonth = recurrence.dayOfMonth {
                return calendar.component(.day, from: day) == dayOfMonth
            }
            if let weekOfMonth = recurrence.weekOfMonth,
               let weekday = recurrence.weekdayOfMonth {
                return calendar.component(.weekday, from: day) == weekday.rawValue &&
                weekOrdinal(for: day, calendar: calendar) == weekOfMonth
            }
            return calendar.component(.day, from: day) == calendar.component(.day, from: startDay)
        case .yearly:
            let years = calendar.dateComponents([.year], from: startDay, to: day).year ?? 0
            guard years % max(1, recurrence.interval) == 0 else { return false }
            let targetMonth = recurrence.month ?? calendar.component(.month, from: startDay)
            let targetDay = recurrence.day ?? calendar.component(.day, from: startDay)
            return calendar.component(.month, from: day) == targetMonth &&
            calendar.component(.day, from: day) == targetDay
        }
    }

    private func weekOrdinal(for date: Date, calendar: Calendar) -> Int {
        let day = calendar.component(.day, from: date)
        let ordinal = ((day - 1) / 7) + 1
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return ordinal }
        return day + 7 > range.upperBound ? -1 : ordinal
    }

    private func combinedDate(day: Date, time: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0
        return calendar.date(from: components)
    }

    private func makeOccurrence(start: Date, end: Date) -> LureliaEventOccurrence {
        // Prefer the Lurelia primary calendar's name, then fall back to
        // the cached Apple calendar title for imported shadow events that
        // don't have a Lurelia primary assigned.
        let resolvedCalendarName: String? =
            calendar?.name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
            ?? appleCalendarTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil

        return LureliaEventOccurrence(
            eventID: id,
            title: title,
            icon: displayIcon,
            colorHex: displayColorHex,
            categoryName: categoryName,
            calendarName: resolvedCalendarName,
            start: start,
            end: end,
            isAllDay: isAllDay,
            isAppleCalendarEvent: appleEventIdentifier != nil
        )
    }
}

private extension String {
    var nonEmptyOrNil: String? {
        isEmpty ? nil : self
    }
}

extension LureliaEvent {
    static func appleShadowKey(
        appleEventIdentifier: String,
        occurrenceStart: Date,
        occurrenceEnd: Date,
        isRecurring: Bool
    ) -> String {
        let identifier = appleEventIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return "" }

        if isRecurring {
            let start = Int(occurrenceStart.timeIntervalSince1970)
            let end = Int(occurrenceEnd.timeIntervalSince1970)
            return "apple:\(identifier):occurrence:\(start):\(end)"
        }

        return "apple:\(identifier)"
    }

    static func appleShadowCandidates(
        in events: [LureliaEvent],
        appleEventIdentifier: String,
        appleOccurrenceKey: String
    ) -> [LureliaEvent] {
        let identifier = appleEventIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = appleOccurrenceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !key.isEmpty else { return [] }

        let exactMatches = events.filter {
            ($0.appleOccurrenceKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == key
        }
        if !exactMatches.isEmpty {
            return exactMatches
        }

        // Legacy fallback for rows created before `appleOccurrenceKey` existed.
        // Only rows without an occurrence key are considered here; keyed rows
        // must match by key so recurring occurrences remain separate.
        return events.filter {
            let storedIdentifier = ($0.appleEventIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let storedKey = ($0.appleOccurrenceKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return storedIdentifier == identifier && storedKey.isEmpty
        }
    }

    static func preferredAppleShadow(
        in events: [LureliaEvent],
        appleEventIdentifier: String,
        appleOccurrenceKey: String
    ) -> LureliaEvent? {
        appleShadowCandidates(
            in: events,
            appleEventIdentifier: appleEventIdentifier,
            appleOccurrenceKey: appleOccurrenceKey
        )
        .sorted { left, right in
            if (left.calendar != nil) != (right.calendar != nil) {
                return left.calendar != nil
            }
            return left.modifiedDate > right.modifiedDate
        }
        .first
    }
}
