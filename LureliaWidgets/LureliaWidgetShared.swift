//
//  LureliaWidgetShared.swift
//  Lurelia
//

import Foundation
import AlarmKit
import SQLite3
import SwiftData
import UIKit

@available(iOS 26.0, *)
struct LureliaReminderAlarmMetadata: AlarmMetadata {
    let reminderID: UUID
    let notificationID: String
    let title: String
    let icon: String
}

@available(iOS 26.0, *)
struct LureliaHabitAlarmMetadata: AlarmMetadata {
    let habitID: UUID
    let title: String
    let icon: String
}

@available(iOS 26.0, *)
struct LureliaRoutineTaskAlarmMetadata: AlarmMetadata {
    let stableTaskID: String
    let routineName: String
    let title: String
    let icon: String
}

struct LureliaWidgetAppleCalendarSnapshot: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let colorHex: String
    let allowsContentModifications: Bool
}

struct LureliaWidgetExternalEventSnapshot: Codable, Hashable, Identifiable {
    let id: String
    let appleEventIdentifier: String
    let appleOccurrenceKey: String?
    let calendarIdentifier: String
    let calendarTitle: String
    let title: String
    let colorHex: String
    let start: Date
    let end: Date
    let isAllDay: Bool
}

enum LureliaWidgetShared {
    static let appGroupID = "group.com.asteriasmoons.Lurelia"
    static let sharedStoreFileName = "default.store"
    private static let appleCalendarsSnapshotKey = "lurelia.widget.appleCalendars.v1"
    private static let externalEventsSnapshotKey = "lurelia.widget.externalEvents.v1"
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static var widgetIconsDirectoryURL: URL {
        appGroupContainerURL.appendingPathComponent("widget_icons", isDirectory: true)
    }

    static func iconURL(for iconName: String) -> URL {
        widgetIconsDirectoryURL.appendingPathComponent("\(iconName).png")
    }

    static func widgetIcon(for iconName: String) -> UIImage? {
        let url = iconURL(for: iconName)

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else {
            return nil
        }

        return image
    }

    @discardableResult
    static func saveAppleCalendarSnapshots(_ snapshots: [LureliaWidgetAppleCalendarSnapshot]) -> Bool {
        let normalized = snapshots
            .map {
                LureliaWidgetAppleCalendarSnapshot(
                    id: $0.id.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    colorHex: $0.colorHex.trimmingCharacters(in: .whitespacesAndNewlines),
                    allowsContentModifications: $0.allowsContentModifications
                )
            }
            .filter { !$0.id.isEmpty && !$0.title.isEmpty }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        guard let data = try? JSONEncoder().encode(normalized),
              let defaults = UserDefaults(suiteName: appGroupID)
        else {
            return false
        }

        if defaults.data(forKey: appleCalendarsSnapshotKey) == data {
            return false
        }

        defaults.set(data, forKey: appleCalendarsSnapshotKey)
        return true
    }

    static func loadAppleCalendarSnapshots() -> [LureliaWidgetAppleCalendarSnapshot] {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: appleCalendarsSnapshotKey),
              let decoded = try? JSONDecoder().decode([LureliaWidgetAppleCalendarSnapshot].self, from: data)
        else {
            return []
        }

