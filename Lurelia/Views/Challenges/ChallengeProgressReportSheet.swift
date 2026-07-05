//
//  ChallengeProgressReportSheet.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct ChallengeProgressReportSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let challenge: LureliaChallenge

    @State private var difficultyRating: Int = 3

    @State private var answer1: String = ""
    @State private var answer2: String = ""
    @State private var answer3: String = ""
    @State private var answer4: String = ""
    @State private var answer5: String = ""
    @State private var answer6: String = ""

    @State private var isAnalyzing: Bool = false
    @State private var analysisResult: LureliaChallengeAnalysisService.AnalysisResponse?
    @State private var analysisError: String?

    private let questions: [String] = [
        "How difficult are you finding this challenge?",
        "What action seems less intimidating right now?",
        "In your own words, describe the simplest way to complete the first action.",
        "What step could you take right now to make just a little progress?",
        "What is currently making this challenge harder?",
        "What has gone well so far?"
    ]

    private var canSubmit: Bool {
        !answer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer4.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer5.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer6.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        headerCard

                        difficultyCard

                        questionCard(
                            title: questions[0],
                            answer: $answer1
                        )

                        questionCard(
                            title: questions[1],
                            answer: $answer2
                        )

                        questionCard(
                            title: questions[2],
                            answer: $answer3
                        )

                        questionCard(
                            title: questions[3],
                            answer: $answer4
                        )

                        questionCard(
                            title: questions[4],
                            answer: $answer5
                        )

                        questionCard(
                            title: questions[5],
                            answer: $answer6
                        )

                        analyzeButton

                        if let result = analysisResult {
                            analysisResultView(result)
                        }

                        if let error = analysisError {
                            analysisErrorView(error)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        GlassCard {
            VStack(spacing: 12) {

                Image("linedpages")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 34, height: 34)
                    .frame(width: 72, height: 72)
                    .background(
                        .white.opacity(0.08),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LGradients.header,
                                lineWidth: 1.2
                            )
                    }

                Text("Progress Report")
                    .font(
                        .system(
                            size: 24,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(challenge.title)
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Difficulty

    private var difficultyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                sectionHeader(
                    title: "Difficulty",
                    subtitle: "How difficult does this challenge feel?"
                )

                HStack(spacing: 10) {

                    ForEach(1...5, id: \.self) { value in

                        Button {
                            difficultyRating = value
                        } label: {

                            Text("\(value)")
                                .font(
                                    .system(
                                        size: 15,
                                        weight: .black,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(.white)
                                .frame(
                                    maxWidth: .infinity
                                )
                                .padding(.vertical, 12)
                                .background(
                                    difficultyRating == value
                                    ? AnyShapeStyle(LGradients.header)
                                    : AnyShapeStyle(.white.opacity(0.05)),
                                    in: RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Questions

    private func questionCard(
        title: String,
        answer: Binding<String>
    ) -> some View {

        GlassCard {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                TextField(
                    "Your response...",
                    text: answer,
                    axis: .vertical
                )
                .lineLimit(4...10)
                .font(
                    .system(
                        size: 14,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            submitReport()
        } label: {

            Text("Submit Progress Report")
                .font(
                    .system(
                        size: 15,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    canSubmit
                    ? AnyShapeStyle(LGradients.header)
                    : AnyShapeStyle(.white.opacity(0.12)),
                    in: Capsule()
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    // MARK: - Save

    private func submitReport() {

        let report = LureliaChallengeProgressReport(
            challenge: challenge,
            difficultyRating: difficultyRating
        )

        modelContext.insert(report)

        let answers = [
            answer1,
            answer2,
            answer3,
            answer4,
            answer5,
            answer6
        ]

        for (index, question) in questions.enumerated() {

            let response = LureliaChallengeReportResponse(
                question: question,
                answer: answers[index],
                sortOrder: index
            )

            response.report = report

            modelContext.insert(response)
        }

        let timelineEntry = LureliaChallengeEntry(
            challenge: challenge,
            sourceType: .progressReportSubmitted,
            sourceID: report.id,
            title: "Progress Report Submitted",
            note: "Difficulty \(difficultyRating)/5"
        )

        modelContext.insert(timelineEntry)

        challenge.updatedAt = Date()

        try? modelContext.save()

        dismiss()
    }

    // MARK: - Analyze

    private var analyzeButton: some View {
        Button {
            analyzeReport()
        } label: {

            HStack(spacing: 8) {

                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Analyze Progress Report")
                        .font(
                            .system(
                                size: 15,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)

                    Text("\u{2728}")
                        .font(.system(size: 14))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                canSubmit && !isAnalyzing
                ? AnyShapeStyle(LGradients.header)
                : AnyShapeStyle(.white.opacity(0.12)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || isAnalyzing)
    }

    private func analysisResultView(
        _ result: LureliaChallengeAnalysisService.AnalysisResponse
    ) -> some View {

        VStack(spacing: 12) {

            analysisSectionCard(
                icon: "linedpages",
                title: "Reflection",
                body: result.reflection
            )

            analysisSectionCard(
                icon: "starwavy",
                title: "What You\u{2019}re Doing Well",
                body: result.strengths
            )

            analysisSectionCard(
                icon: "checkwavy",
                title: "Suggested Next Step",
                body: result.nextStep
            )

            analysisSectionCard(
                icon: "heartwavy",
                title: "Encouragement",
                body: result.encouragement
            )
        }
    }

    private func analysisSectionCard(
        icon: String,
        title: String,
        body: String
    ) -> some View {

        GlassCard {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                HStack(spacing: 8) {

                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LGradients.header)
                        .frame(width: 16, height: 16)

                    Text(title)
                        .font(
                            .system(
                                size: 15,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                }

                Text(body)
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func analysisErrorView(
        _ message: String
    ) -> some View {

        GlassCard {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                Text("Analysis Unavailable")
                    .font(
                        .system(
                            size: 15,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(LColors.danger)

                Text(message)
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func analyzeReport() {

        guard canSubmit, !isAnalyzing else { return }

        isAnalyzing = true
        analysisResult = nil
        analysisError = nil

        let answers: [(question: String, answer: String)] = [
            (questions[0], answer1),
            (questions[1], answer2),
            (questions[2], answer3),
            (questions[3], answer4),
            (questions[4], answer5),
            (questions[5], answer6)
        ]

        Task {
            do {
                let result = try await LureliaChallengeAnalysisService.analyze(
                    challengeName: challenge.title,
                    identityStatement: challenge.identityStatement,
                    progress: challenge.progressText,
                    daysRemaining: challenge.daysRemaining,
                    systemSteps: challenge.sortedSystemSteps.map { step in
                        "\(step.title): \(step.notes)"
                    },
                    answers: answers
                )

                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    analysisError = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {

            Text(title)
                .font(
                    .system(
                        size: 18,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Text(subtitle)
                .font(
                    .system(
                        size: 11,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.5)
                )
        }
    }
}
