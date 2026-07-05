//
//  JourneyStepDetailView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct JourneyStepDetailView: View {

    @Bindable var step: LureliaJourneyStep
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LureliaReminder.scheduledDate)
    private var allReminders: [LureliaReminder]

    @Query(sort: \LureliaRoutine.sortOrder)
    private var allRoutines: [LureliaRoutine]

    @Query(sort: \LureliaHabit.title)
    private var allHabits: [LureliaHabit]

    @State private var showEditSheet = false
    @State private var showNoteSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                stepHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        overviewCard
                        linkedItemsCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
        }
        .fullScreenCover(isPresented: $showEditSheet) {
            if let milestone = step.milestone {
                LureliaNewJourneyStepSheet(milestone: milestone, step: step)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var stepHeader: some View {
        HStack {
            Text(step.title)
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
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            Button { showEditSheet = true } label: {
                Image("pencil")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 0)
        .padding(.bottom, 12)
    }

    // MARK: - Overview

    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        // Status pill
                        Text(step.status.displayName.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(LGradients.header)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(LGradients.header.opacity(0.13), in: Capsule())
                            .overlay(Capsule().strokeBorder(LGradients.header, lineWidth: 1))
                    }

                    Spacer()

                    // Completion toggle
                    Button { step.toggleCompletion() } label: {
                        ZStack {
                            Circle()
                                .fill(step.isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
                                .frame(width: 32, height: 32)

                            Circle()
                                .strokeBorder(
                                    step.isCompleted ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LGradients.header),
                                    lineWidth: 1.6
                                )
                                .frame(width: 32, height: 32)

                            if step.isCompleted {
                                Image("checkwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.white)
                                    .frame(width: 17, height: 17)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !step.details.isEmpty {
                    Divider().overlay(.white.opacity(0.1))

                    Text(step.details)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                if let targetDate = step.targetDate {
                    Divider().overlay(.white.opacity(0.1))

                    HStack(spacing: 6) {
                        Image("clockwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 14, height: 14)

                        Text(targetDate.formatted(date: .long, time: .omitted))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                if let completedAt = step.completedAt {
                    HStack(spacing: 6) {
                        Image("checkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.green)
                            .frame(width: 13, height: 13)

                        Text("Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green.opacity(0.85))
                    }
                }
            }
        }
    }

    // MARK: - Linked Items Card

    @ViewBuilder
    private var linkedItemsCard: some View {
        if hasLinkedItems {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LINKED ITEMS")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("Reminders, routines, and habits connected to this step.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    if !linkedReminders.isEmpty {
                        linkedSectionTitle("LINKED REMINDERS", count: linkedReminders.count)

                        VStack(spacing: 10) {
                            ForEach(linkedReminders) { reminder in
                                reminderRow(reminder)
                            }
                        }
                    }

                    if !linkedRoutines.isEmpty {
                        linkedDivider
                        linkedSectionTitle("LINKED ROUTINES", count: linkedRoutines.count)

                        VStack(spacing: 10) {
                            ForEach(linkedRoutines) { routine in
                                routineRow(routine)
                            }
                        }
                    }

                    if !linkedHabits.isEmpty {
                        linkedDivider
                        linkedSectionTitle("LINKED HABITS", count: linkedHabits.count)

                        VStack(spacing: 10) {
                            ForEach(linkedHabits) { habit in
                                habitRow(habit)
                            }
                        }
                    }
                }
            }
        }
    }

    private func linkedSectionTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))

            Text("\(count)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.12), in: Capsule())

            Spacer()
        }
    }

    private var linkedDivider: some View {
        Divider()
            .overlay(.white.opacity(0.1))
    }

    @ViewBuilder
    private func reminderRow(_ reminder: LureliaReminder) -> some View {
        linkedRowCard {
            HStack(spacing: 12) {
                linkedIconCircle(icon: reminder.icon.isEmpty ? "bellfill" : reminder.icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                    }

                    Text((reminder.nextFireAt ?? reminder.scheduledDate).formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LGradients.header)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func routineRow(_ routine: LureliaRoutine) -> some View {
        linkedRowCard {
            HStack(spacing: 12) {
                linkedIconCircle(icon: routine.icon, fill: Color(lureliaHex: routine.colorHex).opacity(0.2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(routine.timeOfDay.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LGradients.header)

                        if routine.scheduleEnabled {
                            Text("· \(routine.formattedStartTime)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    let taskCount = routine.tasks?.count ?? 0
                    Text("\(taskCount) task\(taskCount == 1 ? "" : "s") · \(routine.formattedDuration)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func habitRow(_ habit: LureliaHabit) -> some View {
        linkedRowCard {
            HStack(spacing: 12) {
                linkedIconCircle(icon: (habit.iconName ?? "repeatfill").isEmpty ? "repeatfill" : (habit.iconName ?? "repeatfill"))

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let details = habit.details, !details.isEmpty {
                        Text(details)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                    }

                    Text("\(habit.todaysCount)/\(habit.target) today")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LGradients.header)
                }

                Spacer()
            }
        }
    }

    private func linkedRowCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
    }

    private func linkedIconCircle(icon: String, fill: Color = .white.opacity(0.1)) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 40, height: 40)

            Circle()
                .strokeBorder(LGradients.header, lineWidth: 1)
                .frame(width: 40, height: 40)

            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
        }
    }

    // MARK: - Helpers

    private var hasLinkedItems: Bool {
        !linkedReminders.isEmpty || !linkedRoutines.isEmpty || !linkedHabits.isEmpty
    }

    private var linkedReminders: [LureliaReminder] {
        let ids = Set(step.linkedReminderIDs)
        guard !ids.isEmpty else { return [] }
        return allReminders
            .filter { ids.contains($0.id) }
            .sorted { ($0.nextFireAt ?? $0.scheduledDate) < ($1.nextFireAt ?? $1.scheduledDate) }
    }

    private var linkedRoutines: [LureliaRoutine] {
        let ids = Set(step.linkedRoutineIDs.map { $0.uuidString })
        guard !ids.isEmpty else { return [] }
        return allRoutines
            .filter { ids.contains($0.persistentID) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var linkedHabits: [LureliaHabit] {
        let ids = Set(step.linkedHabitIDs)
        guard !ids.isEmpty else { return [] }
        return allHabits
            .filter { ids.contains($0.id) }
            .sorted { $0.title < $1.title }
    }
}
