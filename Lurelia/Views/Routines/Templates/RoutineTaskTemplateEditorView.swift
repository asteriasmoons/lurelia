//
//  RoutineTaskTemplateEditorView.swift
//  Lurelia
//
//  Dedicated editor for a `RoutineTaskTemplate`. Reuses the exact same
//  field UI (`RoutineTaskFieldsForm`) as the routine task editor so a
//  template looks and feels identical to editing a task. One Save button:
//  saving updates the template only. Never touches any tasks that were
//  previously generated from this template.
//

import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct RoutineTaskTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var template: RoutineTaskTemplate
    /// True when the template hasn't been inserted into the model context
    /// yet — this is the "Save as Template" path where we pre-populate a
    /// fresh template from a task and only persist it if the user taps
    /// Save Template. False when editing an existing library template.
    let isNew: Bool

    // Field state (seeded from the template on init; written back on save)
    @State private var title: String
    @State private var notes: String
    @State private var taskContext: String
    @State private var selectedIcon: String
    @State private var purpose: String
    @State private var motivation: String
    @State private var trigger: String
    @State private var triggerType: LureliaCueType?
    @State private var triggerReason: String
    @State private var environment: String
    @State private var reward: String
    @State private var consequence: String
    @State private var recoveryPlan: String
    @State private var hasDueTime: Bool
    @State private var dueHour: Int
    @State private var dueMinute: Int
    @State private var estimatedDuration: Int
    @State private var repeatsOnDays: Bool
    @State private var scheduledDays: Set<Int>
    @State private var notificationsEnabled: Bool
    @State private var leadMinutes: Set<Int>
    @State private var alarmEnabled: Bool
    @State private var alarmSoundName: String
    @State private var steps: [StepDraft]
    @State private var supplies: [SupplyDraft]
    @State private var obstacles: [ObstacleDraft]

    private let tint: Color = LColors.neutralPearl.opacity(0.78)

    init(template: RoutineTaskTemplate, isNew: Bool = false) {
        self.template = template
        self.isNew = isNew
        _title = State(initialValue: template.title)
        _notes = State(initialValue: template.notes)
        _taskContext = State(initialValue: template.context)
        _selectedIcon = State(initialValue: template.icon.isEmpty ? "sparkle" : template.icon)
        _purpose = State(initialValue: template.purpose)
        _motivation = State(initialValue: template.motivation)
        _trigger = State(initialValue: template.trigger)
        _triggerType = State(initialValue: template.triggerTypeRaw.flatMap(LureliaCueType.init(rawValue:)))
        _triggerReason = State(initialValue: template.triggerReason)
        _environment = State(initialValue: template.environment)
        _reward = State(initialValue: template.reward)
        _consequence = State(initialValue: template.consequence)
        _recoveryPlan = State(initialValue: template.recoveryPlan)
        _hasDueTime = State(initialValue: template.hasDueTime)
        _dueHour = State(initialValue: template.dueHour)
        _dueMinute = State(initialValue: template.dueMinute)
        _estimatedDuration = State(initialValue: max(0, template.estimatedDurationMinutes))
        _repeatsOnDays = State(initialValue: template.repeatsOnDays)
        _scheduledDays = State(initialValue: Set(template.scheduledDays))
        _notificationsEnabled = State(initialValue: template.notificationsEnabled)
        _leadMinutes = State(initialValue: Set(template.notificationLeadMinutes))
        _alarmEnabled = State(initialValue: template.alarmEnabled)
        _alarmSoundName = State(initialValue: template.alarmSoundName ?? LureliaReminderAlarmSound.defaultSound.fileName)
        _steps = State(initialValue: template.steps.map { StepDraft(title: $0.title) })
        _supplies = State(initialValue: template.supplies.map { SupplyDraft(name: $0.name) })
        _obstacles = State(initialValue: template.obstacles.map { ObstacleDraft(obstacle: $0.obstacle, solution: $0.solution) })
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header

                        RoutineTaskFieldsForm(
                            accent: AnyShapeStyle(tint),
                            accentColor: tint,
                            title: $title,
                            notes: $notes,
                            taskContext: $taskContext,
                            selectedIcon: $selectedIcon,
                            purpose: $purpose,
                            motivation: $motivation,
                            trigger: $trigger,
                            triggerType: $triggerType,
                            triggerReason: $triggerReason,
                            environment: $environment,
                            reward: $reward,
                            consequence: $consequence,
                            recoveryPlan: $recoveryPlan,
                            hasDueTime: $hasDueTime,
                            dueHour: $dueHour,
                            dueMinute: $dueMinute,
                            estimatedDuration: $estimatedDuration,
                            repeatsOnDays: $repeatsOnDays,
                            scheduledDays: $scheduledDays,
                            notificationsEnabled: $notificationsEnabled,
                            leadMinutes: $leadMinutes,
                            alarmEnabled: $alarmEnabled,
                            alarmSoundName: $alarmSoundName,
                            steps: $steps,
                            supplies: $supplies,
                            obstacles: $obstacles
                        )

                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(isNew ? "Save as Template" : "Edit Template")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button { dismiss() } label: {
                Image("xmarkwavy")
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

    private var saveButton: some View {
        Button { save() } label: {
            Text("Save Template")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(canSave ? tint.wcagContrastingSolidTextColor : .white.opacity(0.45))
                .wcagContrastLift(on: tint, isActive: canSave)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSave ? tint : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.top, 6)
    }

    private func save() {
        if isNew {
            // Fresh template from "Save as Template" — insert now that the
            // user has committed. Dismissing without saving would leave the
            // in-memory template unpersisted, no cleanup needed.
            modelContext.insert(template)
        }

        RoutineTaskTemplateWriter.commit(
            state: TemplateFieldState(
                title: title,
                notes: notes,
                taskContext: taskContext,
                selectedIcon: selectedIcon,
                purpose: purpose,
                motivation: motivation,
                trigger: trigger,
                triggerType: triggerType,
                triggerReason: triggerReason,
                environment: environment,
                reward: reward,
                consequence: consequence,
                recoveryPlan: recoveryPlan,
                hasDueTime: hasDueTime,
                dueHour: dueHour,
                dueMinute: dueMinute,
                estimatedDuration: estimatedDuration,
                repeatsOnDays: repeatsOnDays,
                scheduledDays: scheduledDays,
                notificationsEnabled: notificationsEnabled,
                leadMinutes: leadMinutes,
                alarmEnabled: alarmEnabled,
                alarmSoundName: alarmSoundName,
                steps: steps,
                supplies: supplies,
                obstacles: obstacles
            ),
            into: template
        )
        try? modelContext.save()
        dismiss()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Shared field-state container

/// Snapshot of every field a template editor manages. Used by both the
/// standalone template editor and the "Save as Template" preview sheet
/// so the write-back logic lives in exactly one place.
struct TemplateFieldState {
    var title: String
    var notes: String
    var taskContext: String
    var selectedIcon: String
    var purpose: String
    var motivation: String
    var trigger: String
    var triggerType: LureliaCueType?
    var triggerReason: String
    var environment: String
    var reward: String
    var consequence: String
    var recoveryPlan: String
    var hasDueTime: Bool
    var dueHour: Int
    var dueMinute: Int
    var estimatedDuration: Int
    var repeatsOnDays: Bool
    var scheduledDays: Set<Int>
    var notificationsEnabled: Bool
    var leadMinutes: Set<Int>
    var alarmEnabled: Bool
    var alarmSoundName: String
    var steps: [StepDraft]
    var supplies: [SupplyDraft]
    var obstacles: [ObstacleDraft]
}

// MARK: - Writer (shared between editor and preview sheet)

enum RoutineTaskTemplateWriter {
    static func commit(state: TemplateFieldState, into template: RoutineTaskTemplate) {
        template.title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        template.notes = state.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        template.context = state.taskContext.trimmingCharacters(in: .whitespacesAndNewlines)
        template.icon = state.selectedIcon.isEmpty ? "sparkle" : state.selectedIcon
        template.purpose = state.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        template.motivation = state.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        template.trigger = state.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        template.triggerTypeRaw = state.triggerType?.rawValue
        template.triggerReason = state.triggerReason.trimmingCharacters(in: .whitespacesAndNewlines)
        template.environment = state.environment.trimmingCharacters(in: .whitespacesAndNewlines)
        template.reward = state.reward.trimmingCharacters(in: .whitespacesAndNewlines)
        template.consequence = state.consequence.trimmingCharacters(in: .whitespacesAndNewlines)
        template.recoveryPlan = state.recoveryPlan.trimmingCharacters(in: .whitespacesAndNewlines)

        template.hasDueTime = state.hasDueTime
        template.dueHour = state.dueHour
        template.dueMinute = state.dueMinute
        template.estimatedDurationMinutes = max(0, state.estimatedDuration)
        template.repeatsOnDays = state.repeatsOnDays
        template.scheduledDays = state.scheduledDays.sorted()

        template.notificationsEnabled = state.notificationsEnabled && state.hasDueTime
        template.notificationLeadMinutes = state.leadMinutes.sorted()
        template.alarmEnabled = state.alarmEnabled && state.hasDueTime
        template.alarmSoundName = (state.alarmEnabled && state.hasDueTime) ? state.alarmSoundName : nil

        template.steps = state.steps
            .compactMap {
                let trimmed = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : RoutineTaskTemplateStep(title: trimmed)
            }
        template.supplies = state.supplies
            .compactMap {
                let trimmed = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : RoutineTaskTemplateSupply(name: trimmed)
            }
        template.obstacles = state.obstacles
            .compactMap {
                let trimmedObstacle = $0.obstacle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedObstacle.isEmpty else { return nil }
                return RoutineTaskTemplateObstacle(
                    obstacle: trimmedObstacle,
                    solution: $0.solution.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

        template.updatedDate = Date()
    }
}
