//
//  NewMilestoneSheet.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaNewMilestoneSheet: View {

    @Environment(\.modelContext) private var modelContext

    @Environment(\.dismiss) private var dismiss

    @Bindable var journey: LureliaJourney
    var milestone: LureliaJourneyMilestone?

    @State private var title = ""
    @State private var details = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var reward = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEditing: Bool {
        milestone != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    milestoneSheetHeader

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            previewCard

                            formSection(label: "MILESTONE") {
                                textField(
                                    placeholder: "Milestone title",
                                    text: $title
                                )

                                textEditor(
                                    placeholder: "What needs to happen for this milestone?",
                                    text: $details
                                )
                            }

                            formSection(label: "TARGET") {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Toggle(isOn: $hasTargetDate) {
                                            Text("Add target date")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                        }
                                        .tint(LColors.gradientPurple)

                                        if hasTargetDate {
                                            DatePicker(
                                                "Target Date",
                                                selection: $targetDate,
                                                displayedComponents: .date
                                            )
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .tint(LColors.gradientBlue)
                                        }
                                    }
                                }
                            }

                            formSection(label: "REWARD") {
                                GlassCard {
                                    HStack(spacing: 12) {
                                        Image("trophystar")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(LGradients.header)
                                            .frame(width: 24, height: 24)

                                        TextField("Reward for completing this milestone", text: $reward)
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundStyle(.white)
                                            .textInputAutocapitalization(.sentences)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                loadExistingMilestoneIfNeeded()
            }
        }
    }

    private var milestoneSheetHeader: some View {
        HStack(spacing: 12) {
            Text(isEditing ? "Edit Milestone" : "New Milestone")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Button {
                save()
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(canSave ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(.white.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

// MARK: - Preview

extension LureliaNewMilestoneSheet {

    private var previewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEditing ? "EDIT MILESTONE" : "MILESTONE PREVIEW")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Text(titlePreview)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detailsPreview)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)

                if hasTargetDate {
                    Text(targetDate.formatted(date: .long, time: .omitted))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.gradientBlue)
                }

                if !reward.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 6) {
                        Image("trophystar")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 14, height: 14)

                        Text(reward.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LGradients.header)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var titlePreview: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your Milestone" : trimmed
    }

    private var detailsPreview: String {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "A meaningful checkpoint inside this journey." : trimmed
    }
}

// MARK: - Load

extension LureliaNewMilestoneSheet {

    private func loadExistingMilestoneIfNeeded() {
        guard let milestone else { return }

        title = milestone.title
        details = milestone.details

        if let target = milestone.targetDate {
            hasTargetDate = true
            targetDate = target
        } else {
            hasTargetDate = false
        }

        reward = milestone.reward ?? ""
    }
}

// MARK: - Form Pieces

extension LureliaNewMilestoneSheet {

    @ViewBuilder
    private func formSection<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.8)

            content()
        }
    }

    @ViewBuilder
    private func textField(
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        GlassCard {
            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
        }
    }

    @ViewBuilder
    private func textEditor(
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        GlassCard {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }

                TextEditor(text: text)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 110)
            }
        }
    }
}

// MARK: - Save

extension LureliaNewMilestoneSheet {

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReward = reward.trimmingCharacters(in: .whitespacesAndNewlines)

        if let milestone {
            milestone.title = trimmedTitle
            milestone.details = trimmedDetails
            milestone.targetDate = hasTargetDate ? targetDate : nil
            milestone.reward = trimmedReward.isEmpty ? nil : trimmedReward
            milestone.updatedAt = Date()
            dismiss()
            return
        }

        let existingCount = journey.milestones?.count ?? 0

        let newMilestone = LureliaJourneyMilestone(
            title: trimmedTitle,
            details: trimmedDetails,
            sortOrder: existingCount
        )

        newMilestone.journey = journey
        newMilestone.targetDate = hasTargetDate ? targetDate : nil
        newMilestone.reward = trimmedReward.isEmpty ? nil : trimmedReward
        newMilestone.status = existingCount == 0 ? .inProgress : .notStarted
        newMilestone.updatedAt = Date()

        modelContext.insert(newMilestone)
        dismiss()
    }
}
