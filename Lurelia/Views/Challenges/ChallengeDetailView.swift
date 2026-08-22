//
//  ChallengeDetailView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct ChallengeDetailView: View {

    @Bindable var challenge: LureliaChallenge

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEditChallenge = false
    @State private var showProgressReport = false
    @State private var showHistory = false
    @State private var showDeleteConfirmation = false

    @Query(sort: \LureliaReminder.scheduledDate)
    private var reminders: [LureliaReminder]

    @Query(sort: \LureliaHabit.createdAt)
    private var habits: [LureliaHabit]

    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        overviewCard
                        systemStepsCard
                        actionsCard
                        progressReportsCard
                        ChallengeStatsCardView(challenge: challenge)
                        linkedActivityCard
                        activityTimelineCard
                        bottomActionsCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showEditChallenge) {
            AddEditChallengeView(challenge: challenge)
        }
        .sheet(isPresented: $showProgressReport) {
            ChallengeProgressReportSheet(challenge: challenge)
        }
        .sheet(isPresented: $showHistory) {
            ChallengeHistoryView(challenge: challenge)
        }
        .confirmationDialog(
            "Delete Challenge?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Challenge", role: .destructive) {
                deleteChallenge()
            }

            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showEditChallenge = true } label: {
                Image("pencil")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button { showDeleteConfirmation = true } label: {
                Image("trash")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var overviewCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(challenge.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 42, height: 42)
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(LGradients.header, lineWidth: 1.3)
                    }

                VStack(spacing: 7) {
                    Text(challenge.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if !challenge.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(challenge.details)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                challengeProgressRing(
                    progress: LureliaChallengeHelpers.completionPercentage(actions: challenge.sortedActions),
                    size: 102,
                    lineWidth: 9,
                    percentText: LureliaChallengeHelpers.completionPercentText(
                        progress: LureliaChallengeHelpers.completionPercentage(actions: challenge.sortedActions)
                    )
                )

                statusPill
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statusPill: some View {
        Text(challenge.status.displayName.uppercased())
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LGradients.header.opacity(0.22), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(LGradients.header, lineWidth: 1)
            }
    }
    
    private var systemStepsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "System Steps",
                    subtitle: "\(challenge.sortedSystemSteps.count) step\(challenge.sortedSystemSteps.count == 1 ? "" : "s")"
                )

                if challenge.sortedSystemSteps.isEmpty {
                    emptySmallText("No system steps have been added yet.")
                } else {
                    VStack(spacing: 9) {
                        ForEach(
                            Array(challenge.sortedSystemSteps.enumerated()),
                            id: \.element.id
                        ) { index, step in
                            systemStepRow(
                                step,
                                number: index + 1
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func systemStepRow(
        _ step: LureliaChallengeSystemStep,
        number: Int
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LGradients.header)

                Text("\(number)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                let cleanedNotes = step.notes.trimmingCharacters(in: .whitespacesAndNewlines)

                if !cleanedNotes.isEmpty {
                    Text(cleanedNotes)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(LGradients.header.opacity(0.28), lineWidth: 1)
        }
    }

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Votes",
                    subtitle: "\(completedActionsCount)/\(totalActionsCount) complete"
                )

                if challenge.sortedActions.isEmpty {
                    emptySmallText("No votes have been added yet.")
                } else {
                    VStack(spacing: 9) {
                        ForEach(challenge.sortedActions) { action in
                            challengeActionRow(action)
                        }
                    }
                }
            }
        }
    }

    private func challengeActionRow(_ action: LureliaChallengeAction) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleManualAction(action)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(LGradients.header, lineWidth: 1.5)
                        .frame(width: 25, height: 25)

                    if action.isCompleted {
                        Image("checkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 15, height: 15)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(actionSubtitle(action))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer()

            Text(action.isCompleted ? "Done" : "Open")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(LGradients.header.opacity(0.28), lineWidth: 1)
        }
    }
    
    private var linkedActivityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Linked Activity",
                    subtitle: "\(linkedActions.count) linked item\(linkedActions.count == 1 ? "" : "s")"
                )

                if linkedActions.isEmpty {
                    emptySmallText("No reminders, habits, or routines are linked yet.")
                } else {
                    VStack(spacing: 9) {
                        ForEach(linkedActions) { action in
                            linkedActivityRow(for: action)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func linkedActivityRow(for action: LureliaChallengeAction) -> some View {
        switch action.linkedItemType {
        case .reminder:
            if let reminder = linkedReminder(for: action) {
                linkedActivityRowContent(
                    icon: reminder.icon.isEmpty ? "bellfill" : reminder.icon,
                    title: reminder.title,
                    subtitle: "Reminder",
                    actionTitle: action.title
                )
            }

        case .habit:
            if let habit = linkedHabit(for: action) {
                linkedActivityRowContent(
                    icon: (habit.iconName ?? "repeatfill").isEmpty ? "repeatfill" : (habit.iconName ?? "repeatfill"),
                    title: habit.title,
                    subtitle: "Habit • \(habit.todaysCount)/\(habit.target) today",
                    actionTitle: action.title
                )
            }

        case .routine:
            if let routine = linkedRoutine(for: action) {
                linkedRoutineActivityRowContent(
                    routine: routine,
                    actionTitle: action.title
                )
            }

        case .manual:
            EmptyView()
        }
    }
    
    private func linkedActivityRowContent(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.07), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(LGradients.header.opacity(0.6), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)

                Text("Action: \(actionTitle)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(LGradients.header.opacity(0.28), lineWidth: 1)
        }
    }

    private var linkedActions: [LureliaChallengeAction] {
        challenge.sortedActions.filter {
            $0.linkedItemType != .manual && $0.linkedItemID != nil
        }
    }
    
    private func linkedRoutineActivityRowContent(
        routine: LureliaRoutine,
        actionTitle: String
    ) -> some View {
        let routineColor = colorFromHex(routine.colorHex)

        return HStack(spacing: 10) {
            Image(routine.icon.isEmpty ? "clockwavy" : routine.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(routineColor)
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(routineColor.opacity(0.14), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(routineColor.opacity(0.85), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("Routine • \(routine.formattedTimeRange)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)

                Text("Action: \(actionTitle)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(routineColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(routineColor.opacity(0.55), lineWidth: 1)
        }
    }

    private var progressReportsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader(
                        title: "Progress Reports",
                        subtitle: progressReportSubtitle
                    )

                    Spacer()

                    Button {
                        showProgressReport = true
                    } label: {
                        Text("Submit")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.adaptivePrimaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(LGradients.header, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if sortedReports.isEmpty {
                    emptySmallText("No progress reports submitted yet.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(sortedReports.prefix(3)) { report in
                            progressReportRow(report)
                        }
                    }
                }
            }
        }
    }

    private func progressReportRow(_ report: LureliaChallengeProgressReport) -> some View {
        HStack(spacing: 10) {
            Image("linedpages")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 18, height: 18)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.07), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(report.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Difficulty: \(report.difficultyRating)/5")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activityTimelineCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader(
                        title: "Activity Timeline",
                        subtitle: "\(sortedEntries.count) entries"
                    )

                    Spacer()

                    Button {
                        showHistory = true
                    } label: {
                        Image("timebook")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }

                if sortedEntries.isEmpty {
                    emptySmallText("Challenge activity will appear here.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(sortedEntries.prefix(4)) { entry in
                            timelineEntryRow(entry)
                        }
                    }
                }
            }
        }
    }

    private func timelineEntryRow(_ entry: LureliaChallengeEntry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(LGradients.header)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var bottomActionsCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                Button {
                    showProgressReport = true
                } label: {
                    actionButtonLabel("Submit Progress Report", icon: "linedpages")
                }
                .buttonStyle(.plain)

                Button {
                    showEditChallenge = true
                } label: {
                    actionButtonLabel("Edit Challenge", icon: "pencil")
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    actionButtonLabel("Delete Challenge", icon: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionButtonLabel(_ title: String, icon: String) -> some View {
        HStack {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Image("chevright")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 13, height: 13)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func emptySmallText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
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
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 8:
            red = Double((value & 0xFF000000) >> 24) / 255
            green = Double((value & 0x00FF0000) >> 16) / 255
            blue = Double((value & 0x0000FF00) >> 8) / 255
            alpha = Double(value & 0x000000FF) / 255

        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1

        default:
            red = 0.49
            green = 0.10
            blue = 0.97
            alpha = 1
        }

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    private func linkedReminder(for action: LureliaChallengeAction) -> LureliaReminder? {
        guard let id = action.linkedItemID else { return nil }
        return reminders.first { $0.id == id }
    }

    private func linkedHabit(for action: LureliaChallengeAction) -> LureliaHabit? {
        guard let id = action.linkedItemID else { return nil }
        return habits.first { $0.id == id }
    }

    private func linkedRoutine(for action: LureliaChallengeAction) -> LureliaRoutine? {
        guard let id = action.linkedItemID else { return nil }
        return routines.first { routine in
            UUID(uuidString: routine.persistentID) == id
        }
    }

    private var sortedReports: [LureliaChallengeProgressReport] {
        (challenge.progressReports ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedEntries: [LureliaChallengeEntry] {
        (challenge.entries ?? []).sorted { $0.date > $1.date }
    }

    private var totalActionsCount: Int {
        challenge.sortedActions.count
    }

    private var completedActionsCount: Int {
        challenge.sortedActions.filter(\.isCompleted).count
    }

    private var progressReportSubtitle: String {
        if challenge.isCheckInDue {
            return "Progress report required"
        }

        return "Latest reflections"
    }

    private func actionSubtitle(_ action: LureliaChallengeAction) -> String {
        switch action.linkedItemType {
        case .reminder:
            return "Linked Reminder"
        case .habit:
            return "Linked Habit"
        case .routine:
            return "Linked Routine"
        case .manual:
            return "Manual Action"
        }
    }

    private func toggleManualAction(_ action: LureliaChallengeAction) {
        if action.isCompleted {
            action.markIncomplete()
        } else {
            action.markCompleted()

            let entry = LureliaChallengeEntry(
                challenge: challenge,
                action: action,
                sourceType: .manualActionCompleted,
                sourceID: action.id,
                title: "\(action.title) Completed",
                note: ""
            )

            modelContext.insert(entry)
        }

        challenge.currentValue = min(
            challenge.targetValue,
            challenge.sortedActions.filter(\.isCompleted).count
        )

        updateChallengeCompletionState()
        challenge.updatedAt = Date()
        try? modelContext.save()
        NotificationCenter.default.post(name: .lureliaChallengeProgressDidChange, object: nil)
    }

    private func updateChallengeCompletionState() {
        guard !challenge.sortedActions.isEmpty else { return }

        let completedCount = challenge.sortedActions.filter(\.isCompleted).count
        let totalCount = challenge.sortedActions.count

        challenge.currentValue = completedCount

        let allComplete = totalCount > 0 && completedCount >= totalCount

        if allComplete {
            challenge.status = .completed
            challenge.completedAt = challenge.completedAt ?? Date()

            let alreadyHasCompletionEntry = sortedEntries.contains {
                $0.sourceType == .challengeCompleted
            }

            if !alreadyHasCompletionEntry {
                let entry = LureliaChallengeEntry(
                    challenge: challenge,
                    sourceType: .challengeCompleted,
                    sourceID: challenge.id,
                    title: "Challenge Completed",
                    note: challenge.title
                )

                modelContext.insert(entry)
            }
        } else if challenge.status == .completed {
            challenge.status = .active
            challenge.completedAt = nil
        }
    }

    private func deleteChallenge() {
        modelContext.delete(challenge)
        try? modelContext.save()
        dismiss()
    }
}
