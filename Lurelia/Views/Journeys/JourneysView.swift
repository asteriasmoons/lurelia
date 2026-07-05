//
//  JourneysView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct JourneysView: View {

    @Query(
        sort: \LureliaJourney.createdAt,
        order: .reverse
    )
    private var journeys: [LureliaJourney]

    @State private var showNewJourney = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    journeysHeader

                    if journeys.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {

                                ForEach(journeys) { journey in

                                    NavigationLink {
                                        JourneyDetailView(journey: journey)
                                    } label: {

                                        GlassCard {
                                            VStack(alignment: .leading, spacing: 16) {
                                                header(for: journey)

                                                progressSection(for: journey)

                                                HStack(alignment: .top, spacing: 10) {
                                                    infoTile(
                                                        label: "CURRENT MILESTONE",
                                                        value: currentMilestone(for: journey)?.title ?? "No milestone yet"
                                                    )

                                                    infoTile(
                                                        label: "NEXT STEP",
                                                        value: nextStep(for: journey)?.title ?? "No next step"
                                                    )
                                                }

                                                journeyActionRow
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showNewJourney) {
                LureliaNewJourneySheet()
            }
        }
    }
    
    private var journeysHeader: some View {
        HStack {
            Text("Journeys")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                showNewJourney = true
            } label: {
                Image("addwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

// MARK: - Sections

extension JourneysView {

    @ViewBuilder
    private func header(for journey: LureliaJourney) -> some View {
        VStack(alignment: .center, spacing: 10) {

            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))

                Circle()
                    .strokeBorder(LGradients.header, lineWidth: 1.5)

                Image(journey.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .padding(11)
            }
            .frame(width: 56, height: 56)

            Text(journey.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            if !journey.vision.isEmpty {
                Text(journey.vision)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func progressSection(for journey: LureliaJourney) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("PROGRESS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            let totalDots = 12
            let filledDots = Int(round(journeyProgress(journey) * Double(totalDots)))

            HStack(spacing: 6) {
                ForEach(0..<totalDots, id: \.self) { index in
                    Circle()
                        .fill(index < filledDots ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(.white.opacity(0.12)))
                        .frame(width: 10, height: 10)
                }
            }

            Text("\(Int(journeyProgress(journey) * 100))% Complete")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func infoTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var journeyActionRow: some View {
        HStack(spacing: 8) {
            Text("Continue Journey")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)

            Spacer()

            Image("chevright")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 15, height: 15)
        }
        .padding(.top, 2)
    }
}

// MARK: - Helpers

extension JourneysView {

    private func journeyProgress(_ journey: LureliaJourney) -> Double {

        let milestones = journey.milestones ?? []

        guard !milestones.isEmpty else { return 0 }

        let completed = milestones.filter {
            $0.status == .completed
        }.count

        return Double(completed) / Double(milestones.count)
    }

    private func currentMilestone(
        for journey: LureliaJourney
    ) -> LureliaJourneyMilestone? {

        (journey.milestones ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .first {
                $0.status != .completed
            }
    }

    private func nextStep(
        for journey: LureliaJourney
    ) -> LureliaJourneyStep? {

        currentMilestone(for: journey)?
            .steps?
            .sorted { $0.sortOrder < $1.sortOrder }
            .first {
                $0.status != .completed
            }
    }
}

// MARK: - Empty State

extension JourneysView {

    private var emptyState: some View {

        VStack(spacing: 16) {

            Image("journey")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 100, height: 100)

            Text("No Journeys Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Create a journey and start building your path forward.")
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                showNewJourney = true
            } label: {
                Text("Create Journey")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LGradients.header)
            }
        }
        .padding()
    }
}
