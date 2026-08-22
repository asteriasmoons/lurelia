//
//  NewJourneySheet.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaNewJourneySheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var journey: LureliaJourney?

    @State private var title = ""
    @State private var summary = ""
    @State private var vision = ""
    @State private var iconName = "journey"
    @State private var colorHex = "#8B5CF6"
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var showIconPicker = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEditing: Bool {
        journey != nil
    }
    
    private var useFullScreenCover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    journeySheetHeader

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            previewCard

                            formSection(label: "JOURNEY") {
                                textField(
                                    placeholder: "Journey title",
                                    text: $title
                                )

                                textField(
                                    placeholder: "Short summary",
                                    text: $summary
                                )
                            }

                            formSection(label: "VISION") {
                                textEditor(
                                    placeholder: "What is this journey helping you become, build, heal, or create?",
                                    text: $vision
                                )
                            }

                            formSection(label: "APPEARANCE") {
                                iconPickerButton

                                colorPickerRow
                            }

                            formSection(label: "TARGET") {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Toggle(isOn: $hasTargetDate) {
                                            Text("Add target date")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                        }
                                        .tint(LColors.neutralPearl.opacity(0.72))

                                        if hasTargetDate {
                                            DatePicker(
                                                "Target Date",
                                                selection: $targetDate,
                                                displayedComponents: .date
                                            )
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .tint(LColors.neutralPearl.opacity(0.72))
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
            .sheet(isPresented: Binding(
                get: { !useFullScreenCover && showIconPicker },
                set: { showIconPicker = $0 }
            )) {
                IconPickerView(selectedIcon: $iconName)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .fullScreenCover(isPresented: Binding(
                get: { useFullScreenCover && showIconPicker },
                set: { showIconPicker = $0 }
            )) {
                IconPickerView(selectedIcon: $iconName)
            }
            .onAppear {
                loadExistingJourneyIfNeeded()
            }
        }
    }

    private var journeySheetHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Text(isEditing ? "Edit Journey" : "New Journey")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Button {
                save()
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(canSave ? AnyShapeStyle(LColors.textPrimary) : AnyShapeStyle(.white.opacity(0.35)))
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

extension LureliaNewJourneySheet {

    private var previewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(isEditing ? "EDIT JOURNEY" : "JOURNEY PREVIEW")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 12) {
                    journeyIcon

                    VStack(alignment: .leading, spacing: 4) {
                        Text(titlePreview)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(summaryPreview)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    Spacer()
                }

                if !vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VISION")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Text(vision)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private var journeyIcon: some View {
        ZStack {
            Circle()
                .fill(LColors.glassSurface2)

            Circle()
                .strokeBorder(LColors.glassBorder, lineWidth: 1.4)

            Image(iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LColors.neutralPearl.opacity(0.82))
                .padding(11)
        }
        .frame(width: 58, height: 58)
    }

    private var titlePreview: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your Journey" : trimmed
    }

    private var summaryPreview: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "A meaningful path made of milestones, steps, reminders, and routines." : trimmed
    }
}

// MARK: - Form Pieces

extension LureliaNewJourneySheet {

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

    private var iconPickerButton: some View {
        Button {
            showIconPicker = true
        } label: {
            GlassCard {
                HStack(spacing: 12) {
                    journeyIcon
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose Icon")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(iconName)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LColors.neutralPearl.opacity(0.82))
                        .frame(width: 16, height: 16)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var colorPickerRow: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Journey Color")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.self) { option in
                        Button {
                            colorHex = option
                        } label: {
                            Circle()
                                .fill(Color(lureliaHex: option))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            colorHex == option ? Color.white : Color.white.opacity(0.18),
                                            lineWidth: colorHex == option ? 2 : 1
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
        }
    }

    private var colorOptions: [String] {
        [
            "#8B5CF6",
            "#5B7CFF",
            "#FF50D4",
            "#7EEDFF",
            "#41E58A",
            "#F1D38A"
        ]
    }
}

// MARK: - Load

extension LureliaNewJourneySheet {

    private func loadExistingJourneyIfNeeded() {
        guard let journey else { return }

        title = journey.title
        summary = journey.summary
        vision = journey.vision
        iconName = journey.iconName
        colorHex = journey.colorHex

        if let target = journey.targetDate {
            hasTargetDate = true
            targetDate = target
        } else {
            hasTargetDate = false
        }
    }
}

// MARK: - Save

extension LureliaNewJourneySheet {

    private func save() {
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleTrimmed.isEmpty else { return }

        let summaryTrimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let visionTrimmed = vision.trimmingCharacters(in: .whitespacesAndNewlines)

        if let journey {
            journey.title = titleTrimmed
            journey.summary = summaryTrimmed
            journey.vision = visionTrimmed
            journey.iconName = iconName
            journey.colorHex = colorHex
            journey.targetDate = hasTargetDate ? targetDate : nil
            journey.updatedAt = Date()
            dismiss()
            return
        }

        let newJourney = LureliaJourney(
            title: titleTrimmed,
            summary: summaryTrimmed,
            vision: visionTrimmed
        )

        newJourney.iconName = iconName
        newJourney.colorHex = colorHex
        newJourney.targetDate = hasTargetDate ? targetDate : nil
        newJourney.status = .active
        newJourney.updatedAt = Date()

        modelContext.insert(newJourney)
        dismiss()
    }
}
