//
//  JourneyNoteSheet.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaJourneyNoteSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var journey: LureliaJourney
    var note: LureliaJourneyNote?

    // Optional pre-linked context
    var prelinkedMilestone: LureliaJourneyMilestone? = nil
    var prelinkedStep: LureliaJourneyStep? = nil

    @State private var title = ""
    @State private var noteBody = ""
    @State private var selectedMilestoneID: UUID? = nil
    @State private var selectedStepID: UUID? = nil

    private var isEditing: Bool { note != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sortedMilestones: [LureliaJourneyMilestone] {
        (journey.milestones ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var stepsForSelectedMilestone: [LureliaJourneyStep] {
        guard let mid = selectedMilestoneID,
              let milestone = sortedMilestones.first(where: { $0.id == mid })
        else { return [] }
        return (milestone.steps ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedMilestone: LureliaJourneyMilestone? {
        guard let mid = selectedMilestoneID else { return nil }
        return sortedMilestones.first { $0.id == mid }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {

                            // Preview
                            GlassCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(title.isEmpty ? "Note Title" : title)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundStyle(title.isEmpty ? .white.opacity(0.3) : .white)

                                    if !noteBody.isEmpty {
                                        Text(noteBody)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.65))
                                            .lineLimit(3)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Title
                            GlassCard {
                                TextField("Note title", text: $title)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(.white)
                                    .textInputAutocapitalization(.sentences)
                            }

                            // Body
                            GlassCard {
                                ZStack(alignment: .topLeading) {
                                    if noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Write your note...")
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.35))
                                            .padding(.top, 8)
                                            .padding(.horizontal, 4)
                                    }

                                    TextEditor(text: $noteBody)
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(.white)
                                        .scrollContentBackground(.hidden)
                                        .background(.clear)
                                        .frame(minHeight: 140)
                                }
                            }

                            // Link to milestone
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LINK TO MILESTONE")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))

                                    if sortedMilestones.isEmpty {
                                        Text("No milestones yet")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.45))
                                    } else {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                milestoneChip(
                                                    label: "None",
                                                    isSelected: selectedMilestoneID == nil
                                                ) {
                                                    selectedMilestoneID = nil
                                                    selectedStepID = nil
                                                }

                                                ForEach(sortedMilestones) { milestone in
                                                    milestoneChip(
                                                        label: milestone.title,
                                                        isSelected: selectedMilestoneID == milestone.id
                                                    ) {
                                                        selectedMilestoneID = milestone.id
                                                        selectedStepID = nil
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    if selectedMilestone != nil, !stepsForSelectedMilestone.isEmpty {
                                        Divider().overlay(.white.opacity(0.1))

                                        Text("LINK TO STEP")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.5))

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                milestoneChip(
                                                    label: "None",
                                                    isSelected: selectedStepID == nil
                                                ) {
                                                    selectedStepID = nil
                                                }

                                                ForEach(stepsForSelectedMilestone) { step in
                                                    milestoneChip(
                                                        label: step.title,
                                                        isSelected: selectedStepID == step.id
                                                    ) {
                                                        selectedStepID = step.id
                                                    }
                                                }
                                            }
                                        }
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
            .onAppear { load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Text(isEditing ? "Edit Note" : "New Note")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Button { save() } label: {
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

    // MARK: - Chip

    @ViewBuilder
    private func milestoneChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? LColors.bg : .white.opacity(0.75))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.08)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Color.white.opacity(0.14)),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load / Save

    private func load() {
        if let prelinkedMilestone {
            selectedMilestoneID = prelinkedMilestone.id
        }
        if let prelinkedStep {
            selectedStepID = prelinkedStep.id
            if let m = prelinkedStep.milestone {
                selectedMilestoneID = m.id
            }
        }

        guard let note else { return }
        title = note.title
        noteBody = note.body
        selectedMilestoneID = note.linkedMilestoneID
        selectedStepID = note.linkedStepID
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if let note {
            note.title = trimmedTitle
            note.body = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
            note.linkedMilestoneID = selectedMilestoneID
            note.linkedStepID = selectedStepID
            note.updatedAt = Date()
            dismiss()
            return
        }

        let newNote = LureliaJourneyNote(
            title: trimmedTitle,
            body: noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        newNote.journey = journey
        newNote.linkedMilestoneID = selectedMilestoneID
        newNote.linkedStepID = selectedStepID
        modelContext.insert(newNote)
        dismiss()
    }
}
