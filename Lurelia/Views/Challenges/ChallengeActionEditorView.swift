//
//  ChallengeActionEditorView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct ChallengeActionEditorView: View {

    @Environment(\.dismiss) private var dismiss

    let action: ChallengeActionDraft?
    let onSave: (ChallengeActionDraft) -> Void

    @State private var title: String = ""
    @State private var notes: String = ""

    @State private var linkedItemType: LureliaChallengeLinkedItemType = .manual
    @State private var linkedItemID: UUID?

    @State private var showLinkPicker = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        identityCard

                        linkCard
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
        }
        .onAppear {
            loadAction()
        }
        .sheet(isPresented: $showLinkPicker) {
            ChallengeLinkPickerView(
                linkedType: linkedItemType,
                selectedID: $linkedItemID
            )
        }
    }

    // MARK: - Identity

    private var identityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                sectionHeader(
                    title: "Action",
                    subtitle: "Challenge action details"
                )

                fieldBlock(title: "Title") {
                    TextField(
                        "Complete Morning Routine",
                        text: $title
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                }

                fieldBlock(title: "Notes") {
                    TextField(
                        "Optional notes",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Linking

    private var linkCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                sectionHeader(
                    title: "Linked Content",
                    subtitle: "Reminder, habit, routine, or manual"
                )

                VStack(spacing: 8) {
                    ForEach(
                        LureliaChallengeLinkedItemType.allCases,
                        id: \.self
                    ) { type in

                        typeButton(type)
                    }
                }

                if linkedItemType != .manual {

                    Button {
                        showLinkPicker = true
                    } label: {
                        HStack(spacing: 12) {

                            Image(iconForType(linkedItemType))
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(LGradients.header)
                                .frame(width: 18, height: 18)

                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text("Linked Item")
                                    .font(
                                        .system(
                                            size: 13,
                                            weight: .black,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white)

                                Text(
                                    linkedItemID == nil
                                    ? "Select Item"
                                    : "Item Selected"
                                )
                                .font(
                                    .system(
                                        size: 11,
                                        weight: .semibold,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(
                                    .white.opacity(0.5)
                                )
                            }

                            Spacer()

                            Image("chevright")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(
                                    LGradients.header
                                )
                                .frame(
                                    width: 13,
                                    height: 13
                                )
                        }
                        .padding(12)
                        .background(
                            .white.opacity(0.05),
                            in: RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func typeButton(
        _ type: LureliaChallengeLinkedItemType
    ) -> some View {

        Button {
            linkedItemType = type

            if type == .manual {
                linkedItemID = nil
            }
        } label: {

            HStack(spacing: 10) {

                Image(iconForType(type))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        linkedItemType == type
                        ? AnyShapeStyle(.white)
                        : AnyShapeStyle(LGradients.header)
                    )
                    .frame(width: 18, height: 18)

                Text(type.displayName)
                    .font(
                        .system(
                            size: 13,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        linkedItemType == type
                        ? AnyShapeStyle(.white)
                        : AnyShapeStyle(.white.opacity(0.8))
                    )

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                linkedItemType == type
                ? AnyShapeStyle(LGradients.header)
                : AnyShapeStyle(.white.opacity(0.05)),
                in: RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            saveAction()
        } label: {
            Text("Save Action")
                .font(
                    .system(
                        size: 15,
                        weight: .black,
                        design: .rounded
                    )
                )
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

    // MARK: - Helpers

    private func saveAction() {

        let draft = ChallengeActionDraft(
            id: action?.id ?? UUID(),
            title: title,
            notes: notes,
            linkedItemType: linkedItemType,
            linkedItemID: linkedItemID,
            sortOrder: action?.sortOrder ?? 0,
            existingAction: action?.existingAction
        )

        onSave(draft)

        dismiss()
    }

    private func loadAction() {

        guard let action else {
            return
        }

        title = action.title
        notes = action.notes
        linkedItemType = action.linkedItemType
        linkedItemID = action.linkedItemID
    }

    private func iconForType(
        _ type: LureliaChallengeLinkedItemType
    ) -> String {

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

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title)
                .font(
                    .system(
                        size: 18,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Text(subtitle)
                .font(
                    .system(
                        size: 11,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.5)
                )
        }
    }

    private func fieldBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Text(title.uppercased())
                .font(
                    .system(
                        size: 10,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.45)
                )

            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                )
        }
    }
}
