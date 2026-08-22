//
//  ChallengesView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct ChallengesView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LureliaChallenge.createdAt, order: .reverse)
    private var challenges: [LureliaChallenge]

    @State private var showAddChallenge = false
    @State private var dashboardRefreshToken = UUID()

    private var activeChallenges: [LureliaChallenge] {
        challenges
            .filter { $0.status == .active }
            .sorted { $0.endDate < $1.endDate }
    }

    private var completedChallenges: [LureliaChallenge] {
        challenges
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    private var expiredChallenges: [LureliaChallenge] {
        challenges
            .filter { $0.status == .expired }
            .sorted { $0.endDate > $1.endDate }
    }

    private var needsCheckInChallenges: [LureliaChallenge] {
        activeChallenges.filter { $0.isCheckInDue }
    }

    private var almostCompleteChallenges: [LureliaChallenge] {
        activeChallenges
            .filter { $0.completionPercentage >= 0.75 && $0.completionPercentage < 1.0 }
            .sorted { $0.completionPercentage > $1.completionPercentage }
    }

    private var endingSoonChallenges: [LureliaChallenge] {
        activeChallenges
            .filter { $0.daysRemaining <= 3 }
            .sorted { $0.daysRemaining < $1.daysRemaining }
    }

    private var totalActiveProgress: Double {
        let dashboardChallenges = challenges.filter {
            $0.status == .active || $0.status == .completed
        }

        guard !dashboardChallenges.isEmpty else { return 0 }

        let total = dashboardChallenges.reduce(0.0) { partial, challenge in
            partial + LureliaChallengeHelpers.completionPercentage(
                actions: challenge.sortedActions
            )
        }

        return min(max(total / Double(dashboardChallenges.count), 0), 1)
    }
    
    private var dashboardRefreshID: String {
        challenges
            .map { challenge in
                let actionState = challenge.sortedActions
                    .map { action in
                        "\(action.id.uuidString):\(action.isCompleted):\(action.updatedAt.timeIntervalSince1970)"
                    }
                    .joined(separator: ",")

                return [
                    challenge.id.uuidString,
                    challenge.statusRaw,
                    "\(LureliaChallengeHelpers.completionPercentage(actions: challenge.sortedActions))",
                    actionState,
                    challenge.updatedAt.timeIntervalSince1970.description
                ]
                .joined(separator: "|")
            }
            .joined(separator: "::")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            dashboardCard
                                .id("\(dashboardRefreshID)-\(dashboardRefreshToken)")

                            if challenges.isEmpty {
                                emptyStateCard
                            } else {
                                if !needsCheckInChallenges.isEmpty {
                                    challengeSection(
                                        title: "Needs Check-In",
                                        subtitle: "Progress reports waiting for you",
                                        challenges: needsCheckInChallenges
                                    )
                                }

                                if !activeChallenges.isEmpty {
                                    challengeSection(
                                        title: "Active Challenges",
                                        subtitle: "Currently running",
                                        challenges: activeChallenges
                                    )
                                }

                                if !almostCompleteChallenges.isEmpty {
                                    challengeSection(
                                        title: "Almost Complete",
                                        subtitle: "Close to the finish line",
                                        challenges: almostCompleteChallenges
                                    )
                                }

                                if !endingSoonChallenges.isEmpty {
                                    challengeSection(
                                        title: "Ending Soon",
                                        subtitle: "Challenges approaching their end date",
                                        challenges: endingSoonChallenges
                                    )
                                }

                                if !completedChallenges.isEmpty {
                                    challengeSection(
                                        title: "Completed Challenges",
                                        subtitle: "Past victories",
                                        challenges: completedChallenges
                                    )
                                }

                                if !expiredChallenges.isEmpty {
                                    challengeSection(
                                        title: "Expired Challenges",
                                        subtitle: "Ended before completion",
                                        challenges: expiredChallenges
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddChallenge) {
                AddEditChallengeView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lureliaChallengeProgressDidChange)) { _ in
                dashboardRefreshToken = UUID()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Challenges")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Personal missions with momentum")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button {
                showAddChallenge = true
            } label: {
                Image("addwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var dashboardCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 16) {
                    challengeProgressRing(
                        progress: totalActiveProgress,
                        size: 82,
                        lineWidth: 7,
                        percentText: "\(Int((min(max(totalActiveProgress, 0), 1) * 100).rounded()))%"
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("CHALLENGE DASHBOARD")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))

                        Text(challenges.isEmpty ? "No challenges yet" : "Current Challenge Progress")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(dashboardSummaryText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(2)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    dashboardStat(
                        title: "Active",
                        value: "\(activeChallenges.count)"
                    )

                    dashboardStat(
                        title: "Done",
                        value: "\(completedChallenges.count)"
                    )

                    dashboardStat(
                        title: "Check-In",
                        value: "\(needsCheckInChallenges.count)"
                    )
                }
            }
        }
        .id("\(dashboardRefreshID)-\(dashboardRefreshToken)")
    }

    private var dashboardSummaryText: String {
        if challenges.isEmpty {
            return "Create a challenge to focus your effort around a defined goal."
        }

        if needsCheckInChallenges.count == 1 {
            return "1 challenge needs a progress report."
        }

        if needsCheckInChallenges.count > 1 {
            return "\(needsCheckInChallenges.count) challenges need progress reports."
        }

        return "Keep going — your active challenges are moving forward."
    }

    private func dashboardStat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var emptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image("startrophyfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LGradients.header)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("No challenges yet")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Create your first personal mission.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()
                }

                Button {
                    showAddChallenge = true
                } label: {
                    Text("Create Challenge")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.adaptivePrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LGradients.header, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func challengeSection(
        title: String,
        subtitle: String,
        challenges: [LureliaChallenge]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(challenges) { challenge in
                    NavigationLink {
                        ChallengeDetailView(challenge: challenge)
                    } label: {
                        ChallengeCardView(challenge: challenge)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func challengeProgressRing(
        progress: Double,
        size: CGFloat,
        lineWidth: CGFloat,
        percentText: String
    ) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [2, 5]))

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(LGradients.header, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [2, 5]))
                .rotationEffect(.degrees(-90))

            Text(percentText)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

extension Notification.Name {
    static let lureliaChallengeProgressDidChange = Notification.Name("lureliaChallengeProgressDidChange")
}
