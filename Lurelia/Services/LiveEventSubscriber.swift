//
//  LiveEventSubscriber.swift
//  Lurelia
//
//  Subscribes to live updates for one shared event while its detail view
//  is open. Current implementation polls `/api/lurelia/sync/:eventID`
//  every N seconds with a `since` cursor. Upgrade path to Socket.IO is a
//  single file swap — the surface (`subscribe`, `unsubscribe`, `onChange`)
//  stays the same.
//
//  Emits a single `.snapshotChanged` value on each poll so views can
//  reload from the returned bundle. Views should treat the emissions as
//  invalidation cues, not diffs — the shared event detail view already
//  reloads its full state cheaply.
//

import Foundation
import Combine

@MainActor
final class LiveEventSubscriber: ObservableObject {
    /// Payload delivered when the server has new state for an event.
    struct Snapshot: Decodable {
        let cursor: String?
        let event: SharedEventDTO?
        let attendees: [AttendeeDTO]
        let rsvps: [RSVPDTO]
        let comments: [CommentDTO]
        let posts: [EventPostDTO]
        let announcements: [AnnouncementDTO]

        enum CodingKeys: String, CodingKey {
            case cursor, event, attendees, rsvps, comments, posts, announcements
        }
    }

    // A stream views listen to for invalidation cues.
    let changes = PassthroughSubject<Snapshot, Never>()

    private let session: URLSession
    private let decoder: JSONDecoder

    private var pollTask: Task<Void, Never>?
    private var sinceCursor: String?
    private var pollIntervalSeconds: TimeInterval = 3

    init(session: URLSession = .shared) {
        self.session = session
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Subscription lifecycle

    func subscribe(eventID: String, interval: TimeInterval = 3) {
        unsubscribe()
        pollIntervalSeconds = interval
        pollTask = Task { @MainActor in
            await pollLoop(eventID: eventID)
        }
    }

    func unsubscribe() {
        pollTask?.cancel()
        pollTask = nil
        sinceCursor = nil
    }

    // MARK: - Internal

    private func pollLoop(eventID: String) async {
        while !Task.isCancelled {
            await tick(eventID: eventID)
            let nanos = UInt64(pollIntervalSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }
    }

    private func tick(eventID: String) async {
        var comps = URLComponents(
            url: LureliaAPIConfig.route("/sync/\(eventID)"),
            resolvingAgainstBaseURL: false,
        )!
        if let sinceCursor {
            comps.queryItems = [URLQueryItem(name: "since", value: sinceCursor)]
        }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return
            }
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            if let c = snapshot.cursor { sinceCursor = c }

            // Only emit if there's genuinely new content since last poll.
            if hasNewContent(snapshot) {
                changes.send(snapshot)
            }
        } catch {
            #if DEBUG
            print("[LiveEventSubscriber] poll failed:", error)
            #endif
        }
    }

    private func hasNewContent(_ snapshot: Snapshot) -> Bool {
        snapshot.event != nil
            || !snapshot.attendees.isEmpty
            || !snapshot.rsvps.isEmpty
            || !snapshot.comments.isEmpty
            || !snapshot.posts.isEmpty
            || !snapshot.announcements.isEmpty
    }
}
