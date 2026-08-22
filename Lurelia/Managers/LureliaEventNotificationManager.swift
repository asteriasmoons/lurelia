//
//  LureliaEventNotificationManager.swift
//  Lurelia
//

import Foundation
import SwiftData
import UserNotifications
import Combine

@MainActor
final class LureliaEventNotificationManager: ObservableObject {
    static let shared = LureliaEventNotificationManager()

    private let notificationPrefix = "lurelia.event."
    private let maxPendingRequestsPerEvent = 64
    private let schedulingHorizon: TimeInterval = 366 * 24 * 60 * 60

    private init() {}

    func scheduleNotifications(for event: LureliaEvent) {
        let plan = schedulePlan(for: event)

        Task {
            await cancelNotifications(eventID: plan.eventID)

            guard !plan.notifications.isEmpty else { return }

            var requests: [UNNotificationRequest] = []
            for occurrence in plan.occurrences {
                for notification in plan.notifications {
                    guard requests.count < maxPendingRequestsPerEvent else { break }

                    let fireDate = occurrence.start.addingTimeInterval(TimeInterval(-notification.offsetMinutes * 60))
                    guard fireDate > Date() else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = plan.title
                    content.body = plan.body
                    content.sound = .default
                    content.userInfo = [
                        "eventID": plan.eventID.uuidString,
                        "eventNotificationID": notification.id.uuidString,
                        "eventOccurrenceStart": occurrence.start.timeIntervalSince1970
                    ]

                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let requestID = requestID(
                        eventID: plan.eventID,
                        notificationID: notification.id,
                        occurrenceStart: occurrence.start
                    )

                    requests.append(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
                }
            }

            for request in requests {
                do {
                    try await UNUserNotificationCenter.current().add(request)
                } catch {
                    print("❌ [LureliaEventNotificationManager] Event notification failed: \(error)")
                }
            }

            print("🔔 [LureliaEventNotificationManager] Scheduled \(requests.count) event notifications for '\(plan.title)'")
        }
    }

    func cancelNotifications(for event: LureliaEvent) {
        Task {
            await cancelNotifications(eventID: event.id)
        }
    }

    func rescheduleAll(from container: ModelContainer) {
        Task { @MainActor in
            let context = container.mainContext
            let descriptor = FetchDescriptor<LureliaEvent>()

            do {
                let events = try context.fetch(descriptor)
                await cancelAllEventNotifications()

                for event in events where !(event.notifications ?? []).isEmpty {
                    scheduleNotifications(for: event)
                }

                print("🔁 [LureliaEventNotificationManager] Rebuilding notifications for \(events.count) events")
            } catch {
                print("❌ [LureliaEventNotificationManager] Event reschedule fetch error: \(error)")
            }
        }
    }

    private func schedulePlan(for event: LureliaEvent) -> EventNotificationSchedulePlan {
        let now = Date()
        let interval = DateInterval(start: now, end: now.addingTimeInterval(schedulingHorizon))
        let occurrences = event.occurrences(in: interval)
            .sorted { $0.start < $1.start }

        let body = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
            ?? event.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
            ?? "Event starting soon."

        let notifications = (event.notifications ?? [])
            .filter(\.isEnabled)
            .map { EventNotificationSchedulePlan.Notification(id: $0.id, offsetMinutes: $0.offsetMinutes) }

        return EventNotificationSchedulePlan(
            eventID: event.id,
            title: event.title,
            body: body,
            notifications: notifications,
            occurrences: occurrences
        )
    }

    private func cancelNotifications(eventID: UUID) async {
        let eventPrefix = "\(notificationPrefix)\(eventID.uuidString)."
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(eventPrefix) }

        guard !ids.isEmpty else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        print("🧹 [LureliaEventNotificationManager] Cancelled \(ids.count) event notifications for \(eventID)")
    }

    private func cancelAllEventNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(notificationPrefix) }

        guard !ids.isEmpty else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        print("🧹 [LureliaEventNotificationManager] Cancelled \(ids.count) event notifications")
    }

    private func requestID(eventID: UUID, notificationID: UUID, occurrenceStart: Date) -> String {
        "\(notificationPrefix)\(eventID.uuidString).\(notificationID.uuidString).\(Int(occurrenceStart.timeIntervalSince1970))"
    }
}

private struct EventNotificationSchedulePlan {
    struct Notification {
        let id: UUID
        let offsetMinutes: Int
    }

    let eventID: UUID
    let title: String
    let body: String
    let notifications: [Notification]
    let occurrences: [LureliaEventOccurrence]
}

private extension String {
    var nonEmptyOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
