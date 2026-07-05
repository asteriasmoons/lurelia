//
//  NewJourneyStepSheet.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct LureliaNewJourneyStepSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LureliaReminder.scheduledDate)
    private var reminders: [LureliaReminder]

    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]

    @Query(sort: \LureliaHabit.title)
    private var habits: [LureliaHabit]

    @Bindable var milestone: LureliaJourneyMilestone
    var step: LureliaJourneyStep?

    @State private var title = ""
    @State private var details = ""
    @State private var status: LureliaJourneyStepStatus = .notStarted
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var linkedReminderIDs: Set<UUID> = []
    @State private var linkedRoutineIDs: Set<UUID> = []
    @State private var linkedHabitIDs: Set<UUID> = []
    @State private var showLinkedReminders = false
    @State private var showLinkedRoutines = false
    @State private var showLinkedHabits = false

    private var isEditing: Bool { step != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    stepSheetHeader

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {

                            // Preview
                            GlassCard {
                                Text(title.isEmpty ? "Your Step" : title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(title.isEmpty ? .white.opacity(0.3) : .white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Title
                            GlassCard {
                                TextField("Step title", text: $title)
                                    .foregroundStyle(.white)
                                    .textInputAutocapitalization(.sentences)
                            }

                            // Details
                            GlassCard {
                                ZStack(alignment: .topLeading) {
                                    if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Add details...")
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.35))
                                            .padding(.top, 8)
                                            .padding(.horizontal, 4)
                                    }
                                    TextEditor(text: $details)
                                        .foregroundStyle(.white)
                                        .scrollContentBackground(.hidden)
                                        .background(.clear)
                                        .frame(minHeight: 100)
                                }
                            }

                            // Status
                            GlassCard {
                                HStack(spacing: 8) {
                                    ForEach(LureliaJourneyStepStatus.allCases, id: \.self) { s in
                                        statusPill(s)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Target date
                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle(isOn: $hasTargetDate) {
                                        Text("Target Date")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    .tint(LColors.gradientPurple)

                                    if hasTargetDate {
                                        DatePicker(
                                            "Date",
                                            selection: $targetDate,
                                            displayedComponents: .date
                                        )
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .tint(LColors.gradientBlue)
                                    }
                                }
                            }

                            // Linked reminders
                            linkedRemindersCard

                            // Linked routines
                            linkedRoutinesCard

                            // Linked habits
                            linkedHabitsCard
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { loadIfEditing() }
        }
    }

    // MARK: - Header

    private var stepSheetHeader: some View {
        HStack(spacing: 12) {
            Text(isEditing ? "Edit Step" : "New Step")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()
            
            Button { dismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

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

    // MARK: - Status Pill

    @ViewBuilder
    private func statusPill(_ s: LureliaJourneyStepStatus) -> some View {
        let isSelected = status == s
        Button {
            status = s
        } label: {
            Text(s.displayName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? LColors.bg : .white.opacity(0.7))
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

    // MARK: - Linked Reminders

    private var linkedRemindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showLinkedReminders.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LINKED REMINDERS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            Text("\(linkedReminderIDs.count) selected")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LGradients.header)
                        }

                        Spacer()

                        Image("chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(showLinkedReminders ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showLinkedReminders {
                    if reminders.isEmpty {
                        Text("No reminders available.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(reminders) { reminder in
                                linkRow(
                                    icon: reminder.icon.isEmpty ? "bellfill" : reminder.icon,
                                    title: reminder.title,
                                    subtitle: (reminder.nextFireAt ?? reminder.scheduledDate).formatted(date: .abbreviated, time: .shortened),
                                    isSelected: linkedReminderIDs.contains(reminder.id)
                                ) {
                                    if linkedReminderIDs.contains(reminder.id) {
                                        linkedReminderIDs.remove(reminder.id)
                                    } else {
                                        linkedReminderIDs.insert(reminder.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Linked Habits

    private var linkedHabitsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showLinkedHabits.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LINKED HABITS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            Text("\(linkedHabitIDs.count) selected")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LGradients.header)
                        }

                        Spacer()

                        Image("chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(showLinkedHabits ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showLinkedHabits {
                    if habits.isEmpty {
                        Text("No habits available.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(habits) { habit in
                                linkRow(
                                    icon: habit.iconName ?? "checkwavy",
                                    title: habit.title,
                                    subtitle: habitSubtitle(habit),
                                    isSelected: linkedHabitIDs.contains(habit.id)
                                ) {
                                    if linkedHabitIDs.contains(habit.id) {
                                        linkedHabitIDs.remove(habit.id)
                                    } else {
                                        linkedHabitIDs.insert(habit.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func habitSubtitle(_ habit: LureliaHabit) -> String {
        let details = habit.details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return details.isEmpty ? "Habit" : details
    }

    // MARK: - Linked Routines

    private var linkedRoutinesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showLinkedRoutines.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LINKED ROUTINES")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            Text("\(linkedRoutineIDs.count) selected")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LGradients.header)
                        }

                        Spacer()

                        Image("chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(showLinkedRoutines ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showLinkedRoutines {
                    if routines.isEmpty {
                        Text("No routines available.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(routines) { routine in
                                linkRow(
                                    icon: routine.icon,
                                    title: routine.name,
                                    subtitle: routine.timeOfDay.rawValue,
                                    isSelected: linkedRoutineIDs.contains(UUID(uuidString: routine.persistentID) ?? UUID())
                                ) {
                                    // Routines use persistentID (String) so we store as UUID via persistentID
                                    guard let rid = UUID(uuidString: routine.persistentID) else { return }
                                    if linkedRoutineIDs.contains(rid) {
                                        linkedRoutineIDs.remove(rid)
                                    } else {
                                        linkedRoutineIDs.insert(rid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Generic Link Row

    @ViewBuilder
    private func linkRow(
        icon: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(isSelected ? "checkwavy" : "addwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 18, height: 18)

                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard let step else { return }
        title = step.title
        details = step.details
        status = step.status
        if let td = step.targetDate {
            hasTargetDate = true
            targetDate = td
        }
        linkedReminderIDs = Set(step.linkedReminderIDs)
        linkedRoutineIDs = Set(step.linkedRoutineIDs)
        linkedHabitIDs = Set(step.linkedHabitIDs)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if let step {
            step.title = trimmedTitle
            step.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
            step.status = status
            if status == .completed && step.completedAt == nil {
                step.completedAt = Date()
            } else if status != .completed {
                step.completedAt = nil
            }
            step.targetDate = hasTargetDate ? targetDate : nil
            step.updatedAt = Date()
            step.linkedReminderIDs = Array(linkedReminderIDs)
            step.linkedRoutineIDs = Array(linkedRoutineIDs)
            step.linkedHabitIDs = Array(linkedHabitIDs)
            dismiss()
            return
        }

        let newStep = LureliaJourneyStep(
            title: trimmedTitle,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: milestone.steps?.count ?? 0
        )
        newStep.milestone = milestone
        newStep.status = status
        newStep.targetDate = hasTargetDate ? targetDate : nil
        newStep.linkedReminderIDs = Array(linkedReminderIDs)
        newStep.linkedRoutineIDs = Array(linkedRoutineIDs)
        newStep.linkedHabitIDs = Array(linkedHabitIDs)
        modelContext.insert(newStep)
        dismiss()
    }
}
