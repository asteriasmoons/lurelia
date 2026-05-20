//
//  RoutineDetailView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var routine: LureliaRoutine
    
    @State private var showEdit = false
    @State private var activeRoutine: LureliaRoutine?
    
    private var routineTint: Color {
        Color(lureliaHex: routine.colorHex)
    }
    
    private var activeRun: LureliaRoutineRun? {
        routine.activeRun
    }
    
    private var sortedRuns: [LureliaRoutineRun] {
        (routine.runs ?? [])
            .filter { !$0.isActive }
            .sorted { $0.startedAt > $1.startedAt }
    }
    
    private var totalRuns: Int {
        sortedRuns.count
    }
    
    private var completedRuns: Int {
        sortedRuns.filter { $0.wasCompleted }.count
    }
    
    private var completionRate: Double {
        guard totalRuns > 0 else { return 0 }
        return Double(completedRuns) / Double(totalRuns)
    }
    
    private var averageTasksCompleted: Double {
        guard totalRuns > 0 else { return 0 }
        
        let totalCompleted = sortedRuns.reduce(0) {
            $0 + $1.completedCount
        }
        
        return Double(totalCompleted) / Double(totalRuns)
    }
    
    private var scheduleLabel: String {
        guard routine.scheduleEnabled && !routine.scheduledDays.isEmpty else {
            return "No schedule set"
        }
        
        let symbols = Calendar.current.shortWeekdaySymbols
        
        let days = routine.scheduledDays
            .sorted()
            .compactMap { $0 >= 1 && $0 <= 7 ? symbols[$0 - 1] : nil }
            .joined(separator: ", ")
        
        return "\(days) · \(routine.formattedTimeRange)"
    }
    
    private var routineStatusText: String {
        if let activeRun {
            return activeRun.isPaused ? "Paused" : "Running"
        }
        
        return routine.scheduleEnabled ? "Scheduled" : "Ready"
    }
    
    private var routineStatusIcon: String {
        if let activeRun {
            return activeRun.isPaused ? "pause.fill" : "play.fill"
        }
        
        return routine.scheduleEnabled ? "bell.fill" : "sparkles"
    }
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    
                    actionStrip
                    
                    statsGrid
                    
                    if routine.scheduleEnabled {
                        scheduledDaysCard
                        scheduleTimeCard
                    }
                    
                    taskFlowCard
                    
                    historyCard
                    
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image("slider")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(routineTint, in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showEdit) {
            AddRoutineView(editingRoutine: routine)
        }
        .fullScreenCover(item: $activeRoutine) { routine in
            RoutineRunView(routine: routine)
        }
    }
}

// MARK: - Main Cards

extension RoutineDetailView {
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(routineTint.opacity(0.18))
                        .frame(width: 78, height: 78)
                        .overlay(
                            Circle()
                                .strokeBorder(LColors.glassBorderStrong, lineWidth: 1)
                        )
                    
                    Circle()
                        .fill(routineTint.opacity(0.24))
                        .frame(width: 54, height: 54)
                        .blur(radius: 16)
                    
