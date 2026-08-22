//
//  OfflineMutationQueue.swift
//  Lurelia
//
//  Persists shared-event mutations to the local SwiftData store when the
//  network call fails, then replays them in creation order on reconnect.
//  Backed by the `SyncState` model added in Phase 1A.1.
//
//  Usage pattern (see SharedEventsService+Offline):
//    do { try await service.createComment(...) }          // online path
//    catch { queue.enqueue(.createComment(payload)) }     // offline path
//
//  The queue is FIFO by `createdAt`. Retries use exponential backoff
//  capped at 5 minutes. A mutation is dropped after 20 failed attempts.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class OfflineMutationQueue: ObservableObject {
    static let shared = OfflineMutationQueue()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isDraining: Bool = false
    @Published private(set) var lastError: String?

    private var context: ModelContext?
    private var drainTask: Task<Void, Never>?

    private let maxAttempts = 20
    private let baseBackoffSeconds: TimeInterval = 2
    private let maxBackoffSeconds: TimeInterval = 300

    private init() {}

    func bind(to context: ModelContext) {
        self.context = context
        refreshPendingCount()
    }

    // MARK: - Enqueue

    /// Enqueue a mutation. The `payload` is serialized to JSON so the queue
    /// survives app restarts without model rehydration order dependencies.
    func enqueue(
        entityType: String,
        entityLocalID: String,
        entityRemoteID: String? = nil,
        operation: SyncOperationType,
        payload: [String: Any],
    ) {
        guard let context else { return }
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let row = SyncState(
            entityType: entityType,
            entityLocalID: entityLocalID,
            entityRemoteID: entityRemoteID,
            operation: operation,
            payloadJSON: json,
        )
        context.insert(row)
        try? context.save()
        refreshPendingCount()
    }

    // MARK: - Drain

    /// Kick off the drain. Idempotent — if a drain is already in flight,
    /// this is a no-op. Called on app foreground, on network-reachable
    /// events, and manually after enqueue.
    func startDraining(
        applyMutation: @escaping (SyncState) async throws -> String?,
    ) {
        guard drainTask == nil, context != nil else { return }
        isDraining = true
        drainTask = Task { @MainActor in
            defer {
                isDraining = false
                drainTask = nil
            }
            await drain(applyMutation: applyMutation)
        }
    }

    // MARK: - Internal drain loop

    private func drain(
        applyMutation: @escaping (SyncState) async throws -> String?,
    ) async {
        guard let context else { return }
        while !Task.isCancelled {
            let due = fetchDueMutations()
            guard !due.isEmpty else { break }

            for mutation in due {
                if Task.isCancelled { break }
                mutation.status = .sending
                mutation.lastAttemptedAt = Date()
                mutation.attemptCount += 1
                try? context.save()

                do {
                    let remoteID = try await applyMutation(mutation)
                    if let remoteID { mutation.entityRemoteID = remoteID }
                    context.delete(mutation)
                    try? context.save()
                    lastError = nil
                } catch {
                    mutation.lastError = String(describing: error)
                    if mutation.attemptCount >= maxAttempts {
                        // Give up. Mark as failed and remove.
                        context.delete(mutation)
                    } else {
                        mutation.status = .failed
                        mutation.nextRetryAt = Date().addingTimeInterval(
                            backoff(for: mutation.attemptCount),
                        )
                    }
                    try? context.save()
                    lastError = mutation.lastError
                }
            }
            refreshPendingCount()

            // Sleep briefly before the next batch so we don't tight-loop on
            // repeated failures.
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        refreshPendingCount()
    }

    private func fetchDueMutations() -> [SyncState] {
        guard let context else { return [] }
        let now = Date()
        let descriptor = FetchDescriptor<SyncState>(
            sortBy: [SortDescriptor(\.createdAt)],
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { m in
            switch m.status {
            case .idle, .conflict: return false
            case .pending: return true
            case .sending: return true
            case .failed:
                if let next = m.nextRetryAt { return now >= next }
                return true
            }
        }
    }

    private func backoff(for attempt: Int) -> TimeInterval {
        let exp = pow(2.0, Double(min(attempt, 8)))
        return min(baseBackoffSeconds * exp, maxBackoffSeconds)
    }

    private func refreshPendingCount() {
        guard let context else { return }
        let descriptor = FetchDescriptor<SyncState>()
        pendingCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Manual controls

    func cancelDrain() {
        drainTask?.cancel()
        drainTask = nil
        isDraining = false
    }

    /// Discard everything in the queue. Used by "reset sync" in settings.
    func clearAll() {
        guard let context else { return }
        let all = (try? context.fetch(FetchDescriptor<SyncState>())) ?? []
        for m in all { context.delete(m) }
        try? context.save()
        refreshPendingCount()
    }
}
