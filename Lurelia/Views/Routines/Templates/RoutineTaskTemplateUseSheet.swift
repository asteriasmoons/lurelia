//
//  RoutineTaskTemplateUseSheet.swift
//  Lurelia
//
//  Guided "Use Template" flow. Presents a routine picker, then a phase
//  picker if the chosen routine has phases enabled. When both are chosen
//  (or the routine has no phases), calls back with (routine, phase?).
//  The caller generates the new task via `template.makeTask(...)`,
//  inserts children, and opens the task editor for immediate tweaking.
//

import SwiftData
import SwiftUI

struct RoutineTaskTemplateUseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let template: RoutineTaskTemplate
    let routines: [LureliaRoutine]
    var onComplete: (LureliaRoutine, LureliaRoutinePhase?) -> Void

    @State private var selectedRoutine: LureliaRoutine?

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header

                        if let routine = selectedRoutine, phasesNeeded(for: routine) {
                            phasePickerBody(for: routine)
                        } else {
                            routinePickerBody
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedRoutine == nil ? "Use Template" : "Choose Phase")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitleText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button {
                if selectedRoutine != nil {
                    // Back to routine picker without closing the sheet.
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedRoutine = nil
                    }
                } else {
                    dismiss()
                }
            } label: {
                Image(selectedRoutine == nil ? "xmarkwavy" : "chevleft")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(LColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(LColors.glassSurface2, in: Circle())
                    .overlay { Circle().strokeBorder(LColors.glassBorder, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitleText: String {
        if let routine = selectedRoutine {
            return "Pick a phase in \(routine.name.isEmpty ? "this routine" : routine.name)"
        }
        return "Pick a routine to add \"\(displayTitle)\" to"
    }

    private var displayTitle: String {
        let trimmed = template.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "this template" : trimmed
    }

    // MARK: - Routine picker

    private var routinePickerBody: some View {
        Group {
            if routines.isEmpty {
                emptyRoutinesState
            } else {
                VStack(spacing: 10) {
                    ForEach(routines) { routine in
                        routineRow(routine)
                    }
                }
            }
        }
    }

    private func routineRow(_ routine: LureliaRoutine) -> some View {
        Button {
            if phasesNeeded(for: routine) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedRoutine = routine
                }
            } else {
                onComplete(routine, nil)
                dismiss()
            }
        } label: {
            GlassCard(cornerRadius: 18, padding: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 42, height: 42)
                        LureliaIconView(iconId: routine.icon.isEmpty ? "starcal" : routine.icon, size: 20)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name.isEmpty ? "Untitled Routine" : routine.name)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(routineSubtitle(routine))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(LColors.neutralPearl.opacity(0.78))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func routineSubtitle(_ routine: LureliaRoutine) -> String {
        let taskCount = (routine.tasks ?? []).count
        let phaseCount = (routine.phases ?? []).count
        if routine.phasesEnabled && phaseCount > 0 {
            return "\(phaseCount) phase\(phaseCount == 1 ? "" : "s") · \(taskCount) task\(taskCount == 1 ? "" : "s")"
        }
        return "\(taskCount) task\(taskCount == 1 ? "" : "s")"
    }

    private var emptyRoutinesState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text("No Routines Yet")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Create a routine first, then come back to add a task from this template.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Phase picker

    private func phasePickerBody(for routine: LureliaRoutine) -> some View {
        let phases = (routine.phases ?? []).sorted { $0.sortOrder < $1.sortOrder }
        return VStack(spacing: 10) {
            ForEach(phases) { phase in
                Button {
                    onComplete(routine, phase)
                    dismiss()
                } label: {
                    GlassCard(cornerRadius: 18, padding: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 42, height: 42)
                                LureliaIconView(iconId: phase.icon.isEmpty ? "sparkle" : phase.icon, size: 20)
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(phase.name.isEmpty ? "Untitled Phase" : phase.name)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                if phase.scheduleEnabled {
                                    Text(phase.formattedTimeRange)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 8)

                            Image("chevright")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13, height: 13)
                                .foregroundStyle(LColors.neutralPearl.opacity(0.78))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func phasesNeeded(for routine: LureliaRoutine) -> Bool {
        routine.phasesEnabled && !((routine.phases ?? []).isEmpty)
    }
}
