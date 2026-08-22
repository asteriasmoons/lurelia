//
//  JourneyTimelineView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct JourneyTimelineView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var journey: LureliaJourney

    @State private var selectedDate = Date()
    @State private var expandedStepIDs: Set<UUID> = []
    @State private var expandedMilestoneIDs: Set<UUID> = []

    @Query(sort: \LureliaReminder.scheduledDate)
    private var reminders: [LureliaReminder]

    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]

    @Query(sort: \LureliaHabit.createdAt)
    private var habits: [LureliaHabit]

    private var milestones: [LureliaJourneyMilestone] {
        (journey.milestones ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var timelineItems: [LureliaJourneyTimelineItem] {
        (journey.timelineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleDays: [Date] {
        let cal = Calendar.current
        let today = Date()
        return (-3...3).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    // MARK: - Filtering helpers

    private func milestoneHasActivity(_ milestone: LureliaJourneyMilestone) -> Bool {
        let cal = Calendar.current
        if let td = milestone.targetDate, cal.isDate(td, inSameDayAs: selectedDate) { return true }
        return (milestone.steps ?? []).contains { step in
            if let td = step.targetDate { return cal.isDate(td, inSameDayAs: selectedDate) }
            return false
        }
    }

    private func stepIsOnSelectedDate(_ step: LureliaJourneyStep) -> Bool {
        guard let td = step.targetDate else { return false }
        return Calendar.current.isDate(td, inSameDayAs: selectedDate)
    }

    private func timelineItemIsOnSelectedDate(_ item: LureliaJourneyTimelineItem) -> Bool {
        guard let sd = item.scheduledDate else { return false }
        return Calendar.current.isDate(sd, inSameDayAs: selectedDate)
    }

    private var hasAnyActivityOnSelectedDate: Bool {
        milestones.contains { milestoneHasActivity($0) }
        || timelineItems.contains { timelineItemIsOnSelectedDate($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            dayStrip

                            if hasAnyActivityOnSelectedDate {
                                HStack(spacing: 6) {
                                    Image("starcal")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(LGradients.header)
                                        .frame(width: 13, height: 13)

                                    Text("Items scheduled for \(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(LGradients.header)
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            journeyStartCard

                            ForEach(milestones) { milestone in
                                milestoneBlock(milestone)
                            }

                            if !timelineItems.isEmpty {
                                manualTimelineItems
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 120)
                        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedDate)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                normalizeMilestoneStatuses()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("Timeline")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

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
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Day Strip

    private var dayStrip: some View {
        HStack(spacing: 8) {
            ForEach(visibleDays, id: \.self) { day in
                dayButton(day)
            }
        }
        .padding(.bottom, 2)
    }

    private func dayButton(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)

        let hasActivity = milestones.contains { milestone in
            if let td = milestone.targetDate, cal.isDate(td, inSameDayAs: day) { return true }
            return (milestone.steps ?? []).contains { step in
                guard let td = step.targetDate else { return false }
                return cal.isDate(td, inSameDayAs: day)
            }
        } || timelineItems.contains {
            guard let sd = $0.scheduledDate else { return false }
            return cal.isDate(sd, inSameDayAs: day)
        }

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? LColors.bg : .white.opacity(0.55))

                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? LColors.bg : .white)

                Circle()
                    .fill(hasActivity ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(isToday ? 0.12 : 0.07)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isToday && !isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.10)),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Journey Start Card

    private var journeyStartCard: some View {
        timelineRow(
            icon: journey.iconName,
            title: journey.title,
            subtitle: journey.summary.isEmpty ? journey.vision : journey.summary,
            date: journey.createdAt,
            statusText: journey.status.rawValue.capitalized,
            isCompleted: journey.status == .completed,
            rowKind: .journey,
            isHighlighted: false
        )
    }

    // MARK: - Milestone Block

    private func milestoneBlock(_ milestone: LureliaJourneyMilestone) -> some View {
        let milestoneHighlighted: Bool = {
            guard let td = milestone.targetDate else { return false }
            return Calendar.current.isDate(td, inSameDayAs: selectedDate)
        }()

        return VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                JourneyMilestoneDetailView(milestone: milestone)
            } label: {
                timelineRow(
                    icon: "starfill",
                    title: milestone.title,
                    subtitle: milestone.details,
                    date: milestone.targetDate,
                    statusText: milestone.status.displayName,
                    isCompleted: milestone.status == .completed,
                    rowKind: .milestone(milestone, progress: milestoneProgress(milestone)),
                    isHighlighted: milestoneHighlighted
                )
            }
            .buttonStyle(.plain)

            if let reward = milestone.reward, !reward.isEmpty {
                rewardMiniRow(reward: reward)
                    .padding(.leading, 46)
            }

            let steps = (milestone.steps ?? []).sorted { $0.sortOrder < $1.sortOrder }

            ForEach(steps) { step in
                let stepHighlighted = stepIsOnSelectedDate(step)

                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        NavigationLink {
                            JourneyStepDetailView(step: step)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)

                        timelineRow(
                            icon: "checkwavy",
                            title: step.title,
                            subtitle: step.details,
                            date: step.targetDate,
                            statusText: step.status.displayName,
                            isCompleted: step.isCompleted,
                            isIndented: true,
                            rowKind: .step(step),
                            isHighlighted: stepHighlighted
                        )
                    }

                    linkedJourneyItemsRow(for: step)
                }
            }
        }
    }

    // MARK: - Manual Timeline Items

    private var manualTimelineItems: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIMELINE ITEMS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)

            ForEach(timelineItems) { item in
                timelineRow(
                    icon: iconForTimelineItem(item),
                    title: item.title,
                    subtitle: item.details,
                    date: item.scheduledDate ?? item.startTime,
                    statusText: item.itemType.rawValue.capitalized,
                    isCompleted: item.isCompleted,
                    rowKind: .item,
                    isHighlighted: timelineItemIsOnSelectedDate(item)
                )
            }
        }
    }

    // MARK: - Timeline Row

    private enum TimelineRowKind {
        case journey
        case milestone(LureliaJourneyMilestone, progress: Double)
        case step(LureliaJourneyStep)
        case item
    }

    private func timelineRow(
        icon: String,
        title: String,
        subtitle: String,
        date: Date?,
        statusText: String,
        isCompleted: Bool,
        isIndented: Bool = false,
        rowKind: TimelineRowKind = .item,
        isHighlighted: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {

            // Spine
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.10)))

                    Circle()
                        .strokeBorder(
                            isHighlighted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LGradients.header.opacity(0.6)),
                            lineWidth: isHighlighted ? 2 : 1.2
                        )

                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(isCompleted ? LColors.bg : .white)
                        .padding(8)
                }
                .frame(width: 34, height: 34)
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)

                Rectangle()
                    .fill(LGradients.header.opacity(0.35))
                    .frame(width: 2, height: 34)
                    .padding(.top, 4)
            }

            // Card
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {

                            Text(title)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .strikethrough(isCompleted, color: .white.opacity(0.85))
                                .lineLimit(2)

                            Spacer()

                            // Trailing accessories
                            HStack(spacing: 6) {
                            if case .milestone(_, let progress) = rowKind {
                                HStack(spacing: 3) {
                                    ForEach(0..<4, id: \.self) { index in
                                        Circle()
                                            .fill(progressDotFill(index: index, progress: progress))
                                            .frame(width: 5, height: 5)
                                    }
                                }
                            }

                                Text(statusText)
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(LGradients.header)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(LGradients.header.opacity(0.13), in: Capsule())
                                    .overlay { Capsule().strokeBorder(LGradients.header, lineWidth: 1) }

                            if canExpand(rowKind) {
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                        toggleExpanded(rowKind)
                                    }
                                } label: {
                                    Image("chevdown")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(LGradients.header)
                                        .frame(width: 14, height: 14)
                                        .rotationEffect(.degrees(isExpanded(rowKind) ? 180 : 0))
                                        .frame(width: 24, height: 24)
                                        .background(Color.white.opacity(0.07), in: Circle())
                                        .overlay {
                                            Circle()
                                                .strokeBorder(LGradients.header.opacity(0.65), lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }

                            // Completion toggle — trailing, inside card, steps only
                            if case .step(let step) = rowKind {
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                        step.toggleCompletion()
                                        normalizeMilestoneStatuses()
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(step.isCompleted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.clear))
                                            .frame(width: 20, height: 20)

                                        Circle()
                                            .strokeBorder(LGradients.header, lineWidth: 1.4)
                                            .frame(width: 20, height: 20)

                                        if step.isCompleted {
                                            Image("checkwavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(LColors.bg)
                                                .frame(width: 10, height: 10)
                                        }
                                    }
                                    .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                            .lineLimit(isExpanded(rowKind) ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isExpanded(rowKind))
                    }

                    if let date {
                        HStack(spacing: 4) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(isHighlighted ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(Color.white.opacity(0.55)))

                            if isHighlighted {
                                Text("· Today's Focus")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(LGradients.header)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(LGradients.header, lineWidth: 1.5)
                }
            }
        }
        .padding(.leading, isIndented ? 22 : 0)
    }

    // MARK: - Helpers
    
    private func canExpand(_ rowKind: TimelineRowKind) -> Bool {
        switch rowKind {
        case .milestone, .step:
            return true
        case .journey, .item:
            return false
        }
    }

    private func isExpanded(_ rowKind: TimelineRowKind) -> Bool {
        switch rowKind {
        case .milestone(let milestone, _):
            return expandedMilestoneIDs.contains(milestone.id)

        case .step(let step):
            return expandedStepIDs.contains(step.id)

        case .journey, .item:
            return false
        }
    }

    private func toggleExpanded(_ rowKind: TimelineRowKind) {
        switch rowKind {
        case .milestone(let milestone, _):
            if expandedMilestoneIDs.contains(milestone.id) {
                expandedMilestoneIDs.remove(milestone.id)
            } else {
                expandedMilestoneIDs.insert(milestone.id)
            }

        case .step(let step):
            if expandedStepIDs.contains(step.id) {
                expandedStepIDs.remove(step.id)
            } else {
                expandedStepIDs.insert(step.id)
            }

        case .journey, .item:
            break
        }
    }
    
    private func normalizeMilestoneStatuses() {
        for milestone in milestones {
            let steps = milestone.steps ?? []
            guard !steps.isEmpty else { continue }

            let completedCount = steps.filter { $0.isCompleted }.count

            if completedCount == steps.count, milestone.status != .completed {
                milestone.status = .completed
                milestone.updatedAt = Date()
            }
        }
    }

    private func progressDotFill(index: Int, progress: Double) -> AnyShapeStyle {
        let clampedProgress = max(0, min(progress, 1))
        let filledDots = clampedProgress <= 0
            ? 0
            : max(1, Int(floor(clampedProgress * 4)))

        return index < filledDots
            ? AnyShapeStyle(LGradients.header)
            : AnyShapeStyle(Color.white.opacity(0.16))
    }

    private func milestoneProgress(_ milestone: LureliaJourneyMilestone) -> Double {
        let steps = milestone.steps ?? []
        guard !steps.isEmpty else { return milestone.status == .completed ? 1 : 0 }
        let completed = steps.filter { $0.isCompleted }.count
        return Double(completed) / Double(steps.count)
    }

    private func iconForTimelineItem(_ item: LureliaJourneyTimelineItem) -> String {
        switch item.itemType {
        case .milestone: return "starfill"
        case .step:      return "checkwavy"
        case .reminder:  return "bellfill"
        case .routine:   return "wand"
        case .note:      return "pin"
        }
    }

    // MARK: - Linked Journey Items Row

    @ViewBuilder
    private func linkedJourneyItemsRow(for step: LureliaJourneyStep) -> some View {
        let linkedReminders = linkedReminders(for: step)
        let linkedRoutines = linkedRoutines(for: step)
        let linkedHabits = linkedHabits(for: step)

        if !linkedReminders.isEmpty || !linkedRoutines.isEmpty || !linkedHabits.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(linkedReminders) { reminder in
                    linkedMiniRow(
                        icon: reminder.icon.isEmpty ? "bellfill" : reminder.icon,
                        title: reminder.title,
                        subtitle: reminderTimeText(reminder)
                    )
                }

                ForEach(linkedRoutines, id: \.persistentID) { routine in
                    linkedMiniRow(
                        icon: routine.icon.isEmpty ? "wand" : routine.icon,
                        title: routine.name,
                        subtitle: routine.formattedTimeRange
                    )
                }

                ForEach(linkedHabits) { habit in
                    linkedMiniRow(
                        icon: (habit.iconName ?? "sparkle").isEmpty ? "sparkle" : (habit.iconName ?? "sparkle"),
                        title: habit.title,
                        subtitle: "\(habit.todaysCount)/\(habit.target) today"
                    )
                }
            }
            .padding(.leading, 68)
        }
    }

    private func linkedMiniRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 13, height: 13)
                .frame(width: 24, height: 24)
                .background(LGradients.header.opacity(0.16), in: Circle())
                .overlay { Circle().strokeBorder(LGradients.header, lineWidth: 1) }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LGradients.header.opacity(0.35), lineWidth: 1)
        }
    }

    private func rewardMiniRow(reward: String) -> some View {
        HStack(spacing: 8) {
            Image("trophystar")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 13, height: 13)
                .frame(width: 24, height: 24)
                .background(LColors.gradientPurple.opacity(0.16), in: Circle())
                .overlay { Circle().strokeBorder(LColors.gradientPurple.opacity(0.6), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 2) {
                Text("Reward")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(reward)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.gradientPurple)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(LColors.gradientPurple.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LColors.gradientPurple.opacity(0.35), lineWidth: 1)
        }
    }

    private func linkedReminders(for step: LureliaJourneyStep) -> [LureliaReminder] {
        let ids = Set(step.linkedReminderIDs)
        guard !ids.isEmpty else { return [] }
        return reminders
            .filter { ids.contains($0.id) }
            .sorted { ($0.nextFireAt ?? $0.scheduledDate) < ($1.nextFireAt ?? $1.scheduledDate) }
    }

    private func linkedRoutines(for step: LureliaJourneyStep) -> [LureliaRoutine] {
        let ids = Set(step.linkedRoutineIDs)
        guard !ids.isEmpty else { return [] }

        return routines
            .filter { routine in
                guard let uuid = UUID(uuidString: routine.persistentID) else { return false }
                return ids.contains(uuid)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func linkedHabits(for step: LureliaJourneyStep) -> [LureliaHabit] {
        let ids = Set(step.linkedHabitIDs)
        guard !ids.isEmpty else { return [] }

        return habits
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func reminderTimeText(_ reminder: LureliaReminder) -> String {
        (reminder.nextFireAt ?? reminder.scheduledDate).formatted(date: .omitted, time: .shortened)
    }
}
