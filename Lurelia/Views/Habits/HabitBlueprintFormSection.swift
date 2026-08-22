//
//  HabitBlueprintFormSection.swift
//  Lurelia
//

import SwiftUI

struct HabitBlueprintFormSection: View {
    @Binding var identityStatement: String
    @Binding var habitPurpose: String
    @Binding var implementationIntention: String
    @Binding var selectedCueType: LureliaCueType?
    @Binding var cueDescription: String
    @Binding var cueReason: String
    @Binding var currentEnvironment: String
    @Binding var idealEnvironment: String
    @Binding var environmentChanges: String
    @Binding var temptationNeed: String
    @Binding var temptationWant: String
    @Binding var habitRules: [String]
    @Binding var habitObstacles: [String]
    @Binding var habitSolutions: [String]
    @Binding var levels: [LureliaHabitLevel]
    @Binding var immediateReward: String
    @Binding var longTermReward: String
    /// Optional accent tint. `nil` uses the neutral glass sheet style.
    var tint: Color? = nil

    private var accentStyle: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(LColors.neutralPearl.opacity(0.82))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            sectionHeader("HABIT BLUEPRINT")

            // MARK: - Identity

            subsectionLabel("IDENTITY")
            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Who am I becoming?")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    blueprintTextField(
                        placeholder: "e.g. I am someone who takes care of my skin every day.",
                        text: $identityStatement
                    )
                }
            }

            // MARK: - Purpose

            subsectionLabel("PURPOSE")
            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why does this habit exist?")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    blueprintTextField(
                        placeholder: "e.g. Healthy skin and a consistent morning routine.",
                        text: $habitPurpose
                    )
                }
            }

            // MARK: - Implementation Intention

            subsectionLabel("IMPLEMENTATION INTENTION")
            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Write a clear when/where plan for this habit.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    blueprintTextArea(
                        placeholder: "e.g. I will wash my face in the morning before I sit down at 8AM in the bathroom.",
                        text: $implementationIntention
                    )
                }
            }

            // MARK: - Cue

            subsectionLabel("CUE")

            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cue Type")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    cueTypeGrid
                }
            }

            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What reminds you to begin this habit?")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    blueprintTextField(
                        placeholder: "e.g. Headband sitting on top of my laptop.",
                        text: $cueDescription
                    )
                }
            }

            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why This Cue Works")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    blueprintTextArea(
                        placeholder: "e.g. Because I always reach for my laptop immediately after waking up.",
                        text: $cueReason
                    )
                }
            }

            // MARK: - Environment

            subsectionLabel("ENVIRONMENT")

            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Environment")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("What does your current environment encourage?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        blueprintTextField(placeholder: "", text: $currentEnvironment)
                    }

                    Rectangle().fill(.white.opacity(0.06)).frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ideal Environment")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("What should the environment support instead?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        blueprintTextField(placeholder: "", text: $idealEnvironment)
                    }

                    Rectangle().fill(.white.opacity(0.06)).frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Changes to Make")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("What small changes would make this habit easier?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        blueprintTextField(placeholder: "", text: $environmentChanges)
                    }
                }
            }
            
            // MARK: - Temptation Bundling

            subsectionLabel("TEMPTATION BUNDLING")

            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Need")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("What do you need to do?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))

                        blueprintTextField(
                            placeholder: "e.g. Read for 20 minutes.",
                            text: $temptationNeed
                        )
                    }

                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Want")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("What do you want to do after or during it?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))

                        blueprintTextField(
                            placeholder: "e.g. Drink coffee or code guilt free.",
                            text: $temptationWant
                        )
                    }
                }
            }

            // MARK: - Rules

            subsectionLabel("HABIT RULES")
            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(habitRules.enumerated()), id: \.offset) { index, _ in
                        HStack(alignment: .top, spacing: 10) {
                            ruleNumberCircle(index + 1)

                            TextField("Rule \(index + 1)", text: $habitRules[index])
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white)

                            Button {
                                habitRules.remove(at: index)
                            } label: {
                                Image("xmarkwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }

                        if index < habitRules.count - 1 {
                            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                        }
                    }

                    Button {
                        habitRules.append("")
                    } label: {
                        HStack(spacing: 6) {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(accentStyle)
                            Text("Add Rule")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // MARK: - Obstacles & Solutions

            subsectionLabel("OBSTACLES & SOLUTIONS")
            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(habitObstacles.enumerated()), id: \.offset) { index, _ in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                ruleNumberCircle(index + 1)

                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Obstacle", text: $habitObstacles[index])
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)

                                    HStack(spacing: 6) {
                                        Image("rightwavy")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                            .foregroundStyle(LColors.success.opacity(0.6))

                                        let solutionBinding = Binding<String>(
                                            get: {
                                                index < habitSolutions.count ? habitSolutions[index] : ""
                                            },
                                            set: { newValue in
                                                while habitSolutions.count <= index {
                                                    habitSolutions.append("")
                                                }
                                                habitSolutions[index] = newValue
                                            }
                                        )
                                        TextField("Solution", text: solutionBinding)
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(LColors.success.opacity(0.85))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    habitObstacles.remove(at: index)
                                    if index < habitSolutions.count {
                                        habitSolutions.remove(at: index)
                                    }
                                } label: {
                                    Image("xmarkwavy")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(.white.opacity(0.35))
                                }
                                .buttonStyle(.plain)
                            }

                            if index < habitObstacles.count - 1 {
                                Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                            }
                        }
                    }

                    Button {
                        habitObstacles.append("")
                        habitSolutions.append("")
                    } label: {
                        HStack(spacing: 6) {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(accentStyle)
                            Text("Add Obstacle")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // MARK: - Habit Levels

            subsectionLabel("HABIT LEVELS")

            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 12) {

                    ForEach(Array(levels.enumerated()), id: \.offset) { index, _ in

                        HStack(alignment: .center, spacing: 10) {

                            Image("\(min(index + 1, 9))wavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(accentStyle)

                            TextField(
                                "Level \(index + 1)",
                                text: levelBinding(index)
                            )
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white)

                            Button {
                                levels.remove(at: index)
                                normalizeLevelSortOrder()
                            } label: {
                                Image("xmarkwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }

                        if index < levels.count - 1 {
                            Rectangle()
                                .fill(.white.opacity(0.06))
                                .frame(height: 1)
                        }
                    }

                    Button {

                        guard levels.count < 9 else { return }

                        levels.append(
                            LureliaHabitLevel(
                                title: "",
                                sortOrder: levels.count
                            )
                        )

                    } label: {

                        HStack(spacing: 6) {

                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(accentStyle)

                            Text("Add Level")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                    }
                    .buttonStyle(.plain)
                }
            }

            // MARK: - Rewards

            subsectionLabel("REWARDS")
            GlassCard(tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Immediate Reward")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        blueprintTextField(
                            placeholder: "e.g. Fresh coffee, clean feeling, ten minutes of reading.",
                            text: $immediateReward
                        )
                    }

                    Rectangle().fill(.white.opacity(0.06)).frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Long-Term Reward")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        blueprintTextField(
                            placeholder: "e.g. Healthy skin, consistency, confidence.",
                            text: $longTermReward
                        )
                    }
                }
            }
        }
    }

    // MARK: - Cue Type Grid

    private var cueTypeGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(LureliaCueType.allCases) { cueType in
                let isSelected = selectedCueType == cueType
                Button {
                    if selectedCueType == cueType {
                        selectedCueType = nil
                    } else {
                        selectedCueType = cueType
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(cueType.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)

                        Text(cueType.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        isSelected
                        ? accentStyle
                        : AnyShapeStyle(Color.white.opacity(0.06))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.clear : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image("linedpages")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(accentStyle)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.8)
        }
    }

    private func subsectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.3))
            .tracking(0.6)
    }

    private func blueprintTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white)
    }

    private func blueprintTextArea(placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            TextEditor(text: text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 70)
        }
    }
    
    private func levelBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard levels.indices.contains(index) else { return "" }
                return levels[index].title
            },
            set: { newValue in
                guard levels.indices.contains(index) else { return }
                levels[index].title = newValue
                levels[index].updatedAt = Date()
            }
        )
    }

    private func normalizeLevelSortOrder() {
        for index in levels.indices {
            levels[index].sortOrder = index
            levels[index].updatedAt = Date()
        }
    }

    private func ruleNumberCircle(_ number: Int) -> some View {
        ZStack {
            Circle()
                .strokeBorder(accentStyle, lineWidth: 1.5)
                .frame(width: 26, height: 26)

            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
