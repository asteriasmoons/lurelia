//
//  RoutineTaskDetailsService.swift
//  Lurelia
//

import Foundation

struct RoutineTaskDetailsFillObstacle: Codable, Hashable {
    var obstacle: String
    var solution: String
}

struct RoutineTaskDetailsFillRequest: Codable {
    var title: String
    var description: String
    var context: String
    var purpose: String
    var trigger: String
    var triggerType: String?
    var environment: String
    var reward: String
    var consequence: String
    var steps: [String]
    var supplies: [String]
    var obstacles: [RoutineTaskDetailsFillObstacle]
}

struct RoutineTaskDetailsFillResponse: Codable {
    var title: String
    var description: String
    var purpose: String
    var trigger: String
    var triggerType: String?
    var environment: String
    var reward: String
    var consequence: String
    var steps: [String]
    var supplies: [String]
    var obstacles: [RoutineTaskDetailsFillObstacle]
}

enum RoutineTaskDetailsServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid routine task details URL."
        case .invalidResponse:
            return "Invalid routine task details response."
        case .serverError(let message):
            return message
        }
    }
}

final class RoutineTaskDetailsService {
    static let shared = RoutineTaskDetailsService()

    private init() {}

    private let baseURL = "https://appapi.voxiverse.ink/api/routine-task-details"

    func fillDetails(_ payload: RoutineTaskDetailsFillRequest) async throws -> RoutineTaskDetailsFillResponse {
        guard let url = URL(string: "\(baseURL)/fill") else {
            throw RoutineTaskDetailsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoutineTaskDetailsServiceError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = try? JSONDecoder().decode(RoutineTaskDetailsErrorResponse.self, from: data)
            throw RoutineTaskDetailsServiceError.serverError(
                errorBody?.error ?? "Fill Details failed with status \(httpResponse.statusCode)."
            )
        }

        return try JSONDecoder().decode(RoutineTaskDetailsFillResponse.self, from: data)
    }
}

private struct RoutineTaskDetailsErrorResponse: Codable {
    let error: String
}
