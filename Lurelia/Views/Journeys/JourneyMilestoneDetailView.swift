//
//  JourneyMilestoneDetailView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct JourneyMilestoneDetailView: View {

    @Bindable var milestone: LureliaJourneyMilestone
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showEditMilestone = false
    @State private var showNewStep = false
    @State private var showCompletionBanner = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showConfetti = false

    var body: some View {
        ZStack(alignment: .top) {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                milestoneHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        overviewCard
                        progressCard
                        stepsCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }

            // Confetti layer
            if showConfetti {
                ConfettiView(particles: confettiParticles)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Completion banner
            if showCompletionBanner {
                VStack {
                    Spacer()
                    completionBannerView
                    Spacer()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: $showEditMilestone) {
            if let journey = milestone.journey {
                LureliaNewMilestoneSheet(journey: journey, milestone: milestone)
            }
        }
        .fullScreenCover(isPresented: $showNewStep) {
            LureliaNewJourneyStepSheet(milestone: milestone)
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var milestoneHeader: some View {
        HStack {
            Text(milestone.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Button { dismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            Button { showEditMilestone = true } label: {
                Image("pencil")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // MARK: - Completion Banner

    private var completionBannerView: some View {
        VStack(spacing: 16) {
            Image("trophystar")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 52, height: 52)

            Text("Milestone Complete!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(milestone.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            if let reward = milestone.reward, !reward.isEmpty {
                HStack(spacing: 6) {
                    Image("trophystar")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LGradients.header)
                        .frame(width: 16, height: 16)

                    Text(reward)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LGradients.header)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(LGradients.header.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(LGradients.header, lineWidth: 1))
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 40)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LColors.bgSoft.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientPurple.opacity(0.28),
                                    LColors.gradientBlue.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(LGradients.header, lineWidth: 1.5)
                }
        }
        .padding(.horizontal, 32)
        .shadow(color: LColors.gradientPurple.opacity(0.4), radius: 30, y: 10)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

// MARK: - Overview

extension JourneyMilestoneDetailView {

    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(milestone.status.displayName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LGradients.header)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(LGradients.header.opacity(0.14), in: Capsule())
                            .overlay(Capsule().strokeBorder(LGradients.header, lineWidth: 1))
                    }

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 14, height: 14)
                }

                if !milestone.details.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DETAILS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Text(milestone.details)
                            .foregroundStyle(.white)
                    }
                }

                if let targetDate = milestone.targetDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TARGET DATE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Text(targetDate.formatted(date: .long, time: .omitted))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                if let reward = milestone.reward, !reward.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("REWARD")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 8) {
                            Image("trophystar")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(LGradients.header)
                                .frame(width: 20, height: 20)

                            Text(reward)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LGradients.header.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(LGradients.header.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch milestone.status {
        case .notStarted: return .white.opacity(0.25)
        case .inProgress: return LColors.gradientBlue
        case .completed: return .green
        }
    }
}

// MARK: - Progress

extension JourneyMilestoneDetailView {

    private var progressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("PROGRESS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.12))
                            .frame(height: 10)

                        Capsule()
                            .fill(LGradients.header)
                            .frame(width: geo.size.width * progress, height: 10)
                    }
                }
                .frame(height: 10)

                Text("\(Int(progress * 100))% Complete")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(completedSteps)")
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Steps")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(totalSteps)")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Steps

extension JourneyMilestoneDetailView {

    private var stepsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Text("ACTION STEPS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Button { showNewStep = true } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 22, height: 22)
                    }
                }

                if sortedSteps.isEmpty {
                    Text("No action steps yet")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ForEach(sortedSteps) { step in
                        NavigationLink {
                            JourneyStepDetailView(step: step)
                        } label: {
                            HStack(spacing: 12) {
                                Button {
                                    let wasCompleted = step.isCompleted
                                    step.toggleCompletion()

                                    // Fire celebration if milestone just completed
                                    if !wasCompleted && milestone.status == .completed {
                                        triggerCompletionCelebration()
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(step.isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
                                            .frame(width: 24, height: 24)

                                        Circle()
                                            .strokeBorder(
                                                step.isCompleted ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LGradients.header),
                                                lineWidth: 1.6
                                            )
                                            .frame(width: 24, height: 24)

                                        if step.isCompleted {
                                            Image("checkwavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(LColors.bg)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(step.title)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .strikethrough(step.isCompleted, color: .white.opacity(0.85))

                                    if !step.details.isEmpty {
                                        Text(step.details)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .lineLimit(1)
                                    }

                                    // Status + target date inline
                                    HStack(spacing: 6) {
                                        Text(step.status.displayName.uppercased())
                                            .font(.system(size: 9, weight: .black, design: .rounded))
                                            .foregroundStyle(LGradients.header)

                                        if let td = step.targetDate {
                                            Text("· \(td.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                    }
                                }

                                Spacer()

                                Image("chevright")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(LGradients.header)
                                    .frame(width: 16, height: 16)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteStep(step)
                            } label: {
                                Label("Delete Step", image: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

extension JourneyMilestoneDetailView {

    private var sortedSteps: [LureliaJourneyStep] {
        (milestone.steps ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var totalSteps: Int { sortedSteps.count }

    private var completedSteps: Int {
        sortedSteps.filter { $0.status == .completed }.count
    }

    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }

    private func deleteStep(_ step: LureliaJourneyStep) {
        modelContext.delete(step)
        milestone.updatedAt = Date()
    }

    private func triggerCompletionCelebration() {
        confettiParticles = ConfettiParticle.generate()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            showConfetti = true
            showCompletionBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                showCompletionBanner = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            showConfetti = false
            confettiParticles = []
        }
    }
}

// MARK: - Confetti

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var color: Color
    var size: CGFloat
    var rotation: Double
    var speed: Double
    var delay: Double

    static func generate() -> [ConfettiParticle] {
        let colors: [Color] = [
            LColors.gradientPurple,
            LColors.gradientBlue,
            LColors.gradientPink,
            LColors.gradientCyan,
            LColors.gradientYellow,
            .white
        ]

        return (0..<80).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...1),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 5...12),
                rotation: Double.random(in: 0...360),
                speed: Double.random(in: 1.8...3.5),
                delay: Double.random(in: 0...0.6)
            )
        }
    }
}

struct ConfettiView: View {
    let particles: [ConfettiParticle]

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                ConfettiPieceView(particle: particle, screenHeight: geo.size.height)
                    .position(x: particle.x * geo.size.width, y: -20)
            }
        }
    }
}

struct ConfettiPieceView: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat

    @State private var offsetY: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.5)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    .easeIn(duration: particle.speed)
                    .delay(particle.delay)
                ) {
                    offsetY = screenHeight + 40
                    rotation = particle.rotation + Double.random(in: 180...720)
                }
                withAnimation(
                    .easeIn(duration: 0.4)
                    .delay(particle.delay + particle.speed - 0.4)
                ) {
                    opacity = 0
                }
            }
    }
}
