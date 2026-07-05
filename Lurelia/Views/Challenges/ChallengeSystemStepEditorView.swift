//
//  ChallengeSystemStepEditorView.swift
//  Lurelia
//

import SwiftUI

struct ChallengeSystemStepEditorView: View {

    @Environment(\.dismiss) private var dismiss

    let step: SystemStepDraft?
    let onSave: (SystemStepDraft) -> Void

    @State private var title: String
    @State private var notes: String

    private var isEditing: Bool {
        step != nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        step: SystemStepDraft?,
        onSave: @escaping (SystemStepDraft) -> Void
    ) {
        self.step = step
        self.onSave = onSave

        _title = State(initialValue: step?.title ?? "")
        _notes = State(initialValue: step?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        systemStepCard
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
        }
    }

    private var systemStepCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: isEditing ? "Edit System Step" : "Add System Step",
                    subtitle: "Describe one part of the system that supports this challenge"
                )

                fieldBlock(title: "Step Title") {
                    TextField("Prepare clothes the night before", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                fieldBlock(title: "Notes") {
                    TextField("What makes this step helpful?", text: $notes, axis: .vertical)
                        .lineLimit(3...7)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveStep()
        } label: {
            Text(isEditing ? "Save Step" : "Add Step")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    canSave
                    ? AnyShapeStyle(LGradients.header)
                    : AnyShapeStyle(.white.opacity(0.12)),
                    in: Capsule()
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func saveStep() {
        let draft = SystemStepDraft(
            id: step?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: step?.sortOrder ?? 0,
            existingStep: step?.existingStep
        )

        onSave(draft)
        dismiss()
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
}
