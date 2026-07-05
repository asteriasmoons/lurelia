//
//  LureliaChallengeAnalysisService.swift
//  Lurelia
//

import Foundation

enum LureliaChallengeAnalysisService {

    // MARK: - Configuration

    private static let baseURL = "https://lystaria-api-production.up.railway.app"

    // MARK: - Request / Response

    struct AnalysisRequest: Encodable {
        let challengeName: String
        let identityStatement: String
        let progress: String
        let daysRemaining: Int
        let systemSteps: [String]
        let answers: [AnswerPair]

        struct AnswerPair: Encodable {
            let question: String
            let answer: String
        }
    }

    struct AnalysisResponse: Decodable {
        let reflection: String
        let strengths: String
        let systemInsight: String
        let nextStep: String
        let encouragement: String
    }

    // MARK: - API

    static func analyze(
        challengeName: String,
        identityStatement: String,
        progress: String,
        daysRemaining: Int,
        systemSteps: [String],
        answers: [(question: String, answer: String)]
    ) async throws -> AnalysisResponse {

        guard let url = URL(string: "\(baseURL)/api/challenge/analyze") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let body = AnalysisRequest(
            challengeName: challengeName,
            identityStatement: identityStatement,
            progress: progress,
            daysRemaining: daysRemaining,
            systemSteps: systemSteps,
            answers: answers.map {
                .init(question: $0.question, answer: $0.answer)
            }
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "LureliaChallengeAnalysis",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorText]
            )
        }

        return try JSONDecoder().decode(AnalysisResponse.self, from: data)
    }
}
