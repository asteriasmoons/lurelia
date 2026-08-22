//
//  LureliaAPIConfig.swift
//  Lurelia
//
//  Canonical base URL for vox-api reads / writes coming out of the
//  Lurelia app. Kept as one constant so the shared event platform, the
//  Tiptap media uploader, and the (future) socket client all point at
//  the same host. Matches the pattern used by TinyNudgeService and
//  RoutineTaskDetailsService.
//

import Foundation

enum LureliaAPIConfig {
    /// Production vox-api origin.
    static let baseURLString: String = "https://appapi.voxiverse.ink"

    static var baseURL: URL {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid LureliaAPIConfig.baseURLString: \(baseURLString)")
        }
        return url
    }

    /// Path prefix for all `/api/lurelia/*` routes on vox-api.
    static let lureliaPathPrefix: String = "/api/lurelia"

    /// Convenience: build a full URL for a Lurelia route path (leading slash
    /// optional). Example: `route("/events")` → the events collection URL.
    static func route(_ path: String) -> URL {
        let normalized = path.hasPrefix("/") ? path : "/" + path
        return baseURL.appendingPathComponent(lureliaPathPrefix + normalized)
    }
}
