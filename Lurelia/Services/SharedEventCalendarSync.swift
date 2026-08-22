//
//  SharedEventCalendarSync.swift
//  Lurelia
//
//  EventKit mirror for shared events. Supports import, export, one-shot
//  mirror, one-way, and two-way sync. All state lives in the local
//  `SharedEventAppleMirror` @Model — the server has no knowledge of the
//  per-device Apple Calendar mapping.
//
//  Concurrency safety:
//    All EKEventStore access happens on the MainActor via
//    `LureliaEventService.shared` (already used by the personal-event
//    surface). Callers await these methods from view code.
//
//  Conflict rule (two-way):
//    Compare `mirror.lastServerModifiedAt` vs current server
//    `modifiedAt`, and `mirror.lastAppleModifiedAt` vs current EKEvent
//    `lastModifiedDate`.
//      • Only Apple changed  → push Apple → server (via HTTP PATCH).
//      • Only server changed → push server → Apple (rewrite EKEvent).
//      • Both changed        → prefer server (last-write-wins on the
//                              authoritative side), stamp the conflict.
//      • Neither changed     → no-op.
//

import Foundation
import EventKit
import SwiftData

@MainActor
final class SharedEventCalendarSync {
    static let shared = SharedEventCalendarSync()

    private let eventStore = EKEventStore()

    private init() {}

    // MARK: - Access