        return decoded
    }

    @discardableResult
    static func saveExternalEventSnapshots(_ snapshots: [LureliaWidgetExternalEventSnapshot]) -> Bool {
        let normalized = snapshots
            .map {
                LureliaWidgetExternalEventSnapshot(
                    id: $0.id.trimmingCharacters(in: .whitespacesAndNewlines),
                    appleEventIdentifier: $0.appleEventIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    appleOccurrenceKey: $0.appleOccurrenceKey?.trimmingCharacters(in: .whitespacesAndNewlines),
                    calendarIdentifier: $0.calendarIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    calendarTitle: $0.calendarTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    colorHex: $0.colorHex.trimmingCharacters(in: .whitespacesAndNewlines),
                    start: $0.start,
                    end: $0.end,
                    isAllDay: $0.isAllDay
                )
            }
            .filter { !$0.id.isEmpty && !$0.calendarIdentifier.isEmpty && !$0.title.isEmpty }
            .sorted { $0.start < $1.start }

        guard let data = try? JSONEncoder().encode(normalized),
              let defaults = UserDefaults(suiteName: appGroupID)
        else {
            return false
        }

        if defaults.data(forKey: externalEventsSnapshotKey) == data {
            return false
        }

        defaults.set(data, forKey: externalEventsSnapshotKey)
        return true
    }

    static func loadExternalEventSnapshots() -> [LureliaWidgetExternalEventSnapshot] {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: externalEventsSnapshotKey),
              let decoded = try? JSONDecoder().decode([LureliaWidgetExternalEventSnapshot].self, from: data)
        else {
            return []
        }

        return decoded
    }

    static var appGroupContainerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("Could not access App Group container: \(appGroupID)")
        }

        return url
    }

    static var sharedStoreURL: URL {
        appGroupContainerURL.appendingPathComponent(sharedStoreFileName)
    }

    static var sharedSchema: Schema {
        Schema([
            Item.self,
            UserSettings.self,
            LureliaReminder.self,
            LureliaRoutine.self,
            LureliaRoutineContract.self,
            LureliaRoutineTask.self,
            RoutineTaskTemplate.self,
            LureliaRoutineTaskStep.self,
            LureliaRoutineTaskSupply.self,
            LureliaRoutineTaskObstacle.self,
            LureliaRoutineTaskHistoryEntry.self,
            LureliaRoutineRunTask.self,
            LureliaRoutineRun.self,
            LureliaRoutineStats.self,
            LureliaTask.self,
            KanbanBoard.self,
            KanbanColumn.self,
            KanbanCard.self,
            LureliaHabit.self,
            LureliaHabitLog.self,
            LureliaHabitSkip.self,
            LureliaEvent.self,
            LureliaEventRecurrence.self,
            LureliaEventNotification.self,
            LureliaEventAttachment.self,
            LureliaEventTag.self,
            LureliaCalendar.self,
            LureliaChallenge.self,
            LureliaChallengeAction.self,
            LureliaChallengeSystemStep.self,
            LureliaChallengeEntry.self,
            LureliaChallengeProgressReport.self,
            LureliaChallengeReportResponse.self,
            LureliaJourney.self,
            LureliaJourneyCheckIn.self,
            LureliaJourneyMilestone.self,
            LureliaJourneyStep.self,
            LureliaJourneyTimelineItem.self,
            LureliaJourneyNote.self,
            LureliaReminderHistory.self,
            LureliaPractice.self,
            LureliaRoutinePhase.self,
            // MARK: - Shared Event Platform (Prompt 1A.1)
            SharedEvent.self,
            SharedCalendar.self,
            Attendee.self,
            Invitation.self,
            Comment.self,
            CommentReply.self,
            CommentReaction.self,
            RSVP.self,
            Host.self,
            Permissions.self,
            SyncState.self,
            NotificationSubscription.self,
            Attachment.self,
            EventArtwork.self,
            Announcement.self,
            EventPost.self,
            SharedEventAppleMirror.self,
        ])
    }

    static func makeModelContainer() throws -> ModelContainer {
        let schema = sharedSchema
        let configuration = ModelConfiguration(
            "LureliaShared",
            schema: schema,
            url: sharedStoreURL
        )

        // Attempt 1: open the store as-is.
        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            print("[LureliaWidgetShared] Initial ModelContainer load failed: \(error)")
        }

        // Attempt 2: SQL-repair duplicate CloudKit metadata rows and retry.
        if repairCloudKitRecordMetadataDuplicates(at: sharedStoreURL) {
            print("[LureliaWidgetShared] Retrying ModelContainer load after CloudKit metadata repair.")
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [configuration]
                )
            } catch {
                print("[LureliaWidgetShared] Retry after metadata repair still failed: \(error)")
            }
        }

        // Attempt 3: the store is unrecoverable through in-place migration.
        // Move the corrupt store aside so SwiftData/CloudKit can rebuild a
        // fresh one. NSPersistentCloudKitContainer will re-download records
        // from iCloud on next launch.
        do {
            try backupAndResetCorruptStore(at: sharedStoreURL)
            print("[LureliaWidgetShared] Reset corrupt store; retrying ModelContainer load with fresh store.")
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            print("[LureliaWidgetShared] Reset-and-rebuild failed: \(error)")
            throw error
        }
    }

    private static func backupAndResetCorruptStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let storeDirectory = storeURL.deletingLastPathComponent()
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupDirectory = storeDirectory.appendingPathComponent(
            "corrupt-store-\(timestamp)",
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )

        let suffixes = [
            "",
            "-wal",
            "-shm",
            "-ckAssets",
            "-ckAssets-wal",
            "-ckAssets-shm"
        ]

        for suffix in suffixes {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            let destination = backupDirectory.appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: source, to: destination)
        }

        print("[LureliaWidgetShared] Backed up corrupt store to \(backupDirectory.path)")
    }

    static func migrateLocalStoreToAppGroupIfNeeded() {
        let defaultsKey = "didMigrateLocalSwiftDataStoreToAppGroup_v2"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultsKey) else { return }

        let fileManager = FileManager.default
        let destination = sharedStoreURL

        guard !fileManager.fileExists(atPath: destination.path) else {
            defaults.set(true, forKey: defaultsKey)
            return
        }

        let searchRoots = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        let oldStoreURL = searchRoots
            .flatMap { root -> [URL] in
                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { return [] }

                var matches: [URL] = []
                while let url = enumerator.nextObject() as? URL {
                    let name = url.lastPathComponent
                    guard name == sharedStoreFileName else { continue }
                    guard !url.path.contains("/Shared/AppGroup/") else { continue }
                    guard url.path != destination.path else { continue }
                    matches.append(url)
                }
                return matches
            }
            .first

        guard let oldStoreURL else {
            print("[LureliaWidgetShared] No local SwiftData store found to migrate.")
            return
        }

        do {
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: oldStoreURL.path + suffix)
                let target = URL(fileURLWithPath: destination.path + suffix)

                guard fileManager.fileExists(atPath: source.path) else { continue }

                if fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }

                try fileManager.copyItem(at: source, to: target)
            }

            defaults.set(true, forKey: defaultsKey)
            print("[LureliaWidgetShared] Migrated local SwiftData store to App Group: \(oldStoreURL.path)")
        } catch {
            print("[LureliaWidgetShared] Failed to migrate local SwiftData store: \(error)")
        }
    }

    private static func repairCloudKitRecordMetadataDuplicates(at storeURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return false }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard openResult == SQLITE_OK, let database else {
            if let database {
                print("[LureliaWidgetShared] SQLite open failed: \(String(cString: sqlite3_errmsg(database)))")
                sqlite3_close(database)
            }
            return false
        }

        defer { sqlite3_close(database) }

        guard sqliteTableExists("ANSCKRECORDMETADATA", in: database) else {
            return false
        }

        let repairSQL = """
        DELETE FROM ANSCKRECORDMETADATA
        WHERE Z_PK NOT IN (
            SELECT MIN(Z_PK)
            FROM ANSCKRECORDMETADATA
            GROUP BY ZENTITYID, ZENTITYPK
        );
        DELETE FROM ANSCKRECORDMETADATA
        WHERE Z_PK NOT IN (
            SELECT MIN(Z_PK)
            FROM ANSCKRECORDMETADATA
            GROUP BY ZCKRECORDID
        );
        PRAGMA wal_checkpoint(TRUNCATE);
        VACUUM;
        """

        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, repairSQL, nil, nil, &errorMessage)

        if result != SQLITE_OK {
            if let errorMessage {
                print("[LureliaWidgetShared] CloudKit metadata repair failed: \(String(cString: errorMessage))")
                sqlite3_free(errorMessage)
            }
            return false
        }

        print("[LureliaWidgetShared] Repaired duplicate CloudKit metadata rows in ANSCKRECORDMETADATA.")
        return true
    }

    private static func sqliteTableExists(_ tableName: String, in database: OpaquePointer) -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, tableName, -1, sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }
}
