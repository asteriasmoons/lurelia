//
//  ChallengeStatsCardView.swift
//  Lurelia
//

import SwiftUI

struct ChallengeStatsCardView: View {

    let challenge: LureliaChallenge

    private var completedActions: Int {
        LureliaChallengeHelpers.completedActionsCount(challenge)
    }

    private var remainingActions: Int {
        LureliaChallengeHelpers.remainingActionsCount(challenge)
    }

    private var totalActions: Int {
        challenge.sortedActions.count
    }

    private var reportCount: Int {
        challenge.progressReports?.count ?? 0
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                header

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    statBox(
                        title: "Progress",
                        value: LureliaChallengeHelpers.completionPercentText(
                            progress: LureliaChallengeHelpers.completionPercentage(
                                actions: challenge.sortedActions
                            )
                        ),
                        icon: "starchart"
                    )

                    statBox(
                        title: "Actions",
                        value: "\(completedActions)/\(totalActions)",
                        icon: "checkwavy"
                    )

                    statBox(
                        title: "Remaining",
                        value: "\(remainingActions)",
                        icon: "hourglassfill"
                    )

                    statBox(
                        title: "Reports",
                        value: "\(reportCount)",
                        icon: "linedpages"
                    )

                    statBox(
                        title: "Started",
                        value: challenge.startDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "starcal"
                    )

                    statBox(
                        title: "Ends",
                        value: challenge.endDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "stopwavy"
                    )

                    statBox(
                        title: "Duration",
                        value: "\(challenge.durationDays) Days",
                        icon: "clockfill"
                    )

                    statBox(
                        title: "Status",
                        value: challenge.status.displayName,
                        icon: statusIcon
                    )
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Stats")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Progress, dates, reports, and remaining actions")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func statBox(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 17, height: 17)

                Spacer()
            }

            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 12)
        .background(
            .white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var statusIcon: String {
        switch challenge.status {
        case .active:
            return "sparkbolt"
        case .completed:
            return "startrophyfill"
        case .expired:
            return "hourglassfill"
        }
    }
}