                    LureliaIconView(iconId: routine.icon, size: 34)
                        .foregroundStyle(LColors.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label(routine.timeOfDay.rawValue, systemImage: routine.timeOfDay.icon)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(routineTint)
                        
                        Text("·")
                            .foregroundStyle(LColors.textSecondary.opacity(0.5))
                        
                        Label(routineStatusText, systemImage: routineStatusIcon)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                routineMiniPill(
                    icon: "checklist",
                    title: "\((routine.tasks ?? []).count)",
                    subtitle: "Tasks"
                )
                
                routineMiniPill(
                    icon: "clock.fill",
                    title: "\(routine.durationMinutes)m",
                    subtitle: "Length"
                )
                
                routineMiniPill(
                    icon: routine.scheduleEnabled ? "bell.fill" : "bell.slash.fill",
                    title: routine.scheduleEnabled ? "On" : "Off",
                    subtitle: "Schedule"
                )
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(routineTint.opacity(0.30))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(routineTint.opacity(0.55), lineWidth: 1.1)
                }
        }
        .shadow(color: routineTint.opacity(0.16), radius: 18, x: 0, y: 10)
    }
    
    private var actionStrip: some View {
        HStack(spacing: 12) {
            if let activeRun {
                if activeRun.isPaused {
                    primaryActionButton(
                        title: "Resume",
                        icon: "play.fill"
                    ) {
                        RoutineManager.shared.resumeRun(
                            run: activeRun,
                            routine: routine
                        )
                        
                        activeRoutine = routine
                    }
                } else {
                    primaryActionButton(
                        title: "Open Run",
                        icon: "play.fill"
                    ) {
                        activeRoutine = routine
                    }
                    
                    secondaryActionButton(
                        title: "Pause",
                        icon: "pause.fill"
                    ) {
                        RoutineManager.shared.pauseRun(
                            run: activeRun,
                            routine: routine
                        )
                        
                        try? modelContext.save()
                    }
                }
                
                secondaryActionButton(
                    title: "End",
                    icon: "stop.fill"
                ) {
                    RoutineManager.shared.finishRun(
                        run: activeRun,
                        routine: routine,
                        wasCompleted: false
                    )
                    
                    try? modelContext.save()
                }
            } else {
                primaryActionButton(
                    title: "Start Routine",
                    icon: "play.fill"
                ) {
                    let run = RoutineManager.shared.startRun(
                        for: routine,
                        context: modelContext
                    )
                    
                    try? modelContext.save()
                    
                    if run.isActive {
                        activeRoutine = routine
                    }
                }
            }
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 10
        ) {
            statCard(
                value: "\(totalRuns)",
                label: "Runs"
            )
            
            statCard(
                value: "\(Int(completionRate * 100))%",
                label: "Completed"
            )
            
            statCard(
                value: String(format: "%.1f", averageTasksCompleted),
                label: "Avg Done"
            )
        }
    }
    
    private var scheduledDaysCard: some View {
        detailSectionCard(title: "Scheduled Days", icon: "calendar") {
            if routine.scheduledDays.isEmpty {
                emptySectionText("No days selected for this routine yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(routine.scheduledDays.sorted().enumerated()), id: \.element) { index, weekday in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(routineTint.opacity(0.18))
                                    .frame(width: 34, height: 34)
                                
                                Text(shortWeekdayLabel(for: weekday))
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(routineTint)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fullWeekdayLabel(for: weekday))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                
                                Text("Routine is scheduled for this day")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.72))
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        
                        if index < routine.scheduledDays.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
    }
    
    private var scheduleTimeCard: some View {
        detailSectionCard(title: "Schedule Time", icon: "clock.fill") {
            VStack(spacing: 12) {
                detailRow(
                    icon: "sunrise.fill",
                    label: "Starts",
                    value: routine.formattedStartTime
                )
                
                divider
                
                detailRow(
                    icon: "moon.stars.fill",
                    label: "Ends",
                    value: routine.formattedEndTime
                )
                
                divider
                
                detailRow(
                    icon: "hourglass",
                    label: "Duration",
                    value: "\(routine.durationMinutes) minutes"
                )
            }
        }
    }
    
    private var taskFlowCard: some View {
        detailSectionCard(title: "Routine Flow", icon: "list.bullet.clipboard.fill") {
            if routine.sortedTasks.isEmpty {
                emptySectionText("No tasks have been added to this routine yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(routine.sortedTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(routineTint.opacity(0.18))
                                    .frame(width: 30, height: 30)
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(routineTint)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                
                                if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(task.notes)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            if task.isFromBank {
                                Image(systemName: "link")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.65))
                            }
                        }
                        .padding(.vertical, 11)
                        
                        if index < routine.sortedTasks.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
    }
    
    private var historyCard: some View {
        detailSectionCard(title: "Run History", icon: "clock.arrow.circlepath") {
            if sortedRuns.isEmpty {
                emptySectionText("No completed routine runs yet. Start this routine to begin building history.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedRuns.prefix(10).enumerated()), id: \.element.id) { index, run in
                        runHistoryRow(run)
                        
                        if index < min(sortedRuns.count, 10) - 1 {
                            divider
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Components

extension RoutineDetailView {
    
    private func routineMiniPill(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(routineTint)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LColors.glassSurface2)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(routineTint.opacity(0.22))
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(routineTint.opacity(0.50), lineWidth: 1.05)
        )
    }
    
    private func primaryActionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(routineTint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: routineTint.opacity(0.22), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }
    
    private func secondaryActionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(LColors.textPrimary.opacity(0.82))
            .frame(width: 62, height: 54)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(routineTint.opacity(0.18))
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(routineTint.opacity(0.45), lineWidth: 1.05)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statCard(
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(routineTint.opacity(0.22))
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(routineTint.opacity(0.50), lineWidth: 1.05)
        )
    }
    
    private func detailSectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(routineTint)
                
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                
                Spacer()
            }
            
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LColors.glassSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(routineTint.opacity(0.22))
                        }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(routineTint.opacity(0.50), lineWidth: 1.05)
                )
        }
    }
    
    private func detailRow(
        icon: String,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(routineTint)
                .frame(width: 18)
            
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func runHistoryRow(_ run: LureliaRoutineRun) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        run.wasCompleted
                        ? routineTint.opacity(0.24)
                        : LColors.glassSurface2
                    )
                    .frame(width: 34, height: 34)
                
                Image(systemName: run.wasCompleted ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        run.wasCompleted
                        ? routineTint
                        : LColors.textSecondary
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(run.startedAt, style: .date)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                
                Text("\(run.completedCount)/\(run.totalCount) tasks completed · \(run.skippedCount) skipped")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.75))
            }
            
            Spacer()
            
            if let endedAt = run.endedAt {
                let minutes = Int(endedAt.timeIntervalSince(run.startedAt) / 60)
                
                Text("\(minutes)m")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(routineTint.opacity(0.18), in: Capsule())
            }
        }
        .padding(.vertical, 10)
    }
    
    private func emptySectionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(LColors.textSecondary.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
    
    private func shortWeekdayLabel(for weekday: Int) -> String {
        guard weekday >= 1 && weekday <= 7 else { return "--" }
        return Calendar.current.veryShortWeekdaySymbols[weekday - 1]
    }
    
    private func fullWeekdayLabel(for weekday: Int) -> String {
        guard weekday >= 1 && weekday <= 7 else { return "Unknown Day" }
        return Calendar.current.weekdaySymbols[weekday - 1]
    }
    
    private var divider: some View {
        Divider()
            .overlay(LColors.glassBorder)
    }
}
