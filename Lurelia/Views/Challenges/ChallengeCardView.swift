//
//  ChallengeCardView.swift
//  Lurelia
//

import SwiftUI

struct ChallengeCardView: View {

    let challenge: LureliaChallenge

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {

                headerSection

                statsSection

                nextActionSection

                checkInSection
            }
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(
                    .white.opacity(0.08),
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round,
                        dash: [2, 5]
                    )
                )

            Circle()
                .trim(
                    from: 0,
                    to: LureliaChallengeHelpers.completionPercentage(actions: challenge.sortedActions)
                )
                .stroke(
                    LGradients.header,
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round,
                        dash: [2, 5]
                    )
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(
                    LureliaChallengeHelpers.completionPercentText(
                        progress: LureliaChallengeHelpers.completionPercentage(actions: challenge.sortedActions)
                    ).replacingOccurrences(of: "%", with: "")
                )
                .font(
                    .system(
                        size: 12,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

                Text("%")
                    .font(
                        .system(
                            size: 6,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 60, height: 60)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {

            iconView

            VStack(alignment: .leading, spacing: 4) {

                Text(challenge.title)
                    .font(
                        .system(
                            size: 17,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !challenge.identityStatement
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {

                    Text(challenge.identityStatement)
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(challenge.status.displayName)
                    .font(
                        .system(
                            size: 10,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            progressRing
        }
    }

    private var iconView: some View {
        Group {
            if UIImage(named: challenge.iconName) != nil {
                Image(challenge.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "flag.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundStyle(LGradients.header)
        .frame(width: 42, height: 42)
        .frame(width: 60, height: 60)
        .background(
            Color.white.opacity(0.08),
            in: Circle()
        )
        .overlay {
            Circle()
                .strokeBorder(
                    LGradients.header,
                    lineWidth: 1
                )
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 8) {

            statPill(
                title: "Remaining",
                value: daysRemainingText
            )

            statPill(
                title: "Actions",
                value: "\(completedActions)/\(totalActions)"
            )
        }
    }

    private func statPill(
        title: String,
        value: String
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(
                    .system(
                        size: 11,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Text(title.uppercased())
                .font(
                    .system(
                        size: 8,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            Color.white.opacity(0.05),
            in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    // MARK: - Next Action

    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 4) {

            Text("NEXT ACTION")
                .font(
                    .system(
                        size: 9,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white.opacity(0.45))

            Text(nextActionTitle)
                .font(
                    .system(
                        size: 13,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    // MARK: - Check-In

    private var checkInSection: some View {
        HStack(spacing: 8) {

            Circle()
                .fill(
                    LureliaChallengeHelpers.isCheckInDue(for: challenge)
                    ? AnyShapeStyle(LGradients.header)
                    : AnyShapeStyle(Color.white.opacity(0.3))
                )
                .frame(width: 8, height: 8)

            Text(
                LureliaChallengeHelpers.isCheckInDue(for: challenge)
                ? "Check-In Due"
                : "Check-In Complete"
            )
            .font(
                .system(
                    size: 11,
                    weight: .black,
                    design: .rounded
                )
            )
            .foregroundStyle(
                LureliaChallengeHelpers.isCheckInDue(for: challenge)
                ? AnyShapeStyle(.white)
                : AnyShapeStyle(.white.opacity(0.55))
            )
        }
    }

    // MARK: - Helpers

    private var totalActions: Int {
        challenge.sortedActions.count
    }

    private var completedActions: Int {
        LureliaChallengeHelpers.completedActionsCount(challenge)
    }

    private var nextActionTitle: String {
        LureliaChallengeHelpers.nextAction(for: challenge)?.title ?? "All Actions Complete"
    }

    private var daysRemainingText: String {
        LureliaChallengeHelpers.daysRemainingText(for: challenge)
    }
}