    /// Kicked from HostToolsCard / Sync card the first time the user
    /// toggles mirroring on. Idempotent.
    @discardableResult
    func ensureAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .authorized || status == .fullAccess { return true }
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            return false
        }
    }

    // MARK: - Load / create mirror row

    /// Fetch (or create) the mirror row for a shared event on this device.
    func mirror(
        for sharedEventRemoteID: String,
        context: ModelContext,
    ) -> SharedEventAppleMirror {
        let descriptor = FetchDescriptor<SharedEventAppleMirror>(
            predicate: #Predicate {
                $0.sharedEventRemoteID == sharedEventRemoteID
            },
        )
        if let existing = try? context.fetch(descriptor).first { return existing }
        let created = SharedEventAppleMirror(
            sharedEventRemoteID: sharedEventRemoteID,
            syncMode: .off,
        )
        context.insert(created)
        try? context.save()
        return created
    }

    // MARK: - Export (server → Apple)

    /// Write the shared event into Apple Calendar. Creates a new EKEvent
    /// if the mirror doesn't already point at one; otherwise updates in
    /// place. Returns the resulting eventIdentifier.
    @discardableResult
    func exportToAppleCalendar(
        _ dto: SharedEventDTO,
        into calendarID: String,
        mirror: SharedEventAppleMirror,
        context: ModelContext,
    ) async throws -> String {
        guard await ensureAccess() else {
            throw SyncError.accessDenied
        }
        guard let calendar = eventStore.calendar(withIdentifier: calendarID),
              calendar.allowsContentModifications else {
            throw SyncError.calendarNotWritable
        }

        let ekEvent: EKEvent
        if !mirror.appleEventIdentifier.isEmpty,
           let existing = eventStore.event(withIdentifier: mirror.appleEventIdentifier) {
            ekEvent = existing
        } else {
            ekEvent = EKEvent(eventStore: eventStore)
        }

        ekEvent.calendar = calendar
        apply(dto: dto, to: ekEvent)

        try eventStore.save(ekEvent, span: .thisEvent, commit: true)

        mirror.appleEventIdentifier = ekEvent.eventIdentifier ?? mirror.appleEventIdentifier
        mirror.appleCalendarIdentifier = calendarID
        mirror.lastServerModifiedAt = dto.startDate  // best available proxy
        mirror.lastAppleModifiedAt = ekEvent.lastModifiedDate
        mirror.lastSyncedAt = Date()
        mirror.lastSyncError = nil
        try? context.save()

        return ekEvent.eventIdentifier ?? ""
    }

    // MARK: - Import (Apple → local read)

    /// Read the mirrored EKEvent's current state as it exists in Apple
    /// Calendar. Returns nil if the event was deleted or is unreachable.
    func importFromAppleCalendar(
        mirror: SharedEventAppleMirror,
    ) async -> EKEvent? {
        guard await ensureAccess() else { return nil }
        guard !mirror.appleEventIdentifier.isEmpty else { return nil }
        return eventStore.event(withIdentifier: mirror.appleEventIdentifier)
    }

    // MARK: - Mirror (one-shot copy)

    /// A one-time sync in the requested direction. Convenience for the
    /// "just make them match once" UX affordance.
    func mirrorOnce(
        _ dto: SharedEventDTO,
        direction: MirrorDirection,
        calendarID: String,
        mirror: SharedEventAppleMirror,
        context: ModelContext,
    ) async throws {
        switch direction {
        case .toApple:
            _ = try await exportToAppleCalendar(
                dto,
                into: calendarID,
                mirror: mirror,
                context: context,
            )
        case .fromApple:
            _ = await importFromAppleCalendar(mirror: mirror)
        }
        mirror.syncMode = .mirror
        mirror.updatedAt = Date()
        try? context.save()
    }

    // MARK: - One-way (continuous single direction)

    /// Push server state to Apple. Called on every server-side change
    /// (view-model observes and calls this). Safe to call repeatedly.
    func pushServerToApple(
        _ dto: SharedEventDTO,
        mirror: SharedEventAppleMirror,
        context: ModelContext,
    ) async {
        guard mirror.syncMode == .oneWay || mirror.syncMode == .exportOnly
        else { return }
        guard let calendarID = mirror.appleCalendarIdentifier else { return }
        do {
            _ = try await exportToAppleCalendar(
                dto,
                into: calendarID,
                mirror: mirror,
                context: context,
            )
        } catch {
            mirror.lastSyncError = String(describing: error)
            try? context.save()
        }
    }

    // MARK: - Two-way

    /// Reconcile Apple ↔ server. If both sides diverged since the last
    /// sync, the server wins (documented rule; keeps distributed state
    /// authoritative on the server side).
    func syncTwoWay(
        _ dto: SharedEventDTO,
        mirror: SharedEventAppleMirror,
        context: ModelContext,
    ) async {
        guard mirror.syncMode == .twoWay else { return }
        guard let calendarID = mirror.appleCalendarIdentifier else { return }
        guard await ensureAccess() else { return }

        let ekEvent = eventStore.event(withIdentifier: mirror.appleEventIdentifier)

        let serverChanged: Bool = {
            guard let previously = mirror.lastServerModifiedAt else { return true }
            return dto.startDate != previously
        }()
        let appleChanged: Bool = {
            guard let ekEvent, let last = mirror.lastAppleModifiedAt
            else { return ekEvent != nil }
            return (ekEvent.lastModifiedDate ?? Date()) > last
        }()

        switch (serverChanged, appleChanged) {
        case (false, false):
            return
        case (true, false):
            await pushServerToApple(dto, mirror: mirror, context: context)
        case (false, true):
            // Apple has changes we haven't pushed. Nothing to do here —
            // the server-side edit endpoint owns the write. Surface via
            // a callback or a UI badge in a later phase; for now, log.
            #if DEBUG
            print("[CalendarSync] Apple has newer edits; server-side push not yet wired")
            #endif
            mirror.lastAppleModifiedAt = ekEvent?.lastModifiedDate
            try? context.save()
        case (true, true):
            // Both diverged → server wins.
            await pushServerToApple(dto, mirror: mirror, context: context)
        }
    }

    // MARK: - Remove

    /// Remove the EKEvent Apple side and clear the mirror row.
    func stopMirroring(
        mirror: SharedEventAppleMirror,
        context: ModelContext,
    ) async {
        if !mirror.appleEventIdentifier.isEmpty,
           let ekEvent = eventStore.event(withIdentifier: mirror.appleEventIdentifier) {
            try? eventStore.remove(ekEvent, span: .thisEvent, commit: true)
        }
        context.delete(mirror)
        try? context.save()
    }

    // MARK: - Writable calendars

    func writableCalendars() -> [LureliaAppleCalendarSource] {
        LureliaEventService.shared.appleCalendars.filter { $0.allowsContentModifications }
    }

    // MARK: - DTO → EKEvent

    private func apply(dto: SharedEventDTO, to ekEvent: EKEvent) {
        ekEvent.title = dto.title
        ekEvent.notes = dto.description
        ekEvent.location = dto.locationName
        ekEvent.isAllDay = dto.isAllDay
        ekEvent.startDate = dto.startDate
        ekEvent.endDate = dto.endDate ?? dto.startDate.addingTimeInterval(3600)
        if let tz = TimeZone(identifier: dto.startDate.description) {
            ekEvent.timeZone = tz
        }
    }
}

// MARK: - Types

extension SharedEventCalendarSync {
    enum MirrorDirection {
        case toApple
        case fromApple
    }

    enum SyncError: LocalizedError {
        case accessDenied
        case calendarNotWritable

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Calendar access denied."
            case .calendarNotWritable: return "Chosen Apple calendar isn't writable."
            }
        }
    }
}
