//
//  SharedEventsService+Offline.swift
//  Lurelia
//
//  Wraps the raw HTTP methods on `SharedEventsService` with the offline
//  queue: if the network call throws (URLError, timeout, or 5xx), the
//  mutation is persisted to `SyncState` and will replay on reconnect.
//  Callers that want fire-and-forget offline semantics call the `enqueue`
//  variants below.
//
//  Callers that need the round-trip result (e.g. to insert the returned
//  DTO into a view) should keep calling the raw methods on
//  SharedEventsService and only fall back to enqueue on failure.
//

import Foundation

extension SharedEventsService {
    /// Post an RSVP with offline fallback. Returns true if the write hit
    /// the server; false if it was queued locally.
    @discardableResult
    func setRSVPWithOfflineFallback(
        eventID: String,
        userID: String,
        displayName: String,
        status: String,
        note: String? = nil,
    ) async -> Bool {
        do {
            try await setRSVP(
                eventID: eventID,
                userID: userID,
                displayName: displayName,
                status: status,
                note: note,
            )
            return true
        } catch {
            OfflineMutationQueue.shared.enqueue(
                entityType: "RSVP",
                entityLocalID: UUID().uuidString,
                operation: .update,
                payload: [
                    "endpoint": "setRSVP",
                    "eventID": eventID,
                    "userID": userID,
                    "displayName": displayName,
                    "status": status,
                    "note": note ?? "",
                ],
            )
            return false
        }
    }

    /// Post a comment with offline fallback.
    @discardableResult
    func createCommentWithOfflineFallback(
        eventID: String,
        authorUserID: String,
        authorDisplayName: String,
        body: String,
    ) async -> Bool {
        do {
            _ = try await createComment(
                eventID: eventID,
                authorUserID: authorUserID,
                authorDisplayName: authorDisplayName,
                body: body,
            )
            return true
        } catch {
            OfflineMutationQueue.shared.enqueue(
                entityType: "Comment",
                entityLocalID: UUID().uuidString,
                operation: .create,
                payload: [
                    "endpoint": "createComment",
                    "eventID": eventID,
                    "authorUserID": authorUserID,
                    "authorDisplayName": authorDisplayName,
                    "body": body,
                ],
            )
            return false
        }
    }

    /// Replay handler passed to `OfflineMutationQueue.startDraining`.
    /// Returns the server-assigned remote ID (if the endpoint returns one)
    /// so the queue can stamp the SyncState row before deleting it.
    static func replay(mutation: SyncState) async throws -> String? {
        guard
            let payloadData = mutation.payloadJSON.data(using: .utf8),
            let payload = try JSONSerialization.jsonObject(with: payloadData)
                as? [String: Any],
            let endpoint = payload["endpoint"] as? String
        else {
            throw NSError(
                domain: "OfflineMutationQueue",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Malformed payload"],
            )
        }

        let service = SharedEventsService.shared
        switch endpoint {
        case "setRSVP":
            try await service.setRSVP(
                eventID: payload["eventID"] as? String ?? "",
                userID: payload["userID"] as? String ?? "",
                displayName: payload["displayName"] as? String ?? "",
                status: payload["status"] as? String ?? "pending",
                note: payload["note"] as? String,
            )
            return nil
        case "createComment":
            let comment = try await service.createComment(
                eventID: payload["eventID"] as? String ?? "",
                authorUserID: payload["authorUserID"] as? String ?? "",
                authorDisplayName: payload["authorDisplayName"] as? String ?? "",
                body: payload["body"] as? String ?? "",
            )
            return comment.id
        default:
            throw NSError(
                domain: "OfflineMutationQueue",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unknown endpoint: \(endpoint)",
                ],
            )
        }
    }
}
