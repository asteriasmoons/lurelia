//
//  LureliaWidgetShared.swift
//  Lurelia
//

import Foundation
import SwiftData
import UIKit

enum LureliaWidgetShared {
    static let appGroupID = "group.com.asteriasmoons.Lurelia"
    static let sharedStoreFileName = "default.store"

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

    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Item.self,
            UserSettings.self,
            LureliaReminder.self,
            LureliaRoutine.self,
            LureliaRoutineTask.self,
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
        ])

        let configuration = ModelConfiguration(
            "LureliaShared",
            schema: schema,
            url: sharedStoreURL
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
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
}
