//
//  JourneyDetailView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct JourneyDetailView: View {

    @Bindable var journey: LureliaJourney
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LureliaJourneyCheckIn.dayStart, order: .reverse)
    private var allCheckIns: [LureliaJourneyCheckIn]

    @State private var showEditJourney = false
    @State private var showNewMilestone = false
    @State private var showTimeline = false
    @State private var showAllMilestones = false
    @State private var showNewNote = false
    @State private var showStatusMenu = false
    @State private var showQuickAddStep = false
    @State private var showCheckInHistory = false
    @State private var noteToEdit: LureliaJourneyNote? = nil
    
    private var useFullScreenCover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        ZStack(alignment: .top) {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                journeyHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        overviewCard
                        dailyCheckInCard
                        currentFocusCard
                        milestonesCard
                        actionsCard
                        notebookCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
        }
        .fullScreenCover(isPresented: $showEditJourney) {
            LureliaNewJourneySheet(journey: journey)
        }
        .fullScreenCover(isPresented: $showNewMilestone) {
            LureliaNewMilestoneSheet(journey: journey)
        }
        .fullScreenCover(isPresented: $showTimeline) {
            JourneyTimelineView(journey: journey)
        }
        .fullScreenCover(isPresented: $showNewNote) {
            LureliaJourneyNoteSheet(journey: journey)
        }
        .fullScreenCover(item: $noteToEdit) { note in
            LureliaJourneyNoteSheet(journey: journey, note: note)
        }
        .fullScreenCover(isPresented: $showQuickAddStep) {
            if let milestone = currentMilestone {
                LureliaNewJourneyStepSheet(milestone: milestone)
            }
        }
        .sheet(isPresented: Binding(
            get: { !useFullScreenCover && showCheckInHistory },
            set: { showCheckInHistory = $0 }
        )) {
            JourneyCheckInHistorySheet(journey: journey)
        }
        .fullScreenCover(isPresented: Binding(
            get: { useFullScreenCover && showCheckInHistory },
            set: { showCheckInHistory = $0 }
        )) {
            JourneyCheckInHistorySheet(journey: journey)
        }
        .confirmationDialog("Journey Status", isPresented: $showStatusMenu, titleVisibility: .visible) {
            ForEach(LureliaJourneyStatus.allCases, id: \.self) { s in
                if s != journey.status {
                    Button(s.displayName) {
                        journey.status = s
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var journeyHeader: some View {
        HStack {
            Text(journey.title)
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

            Button { showTimeline = true } label: {
                Image("clockfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            Button { showEditJourney = true } label: {
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
}

// MARK: - Overview

// MARK: - Daily Check-In

extension JourneyDetailView {

    private var dailyCheckInCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DAILY CHECK-IN")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("Are you still working on this journey?")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button { showCheckInHistory = true } label: {
                        Image("clockfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    checkInButton("Yes", response: .yes)
                    checkInButton("Not Today", response: .notToday)
                    checkInButton("No", response: .no)
                }
            }
        }
    }

    @ViewBuilder
    private func checkInButton(_ title: String, response: LureliaJourneyCheckInResponse) -> some View {
        let selected = todaysCheckIn?.response == response

        Button {
            recordCheckIn(response)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(selected ? .white : .white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    selected
                    ? AnyShapeStyle(LGradients.header)
                    : AnyShapeStyle(.white.opacity(0.08)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(.white.opacity(0.14)), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var journeyCheckIns: [LureliaJourneyCheckIn] {
        allCheckIns.filter { $0.journey?.id == journey.id }
    }

    private var todaysCheckIn: LureliaJourneyCheckIn? {
        let today = Calendar.current.startOfDay(for: Date())
        return journeyCheckIns.first { Calendar.current.isDate($0.dayStart, inSameDayAs: today) }
    }

    private func recordCheckIn(_ response: LureliaJourneyCheckInResponse) {
        if let existing = todaysCheckIn {
            existing.response = response
            existing.date = Date()
            existing.updatedAt = Date()
        } else {
            let checkIn = LureliaJourneyCheckIn(
                journey: journey,
                response: response,
                date: Date()
            )
            modelContext.insert(checkIn)
        }

        journey.updatedAt = Date()
        try? modelContext.save()
    }
}

extension JourneyDetailView {

    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(LGradients.header, lineWidth: 1.5)
                            .background(Circle().fill(LGradients.header.opacity(0.12)))

                        Image(journey.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .padding(10)
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(journey.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        // Tappable status pill
                        Button { showStatusMenu = true } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(statusIndicatorColor)
                                    .frame(width: 7, height: 7)

                                Text(journey.status.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(LGradients.header)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(LGradients.header.opacity(0.13), in: Capsule())
                            .overlay(Capsule().strokeBorder(LGradients.header, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }

                if !journey.vision.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VISION")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(journey.vision)
                            .foregroundStyle(.white)
                    }
                }

                progressSection
            }
        }
    }

    private var statusIndicatorColor: Color {
        switch journey.status {
        case .active: return .green
        case .paused: return LColors.gradientYellow
        case .abandoned: return LColors.danger
        case .completed: return LColors.gradientBlue
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROGRESS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            // Progress dots — one per milestone, filled by step completion within that milestone
            if !sortedMilestones.isEmpty {
                HStack(spacing: 6) {
                    ForEach(sortedMilestones) { milestone in
                        milestoneDot(for: milestone)
                    }
                    Spacer()
                }
            }

            Text("\(Int(journeyProgress * 100))% Complete")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func milestoneDot(for milestone: LureliaJourneyMilestone) -> some View {
        let steps = milestone.steps ?? []
        let totalSteps = steps.count
        let completedSteps = steps.filter { $0.isCompleted }.count
        let milestoneProgress: Double = totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : (milestone.status == .completed ? 1.0 : 0.0)
        let isFullyDone = milestone.status == .completed

        ZStack {
            Circle()
                .fill(isFullyDone ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.12)))
                .frame(width: 14, height: 14)

            if !isFullyDone && milestoneProgress > 0 {
                // Partial fill arc
                Circle()
                    .trim(from: 0, to: milestoneProgress)
                    .stroke(LGradients.header, lineWidth: 3)
                    .frame(width: 11, height: 11)
                    .rotationEffect(.degrees(-90))
            }

            if isFullyDone {
                Image("checkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Current Focus

extension JourneyDetailView {

    private var currentFocusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT FOCUS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Milestone")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(currentMilestone?.title ?? "No active milestone")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Divider().overlay(.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Step")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(nextStep?.title ?? "No next step")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Milestones

extension JourneyDetailView {

    private var milestonesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Text("MILESTONES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Button { showNewMilestone = true } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)

                    if sortedMilestones.count > 4 {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                showAllMilestones.toggle()
                            }
                        } label: {
                            Image("chevdown")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(LGradients.header)
                                .frame(width: 22, height: 22)
                                .rotationEffect(.degrees(showAllMilestones ? 180 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if sortedMilestones.isEmpty {
                    Text("No milestones yet")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ForEach(visibleMilestones) { milestone in
                        NavigationLink {
                            JourneyMilestoneDetailView(milestone: milestone)
                        } label: {
                            HStack(spacing: 12) {
                                // Status dot
                                Circle()
                                    .fill(
                                        milestone.status == .completed
                                        ? AnyShapeStyle(LGradients.header)
                                        : AnyShapeStyle(Color.white.opacity(0.2))
                                    )
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(milestone.title)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)

                                    HStack(spacing: 6) {
                                        let steps = milestone.steps ?? []
                                        if !steps.isEmpty {
                                            Text("\(steps.filter { $0.isCompleted }.count)/\(steps.count) steps")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }

                                        if let reward = milestone.reward, !reward.isEmpty {
                                            HStack(spacing: 3) {
                                                Image("trophystar")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundStyle(LGradients.header)
                                                    .frame(width: 10, height: 10)

                                                Text(reward)
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundStyle(LGradients.header)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }

                                Spacer()

                                Image("chevright")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(LGradients.header)
                                    .frame(width: 14, height: 14)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteMilestone(milestone)
                            } label: {
                                Label("Delete Milestone", image: "trash")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        }
    }
}

// MARK: - Actions (current milestone steps)

extension JourneyDetailView {

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Text("NEXT ACTIONS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    if currentMilestone != nil {
                        Button { showQuickAddStep = true } label: {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(LGradients.header)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if currentMilestone?.steps?.isEmpty ?? true {
                    Text("No action steps yet")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ForEach(
                        (currentMilestone?.steps ?? [])
                            .sorted { $0.sortOrder < $1.sortOrder }
                            .prefix(5),
                        id: \.id
                    ) { step in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(step.isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.18)))
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .strikethrough(step.isCompleted, color: .white.opacity(0.85))

                                Text(step.status.displayName.uppercased())
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(LGradients.header)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
    }
}

// MARK: - Notebook

extension JourneyDetailView {

    private var notebookCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                HStack {
                    HStack(spacing: 8) {
                        Image("lovejournal")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 18, height: 18)

                        Text("NOTEBOOK")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Button { showNewNote = true } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }

                if sortedNotes.isEmpty {
                    Text("No notes yet. Add your first note to this journey.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ForEach(sortedNotes) { note in
                        noteRow(note)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func noteRow(_ note: LureliaJourneyNote) -> some View {
        Button { noteToEdit = note } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(note.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }

                // Milestone / step link badges
                HStack(spacing: 6) {
                    if let milestoneID = note.linkedMilestoneID,
                       let milestone = sortedMilestones.first(where: { $0.id == milestoneID }) {
                        noteLinkBadge(milestone.title)
                    }
                    if let stepID = note.linkedStepID,
                       let step = allSteps.first(where: { $0.id == stepID }) {
                        noteLinkBadge(step.title)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteNote(note)
            } label: {
                Label("Delete Note", image: "trash")
            }
        }
    }

    @ViewBuilder
    private func noteLinkBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(LGradients.header)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(LGradients.header.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(LGradients.header.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Helpers

extension JourneyDetailView {

    private var sortedMilestones: [LureliaJourneyMilestone] {
        (journey.milestones ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleMilestones: [LureliaJourneyMilestone] {
        showAllMilestones ? sortedMilestones : Array(sortedMilestones.prefix(4))
    }

    private var currentMilestone: LureliaJourneyMilestone? {
        sortedMilestones.first { $0.status != .completed }
    }

    private var nextStep: LureliaJourneyStep? {
        currentMilestone?.steps?
            .sorted { $0.sortOrder < $1.sortOrder }
            .first { $0.status != .completed }
    }

    private var journeyProgress: Double {
        guard !sortedMilestones.isEmpty else { return 0 }
        let completed = sortedMilestones.filter { $0.status == .completed }.count
        return Double(completed) / Double(sortedMilestones.count)
    }

    private var sortedNotes: [LureliaJourneyNote] {
        (journey.notes ?? []).sorted { $0.updatedAt > $1.updatedAt }
    }

    private var allSteps: [LureliaJourneyStep] {
        sortedMilestones.flatMap { $0.steps ?? [] }
    }

    private func deleteMilestone(_ milestone: LureliaJourneyMilestone) {
        modelContext.delete(milestone)
        journey.updatedAt = Date()
    }

    private func deleteNote(_ note: LureliaJourneyNote) {
        modelContext.delete(note)
        journey.updatedAt = Date()
    }
}


// MARK: - Check-In History Sheet

struct JourneyCheckInWeek: Identifiable {
    let id: Date
    let start: Date
    let end: Date
    let entries: [LureliaJourneyCheckIn]
}

struct JourneyCheckInHistorySheet: View {

    @Bindable var journey: LureliaJourney
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LureliaJourneyCheckIn.dayStart, order: .reverse)
    private var allCheckIns: [LureliaJourneyCheckIn]

    private var journeyCheckIns: [LureliaJourneyCheckIn] {
        allCheckIns
            .filter { $0.journey?.id == journey.id }
            .sorted { $0.dayStart > $1.dayStart }
    }

    private var weeks: [JourneyCheckInWeek] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: journeyCheckIns) { checkIn in
            calendar.dateInterval(of: .weekOfYear, for: checkIn.dayStart)?.start
                ?? calendar.startOfDay(for: checkIn.dayStart)
        }

        return grouped.map { start, entries in
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return JourneyCheckInWeek(
                id: start,
                start: start,
                end: end,
                entries: entries.sorted { $0.dayStart < $1.dayStart }
            )
        }
        .sorted { $0.start > $1.start }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if weeks.isEmpty {
                                emptyState
                            } else {
                                ForEach(weeks) { week in
                                    NavigationLink {
                                        JourneyCheckInWeekDetailView(week: week)
                                    } label: {
                                        weekRow(week)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Text("Check-In History")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)

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
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No check-ins yet")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Daily answers will appear here by week.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weekRow(_ week: JourneyCheckInWeek) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(weekTitle(week))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(week.entries.count) check-in\(week.entries.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                HStack(spacing: 5) {
                    ForEach(week.entries.prefix(7)) { entry in
                        Circle()
                            .fill(responseStyle(entry.response))
                            .frame(width: 8, height: 8)
                    }
                }

                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func weekTitle(_ week: JourneyCheckInWeek) -> String {
        let start = week.start.formatted(date: .abbreviated, time: .omitted)
        let end = week.end.formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }

    private func responseStyle(_ response: LureliaJourneyCheckInResponse) -> AnyShapeStyle {
        switch response {
        case .yes:
            return AnyShapeStyle(LGradients.header)
        case .notToday:
            return AnyShapeStyle(LColors.gradientYellow)
        case .no:
            return AnyShapeStyle(LColors.danger)
        }
    }
}

struct JourneyCheckInWeekDetailView: View {

    let week: JourneyCheckInWeek
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(week.entries) { entry in
                            dayRow(entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Text("Week Details")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)

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
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private func dayRow(_ entry: LureliaJourneyCheckIn) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(responseStyle(entry.response))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.dayStart.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(entry.response.displayName.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()
            }
        }
    }

    private func responseStyle(_ response: LureliaJourneyCheckInResponse) -> AnyShapeStyle {
        switch response {
        case .yes:
            return AnyShapeStyle(LGradients.header)
        case .notToday:
            return AnyShapeStyle(LColors.gradientYellow)
        case .no:
            return AnyShapeStyle(LColors.danger)
        }
    }
}
