//
//  TinyNudgeService.swift
//  Lurelia
//

import Foundation

enum TinyNudgeTaskType: String, Codable {
    case reminder
    case habit
    case routine
}

struct TinyNudgeRequest: Codable {
    let taskType: TinyNudgeTaskType
    let taskName: String
    let friction: String
}

struct TinyNudgeResponse: Codable {
    let encouragement: String
    let frictionSuggestion: String
}

enum TinyNudgeServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Tiny Nudge URL."
        case .invalidResponse:
            return "Invalid Tiny Nudge response."
        case .serverError(let message):
            return message
        }
    }
}

final class TinyNudgeService {
    static let shared = TinyNudgeService()

    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink/api/tiny-nudge"

    func convinceMe(
        taskType: TinyNudgeTaskType,
        taskName: String,
        friction: String
    ) async throws -> TinyNudgeResponse {
        guard let url = URL(string: "\(baseURL)/convince-me") else {
            throw TinyNudgeServiceError.invalidURL
        }

        let payload = TinyNudgeRequest(
            taskType: taskType,
            taskName: taskName,
            friction: friction
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TinyNudgeServiceError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = try? JSONDecoder().decode(TinyNudgeErrorResponse.self, from: data)
            throw TinyNudgeServiceError.serverError(
                errorBody?.error ?? "Tiny Nudge failed with status \(httpResponse.statusCode)."
            )
        }

        return try JSONDecoder().decode(TinyNudgeResponse.self, from: data)
    }
}

private struct TinyNudgeErrorResponse: Codable {
    let error: String
}
