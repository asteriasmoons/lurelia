//
//  AddEditChallengeView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct AddEditChallengeView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var challenge: LureliaChallenge?

    @State private var title: String = ""
    @State private var identityStatement: String = ""
    @State private var details: String = ""
    @State private var iconName: String = "startrophyfill"

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()

    @State private var frequency: LureliaChallengeFrequency = .daily

    @State private var targetValue: Int = 1
    @State private var targetUnit: LureliaChallengeTargetUnit = .completions
    @State private var customTargetUnit: String = ""

    @State private var rewardName: String = ""
    @State private var rewardDescription: String = ""
    @State private var rewardAlignmentNote: String = ""

    @State private var draftActions: [ChallengeActionDraft] = []
    @State private var draftSystemSteps: [SystemStepDraft] = []

    @State private var showIconPicker = false
    @State private var showActionEditor = false
    @State private var actionToEdit: ChallengeActionDraft?

    @State private var showSystemStepEditor = false
    @State private var systemStepToEdit: SystemStepDraft?

    private var isEditing: Bool {
        challenge != nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !identityStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draftActions.count >= 2 &&
        draftSystemSteps.count >= 1 &&
        endDate >= startDate
    }

    private var durationDays: Int {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return max(1, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        identityCard
                        systemStepsCard
                        scheduleCard
                        targetCard
                        actionsCard
                        progressReportsCard
                        rewardCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }

                saveButton
            }
        }
        .onAppear {
            loadChallenge()
        }
        .sheet(isPresented: $showIconPicker) {
            LureliaIconPickerView(selectedIcon: $iconName)
        }
        .sheet(isPresented: $showActionEditor) {
            ChallengeActionEditorView(
                action: actionToEdit,
                onSave: { draft in
                    saveDraftAction(draft)
                }
            )
        }
        .sheet(isPresented: $showSystemStepEditor) {
            ChallengeSystemStepEditorView(
                step: systemStepToEdit,
                onSave: { draft in
                    saveDraftSystemStep(draft)
                }
            )
        }
    }

    // MARK: - Header

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

            Text(isEditing ? "Edit Challenge" : "New Challenge")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 26, height: 26)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Identity

    private var identityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Identity",
                    subtitle: "Who do you want to become?"
                )

                Button {
                    showIconPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 32, height: 32)
                            .frame(width: 58, height: 58)
                            .background(.white.opacity(0.08), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(LGradients.header, lineWidth: 1.2)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Challenge Icon")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text(iconName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer()

                        Image("chevright")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 14, height: 14)
                    }
                }
                .buttonStyle(.plain)

                fieldBlock(title: "Challenge Name") {
                    TextField("Becoming a Morning Person", text: $title)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                fieldBlock(title: "Identity Statement") {
                    TextField("I am someone who...", text: $identityStatement)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                fieldBlock(title: "Description") {
                    TextField("Why does this identity matter to you?", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - System Steps

    private var systemStepsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader(
                        title: "Your System",
                        subtitle: "\(draftSystemSteps.count) step\(draftSystemSteps.count == 1 ? "" : "s") \u{2022} minimum 1"
                    )

                    Spacer()

                    Button {
                        systemStepToEdit = nil
                        showSystemStepEditor = true
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }

                if draftSystemSteps.isEmpty {
                    emptyText("Describe the environment and steps that make your identity automatic. What does your system look like?")
                } else {
                    VStack(spacing: 9) {
                        ForEach(Array(draftSystemSteps.enumerated()), id: \.element.id) { index, step in
                            systemStepRow(step, index: index + 1)
                        }
                    }
                }
            }
        }
    }

    private func systemStepRow(_ step: SystemStepDraft, index: Int) -> some View {
        Button {
            systemStepToEdit = step
            showSystemStepEditor = true
        } label: {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(LGradients.header.opacity(0.35), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(LGradients.header, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !step.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(step.notes)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 13, height: 13)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteDraftSystemStep(step)
            } label: {
                Label("Delete Step", systemImage: "trash")
            }
        }
    }

    // MARK: - Schedule

    private var scheduleCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Schedule",
                    subtitle: "\(durationDays) day\(durationDays == 1 ? "" : "s")"
                )

                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

                DatePicker(
                    "End Date",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Frequency")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))

                    HStack(spacing: 8) {
                        ForEach(LureliaChallengeFrequency.allCases, id: \.self) { option in
                            frequencyButton(option)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Challenge Target

    private var targetCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Challenge Target",
                    subtitle: "Overall amount needed to complete this challenge"
                )

                LureliaGradientStepper(
                    title: "Target Amount",
                    subtitle: "Total progress needed",
                    value: $targetValue,
                    range: 1...9999,
                    step: 1
                )

                Picker("Target Unit", selection: $targetUnit) {
                    ForEach(LureliaChallengeTargetUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)

                if targetUnit == .custom {
                    fieldBlock(title: "Custom Unit") {
                        TextField("Chapters", text: $customTargetUnit)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func frequencyButton(_ option: LureliaChallengeFrequency) -> some View {
        Button {
            frequency = option
        } label: {
            Text(option.displayName)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(frequency == option ? .white : .white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    frequency == option
                    ? AnyShapeStyle(LGradients.header)
                    : AnyShapeStyle(.white.opacity(0.07)),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            frequency == option
                            ? AnyShapeStyle(LGradients.header)
                            : AnyShapeStyle(.white.opacity(0.12)),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions (Votes)

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader(
                        title: "Identity Votes",
                        subtitle: "\(draftActions.count) added \u{2022} minimum 2"
                    )

                    Spacer()

                    Button {
                        actionToEdit = nil
                        showActionEditor = true
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }

                if draftActions.isEmpty {
                    emptyText("Each action is a vote for your identity. Add at least two.")
                } else {
                    VStack(spacing: 9) {
                        ForEach(draftActions) { draft in
                            draftActionRow(draft)
                        }
                    }
                }
            }
        }
    }

    private func draftActionRow(_ draft: ChallengeActionDraft) -> some View {
        Button {
            actionToEdit = draft
            showActionEditor = true
        } label: {
            HStack(spacing: 10) {
                Image(iconForLinkedType(draft.linkedItemType))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 18, height: 18)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.07), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(draft.linkedItemType.displayName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        if draft.behaviorLaw != .none {
                            Text("\u{2022} \(draft.behaviorLaw.shortName)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                Spacer()

                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 13, height: 13)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteDraftAction(draft)
            } label: {
                Label("Delete Action", systemImage: "trash")
            }
        }
    }

    // MARK: - Progress Reports

    private var progressReportsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Progress Reports",
                    subtitle: "Identity and system reflection check-ins"
                )

                VStack(alignment: .leading, spacing: 8) {
                    reportQuestion("Does the identity you declared feel more true than when you started?")
                    reportQuestion("Which vote for your identity felt most natural this period?")
                    reportQuestion("What friction point could you remove to make the right behavior easier?")
                    reportQuestion("What environmental change would make your next vote more obvious?")
                    reportQuestion("Have you caught yourself thinking or acting like your identity without effort?")
                    reportQuestion("What part of your system is working well?")
                }
            }
        }
    }

    private func reportQuestion(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(LGradients.header)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Reward

    private var rewardCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Reward",
                    subtitle: "How will you celebrate who you\u{2019}ve become?"
                )

                fieldBlock(title: "Reward Name") {
                    TextField("Cozy evening", text: $rewardName)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                fieldBlock(title: "Reward Description") {
                    TextField("Describe the reward", text: $rewardDescription, axis: .vertical)
                        .lineLimit(2...5)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                fieldBlock(title: "How does this reward reinforce your identity?") {
                    TextField("It aligns with who I\u{2019}m becoming because...", text: $rewardAlignmentNote, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveChallenge()
        } label: {
            Text(isEditing ? "Save Challenge" : "Create Challenge")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSave ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    // MARK: - Helpers

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

    private func fieldBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private func iconForLinkedType(_ type: LureliaChallengeLinkedItemType) -> String {
        switch type {
        case .reminder:
            return "bellfill"
        case .habit:
            return "repeatfill"
        case .routine:
            return "clockwavy"
        case .manual:
            return "checkwavy"
        }
    }

    private func loadChallenge() {
        guard let challenge else {
            return
        }

        title = challenge.title
        identityStatement = challenge.identityStatement
        details = challenge.details
        iconName = challenge.iconName
        startDate = challenge.startDate
        endDate = challenge.endDate
        frequency = challenge.frequency
        targetValue = challenge.targetValue
        targetUnit = challenge.targetUnit
        customTargetUnit = challenge.customTargetUnit
        rewardName = challenge.rewardName
        rewardDescription = challenge.rewardDescription
        rewardAlignmentNote = challenge.rewardAlignmentNote

        draftActions = challenge.sortedActions.map { action in
            ChallengeActionDraft(
                id: action.id,
                title: action.title,
                notes: action.notes,
                linkedItemType: action.linkedItemType,
                linkedItemID: action.linkedItemID,
                behaviorLaw: action.behaviorLaw,
                twoMinuteVersion: action.twoMinuteVersion,
                habitStackCue: action.habitStackCue,
                sortOrder: action.sortOrder,
                existingAction: action
            )
        }

        draftSystemSteps = challenge.sortedSystemSteps.map { step in
            SystemStepDraft(
                id: step.id,
                title: step.title,
                notes: step.notes,
                sortOrder: step.sortOrder,
                existingStep: step
            )
        }
    }

    private func saveDraftAction(_ draft: ChallengeActionDraft) {
        if let index = draftActions.firstIndex(where: { $0.id == draft.id }) {
            draftActions[index] = draft
        } else {
            var newDraft = draft
            newDraft.sortOrder = draftActions.count
            draftActions.append(newDraft)
        }

        draftActions = draftActions.enumerated().map { index, action in
            var copy = action
            copy.sortOrder = index
            return copy
        }
    }

    private func deleteDraftAction(_ draft: ChallengeActionDraft) {
        draftActions.removeAll { $0.id == draft.id }

        draftActions = draftActions.enumerated().map { index, action in
            var copy = action
            copy.sortOrder = index
            return copy
        }
    }

    private func saveDraftSystemStep(_ draft: SystemStepDraft) {
        if let index = draftSystemSteps.firstIndex(where: { $0.id == draft.id }) {
            draftSystemSteps[index] = draft
        } else {
            var newDraft = draft
            newDraft.sortOrder = draftSystemSteps.count
            draftSystemSteps.append(newDraft)
        }

        draftSystemSteps = draftSystemSteps.enumerated().map { index, step in
            var copy = step
            copy.sortOrder = index
            return copy
        }
    }

    private func deleteDraftSystemStep(_ draft: SystemStepDraft) {
        draftSystemSteps.removeAll { $0.id == draft.id }

        draftSystemSteps = draftSystemSteps.enumerated().map { index, step in
            var copy = step
            copy.sortOrder = index
            return copy
        }
    }

    private func saveChallenge() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIdentity = identityStatement.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRewardName = rewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRewardDescription = rewardDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRewardAlignment = rewardAlignmentNote.trimmingCharacters(in: .whitespacesAndNewlines)

        let targetChallenge: LureliaChallenge

        if let existing = challenge {
            targetChallenge = existing
        } else {
            targetChallenge = LureliaChallenge(
                title: trimmedTitle,
                identityStatement: trimmedIdentity,
                details: trimmedDetails,
                iconName: iconName,
                startDate: startDate,
                endDate: endDate,
                frequency: frequency,
                targetValue: targetValue,
                targetUnit: targetUnit,
                customTargetUnit: customTargetUnit.trimmingCharacters(in: .whitespacesAndNewlines),
                rewardName: trimmedRewardName,
                rewardDescription: trimmedRewardDescription,
                rewardAlignmentNote: trimmedRewardAlignment
            )
            modelContext.insert(targetChallenge)

            let startEntry = LureliaChallengeEntry(
                challenge: targetChallenge,
                sourceType: .challengeStarted,
                sourceID: targetChallenge.id,
                title: "Challenge Started",
                note: trimmedIdentity
            )
            modelContext.insert(startEntry)
        }

        targetChallenge.title = trimmedTitle
        targetChallenge.identityStatement = trimmedIdentity
        targetChallenge.details = trimmedDetails
        targetChallenge.iconName = iconName
        targetChallenge.startDate = startDate
        targetChallenge.endDate = endDate
        targetChallenge.frequency = frequency
        targetChallenge.targetValue = max(1, targetValue)
        targetChallenge.targetUnit = targetUnit
        targetChallenge.customTargetUnit = customTargetUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        targetChallenge.rewardName = trimmedRewardName
        targetChallenge.rewardDescription = trimmedRewardDescription
        targetChallenge.rewardAlignmentNote = trimmedRewardAlignment
        targetChallenge.updatedAt = Date()

        syncActions(to: targetChallenge)
        syncSystemSteps(to: targetChallenge)

        try? modelContext.save()
        dismiss()
    }

    private func syncActions(to challenge: LureliaChallenge) {
        let existingActions = challenge.actions ?? []
        let draftIDs = Set(draftActions.map(\.id))

        for action in existingActions where !draftIDs.contains(action.id) {
            modelContext.delete(action)
        }

        for draft in draftActions {
            let action: LureliaChallengeAction

            if let existing = draft.existingAction {
                action = existing
            } else if let existing = existingActions.first(where: { $0.id == draft.id }) {
                action = existing
            } else {
                action = LureliaChallengeAction(
                    title: draft.title,
                    notes: draft.notes,
                    linkedItemType: draft.linkedItemType,
                    linkedItemID: draft.linkedItemID,
                    behaviorLaw: draft.behaviorLaw,
                    twoMinuteVersion: draft.twoMinuteVersion,
                    habitStackCue: draft.habitStackCue,
                    sortOrder: draft.sortOrder
                )
                action.challenge = challenge
                modelContext.insert(action)
            }

            action.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            action.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            action.linkedItemType = draft.linkedItemType
            action.linkedItemID = draft.linkedItemID
            action.behaviorLaw = draft.behaviorLaw
            action.twoMinuteVersion = draft.twoMinuteVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            action.habitStackCue = draft.habitStackCue.trimmingCharacters(in: .whitespacesAndNewlines)
            action.sortOrder = draft.sortOrder
            action.updatedAt = Date()
        }
    }

    private func syncSystemSteps(to challenge: LureliaChallenge) {
        let existingSteps = challenge.systemSteps ?? []
        let draftIDs = Set(draftSystemSteps.map(\.id))

        for step in existingSteps where !draftIDs.contains(step.id) {
            modelContext.delete(step)
        }

        for draft in draftSystemSteps {
            let step: LureliaChallengeSystemStep

            if let existing = draft.existingStep {
                step = existing
            } else if let existing = existingSteps.first(where: { $0.id == draft.id }) {
                step = existing
            } else {
                step = LureliaChallengeSystemStep(
                    title: draft.title,
                    notes: draft.notes,
                    sortOrder: draft.sortOrder
                )
                step.challenge = challenge
                modelContext.insert(step)
            }

            step.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            step.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            step.sortOrder = draft.sortOrder
            step.updatedAt = Date()
        }
    }
}

// MARK: - Challenge Action Draft

struct ChallengeActionDraft: Identifiable, Hashable {

    var id: UUID = UUID()

    var title: String = ""
    var notes: String = ""

    var linkedItemType: LureliaChallengeLinkedItemType = .manual
    var linkedItemID: UUID?

    var behaviorLaw: LureliaBehaviorLaw = .none
    var twoMinuteVersion: String = ""
    var habitStackCue: String = ""

    var sortOrder: Int = 0

    var existingAction: LureliaChallengeAction?

    static func == (lhs: ChallengeActionDraft, rhs: ChallengeActionDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - System Step Draft

struct SystemStepDraft: Identifiable, Hashable {

    var id: UUID = UUID()

    var title: String = ""
    var notes: String = ""

    var sortOrder: Int = 0

    var existingStep: LureliaChallengeSystemStep?

    static func == (lhs: SystemStepDraft, rhs: SystemStepDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
