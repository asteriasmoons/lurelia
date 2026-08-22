//
//  SyncState.swift
//  Lurelia
//
//  A pending or in-flight mutation waiting to be replicated to vox-api.
//  Used by `SharedEventService`'s offline queue. On network loss, mutations
//  are appended here; on reconnect they're replayed in `createdAt` order.
//  Rows are deleted once acknowledged by the server.
//

import Foundation
import SwiftData

@Model
final class SyncState {
    var id: UUID = UUID()

    /// Model type name (e.g. "SharedEvent", "Comment") the mutation applies to.
    var entityType: String = ""

    /// The Swift UUID of the local record (as a string for CloudKit friendliness).
    var entityLocalID: String = ""

    /// The server-side remoteID when known — nil for pending creates.
    var entityRemoteID: String?

    /// Backing storage for `SyncOperationType`.
    var operationRaw: String = SyncOperationType.update.rawValue

    /// JSON payload sent to the server. Encoded here so the queue survives
    /// app restarts without model rehydration order dependencies.
    var payloadJSON: String = "{}"

    var createdAt: Date = Date()
    var lastAttemptedAt: Date?
    var nextRetryAt: Date?
    var attemptCount: Int = 0
    var lastError: String?

    /// Backing storage for `SyncStatus`.
    var statusRaw: String = SyncStatus.pending.rawValue

    init(
        entityType: String = "",
        entityLocalID: String = "",
        entityRemoteID: String? = nil,
        operation: SyncOperationType = .update,
        payloadJSON: String = "{}"
    ) {
        self.id = UUID()
        self.entityType = entityType
        self.entityLocalID = entityLocalID
        self.entityRemoteID = entityRemoteID
        self.operationRaw = operation.rawValue
        self.payloadJSON = payloadJSON
        self.createdAt = Date()
    }
}

extension SyncState {
    var operation: SyncOperationType {
        get { SyncOperationType(rawValue: operationRaw) ?? .update }
        set { operationRaw = newValue.rawValue }
    }

    var status: SyncStatus {
        get { SyncStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var shouldRetry: Bool {
        guard let nextRetryAt else { return status == .pending || status == .failed }
        return Date() >= nextRetryAt
    }
}
