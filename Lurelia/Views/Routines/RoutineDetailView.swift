//
//  RoutineDetailView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import WidgetKit
import UserNotifications

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    let routineID: PersistentIdentifier
    let refreshID: UUID

    @Query private var routines: [LureliaRoutine]

    private var routine: LureliaRoutine {
        guard let routine = routines.first else {
            fatalError("Routine not found")
        }
        return routine
    }

    init(
        routineID: PersistentIdentifier,
        refreshID: UUID = UUID()
    ) {
        self.routineID = routineID
        self.refreshID = refreshID

        let descriptor = FetchDescriptor<LureliaRoutine>(
            predicate: #Predicate<LureliaRoutine> { routine in
                routine.id == routineID
            }
        )

        _routines = Query(descriptor)
    }
    
    @State private var showEdit = false
    @State private var activeRoutine: LureliaRoutine?
    @State private var showCompletionBanner = false
    @State private var bannerMessage = "Done!"
    @State private var editingTask: LureliaRoutineTask?
    @State private var editingPhase: LureliaRoutinePhase?
    @State private var didCheckNotificationPermission = false
    @State private var viewRefreshID = UUID()
    
    private var routineTint: Color {
        Color(lureliaHex: routine.colorHex)
    }
    
    private var activeRun: LureliaRoutineRun? {
        routine.activeRun
    }

    // MARK: - Schedule Status

    private enum RoutineScheduleStatus {
        case dueNow, soon, none
    }

    private var scheduleStatus: RoutineScheduleStatus {
        let calendar = Calendar.current
        let now = Date()
        let todayWeekday = calendar.component(.weekday, from: now)

        if routine.phasesEnabled {
            let todayPhases = (routine.phases ?? [])
                .filter { $0.scheduleEnabled && $0.scheduledDays.contains(todayWeekday) }
            guard !todayPhases.isEmpty else { return .none }

            let earliestStart = todayPhases
                .map { $0.startHour * 60 + $0.startMinute }
                .min() ?? 0
            let latestEnd = todayPhases
                .map { $0.endHour * 60 + $0.endMinute }
                .max() ?? 0

            let nowMins = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

            if nowMins >= earliestStart && nowMins <= latestEnd { return .dueNow }
            if nowMins > latestEnd && !routine.allTasksDone { return .dueNow }
            if nowMins < earliestStart { return .soon }
            return .none
        }

        guard routine.scheduleEnabled, routine.scheduledDays.contains(todayWeekday) else { return .none }

        let startMins = routine.startHour * 60 + routine.startMinute
        let endMins = startMins + routine.durationMinutes
        let nowMins = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        if nowMins >= startMins && nowMins <= endMins { return .dueNow }
        if nowMins > endMins && !routine.allTasksDone { return .dueNow }
        if nowMins < startMins { return .soon }
        return .none
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
        
        if routine.allTasksDone { return "Completed" }
        
        return routine.scheduleEnabled ? "Scheduled" : "Ready"
    }
    
    private var routineStatusIcon: String {
        if let activeRun {
            return activeRun.isPaused ? "pausewavy" : "playwavy"
        }
        
        if routine.allTasksDone { return "checkwavy" }
        
        return routine.scheduleEnabled ? "bellfill" : "sparkle"
    }
    
    private var adaptiveRoutineTextColor: Color {
        routineTint.isLightColor ? .black.opacity(0.88) : .white
    }
    
    private var adaptiveRoutineSecondaryTextColor: Color {
        routineTint.isLightColor ? .black.opacity(0.62) : .white.opacity(0.72)
    }
    
    private func requestNotificationPermissionIfNeeded() async {
        guard !didCheckNotificationPermission else { return }
        didCheckNotificationPermission = true

        guard routine.remindersEnabled else { return }

        let status = await LureliaNotificationManager.shared.currentPermissionStatus()

        guard status == .notDetermined else { return }

        _ = await LureliaNotificationManager.shared.requestPermission()
    }
    
    // MARK: - CRITICAL FIX
        private func forceContextRefresh() {
            // Tells SwiftData to instantly process mutations that occurred externally (like via Widget)
            modelContext.processPendingChanges()
            
            // Triggers SwiftUI to completely tear down and rebuild the view layout, forcing a data re-read
            viewRefreshID = UUID()
        }
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    customHeader

                    heroCard

                    if scheduleStatus != .none {
                        scheduleStatusBox
                    }

                    actionStrip
                    
                    statsGrid
                    
                    if !routine.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailSectionCard(title: "Purpose", icon: "sparkle") {
                            Text(routine.purpose)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(adaptiveRoutineTextColor)
                        }
                    }
                    
                    if !routine.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailSectionCard(title: "Description", icon: "starnote") {
                            Text(routine.descriptionText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(adaptiveRoutineTextColor)
                        }
                    }
                    
                    if routine.scheduleEnabled {
                        scheduledDaysCard
                        scheduleTimeCard
                    }
                    
                    if routine.phasesEnabled {
                        phasesFlowSection
                    } else {
                        taskFlowCard
                    }
                    
                    if !routine.principles.isEmpty {
                        principlesCard
                    }
                    
                    historyCard
                    
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
        .id(viewRefreshID) // Attached up top to bind root container redraws directly
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            AddRoutineView(editingRoutine: routine)
        }
        .sheet(item: $editingTask) { task in
            EditRoutineTaskSheet(
                task: task,
                routineTint: routineTint
            )
        }
        .sheet(item: $editingPhase) { phase in
            EditRoutinePhaseSheet(
                phase: phase,
                routineTint: routineTint
            )
        }
        .task {
            await requestNotificationPermissionIfNeeded()
        }
        .fullScreenCover(item: $activeRoutine) { routine in
            RoutineRunView(routine: routine)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                forceContextRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            forceContextRefresh()
        }
        .completionBanner(isShowing: showCompletionBanner, message: bannerMessage)
    }
    
    private func triggerBanner(_ message: String) {
        bannerMessage = message
        showCompletionBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCompletionBanner = false
        }
    }

    private func completeCurrentPhase() {
        let calendar = Calendar.current
        let now = Date()
        let todayWeekday = calendar.component(.weekday, from: now)

        let scheduledPhases = routine.sortedPhases
            .filter { $0.scheduleEnabled && $0.scheduledDays.contains(todayWeekday) }

        let currentPhase = scheduledPhases.first { phase in
            let startMins = phase.startHour * 60 + phase.startMinute
            let endMins = phase.endHour * 60 + phase.endMinute
            let nowMins = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            let isTimeRelevant = nowMins <= endMins || nowMins >= startMins
            let hasPendingTasks = routine.tasksForPhase(phase).contains { $0.isPending }
            return isTimeRelevant && hasPendingTasks
        } ?? scheduledPhases.first { phase in
            routine.tasksForPhase(phase).contains { $0.isPending }
        }

        guard let phase = currentPhase else {
            routine.completeRoutine()
            return
        }

        let phaseTasks = routine.tasksForPhase(phase)
        for task in phaseTasks where task.isPending {
            task.markCompleted()
            routine.updatedAt = Date()
            
            do {
                try modelContext.save()
                WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
            } catch {
                print("Failed saving manual routine task completion: \(error)")
            }
        }

        routine.updatedAt = Date()

        if routine.allTasksDone {
            routine.lastCompletedAt = Date()
        }
    }
}

// MARK: - Main Cards
extension RoutineDetailView {
    
    private var customHeader: some View {
        HStack(spacing: 12) {

            Text(routine.name)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(routineTint)
                .lineLimit(2)

            Spacer()

            Button {
                showEdit = true
            } label: {
                Image("settings")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(adaptiveRoutineTextColor)
                    .frame(width: 40, height: 40)
                    .background(routineTint, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            
            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(adaptiveRoutineTextColor)
                    .frame(width: 40, height: 40)
                    .background(routineTint, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }
    
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
                        .foregroundStyle(adaptiveRoutineTextColor)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(adaptiveRoutineTextColor)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        heroMetaLabel(
                            icon: routine.timeOfDay.icon,
                            text: routine.timeOfDay.rawValue,
                            color: routineTint
                        )
                        
                        Text("·")
                            .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                        
                        heroMetaLabel(
                            icon: routineStatusIcon,
                            text: routineStatusText,
                            color: adaptiveRoutineSecondaryTextColor
                        )
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                routineMiniPill(
                    icon: "starnote",
                    title: "\(displayTaskCount)",
                    subtitle: routine.phasesEnabled ? "Phase Tasks" : "Tasks"
                )

                routineMiniPill(
                    icon: "clockfill",
                    title: displayDurationText,
                    subtitle: "Length"
                )

                routineMiniPill(
                    icon: displayScheduleIcon,
                    title: displayScheduleText,
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
    
    private var scheduleStatusBox: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(scheduleStatus == .dueNow ? routineTint : .white.opacity(0.35))
                .frame(width: 8, height: 8)

            Text(scheduleStatus == .dueNow ? "DUE NOW" : "SOON")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(scheduleStatus == .dueNow ? routineTint : .white.opacity(0.65))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    scheduleStatus == .dueNow
                    ? routineTint.opacity(0.15)
                    : Color.white.opacity(0.06)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    scheduleStatus == .dueNow
                    ? routineTint.opacity(0.55)
                    : Color.white.opacity(0.14),
                    lineWidth: 1
                )
        }
    }

    private var actionStrip: some View {
        HStack(spacing: 12) {
            if let activeRun {
                if activeRun.isPaused {
                    primaryActionButton(
                        title: "Resume",
                        icon: "playwavy"
                    ) {
                        RoutineManager.shared.resumeRun(
                            run: activeRun,
                            routine: routine
                        )
                        activeRoutine = routine
                        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                    }
                } else {
                    primaryActionButton(
                        title: "Open Run",
                        icon: "playwavy"
                    ) {
                        activeRoutine = routine
                    }
                    
                    secondaryActionButton(
                        title: "Pause",
                        icon: "pausewavy"
                    ) {
                        RoutineManager.shared.pauseRun(
                            run: activeRun,
                            routine: routine
                        )
                        try? modelContext.save()
                        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                    }
                }
                
                secondaryActionButton(
                    title: "End",
                    icon: "stopwavy"
                ) {
                    RoutineManager.shared.finishRun(
                        run: activeRun,
                        routine: routine,
                        wasCompleted: false
                    )
                    try? modelContext.save()
                    WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                }
            } else if routine.allTasksDone {
                primaryActionButton(
                    title: "Reset Tasks",
                    icon: "arrow.counterclockwise"
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        routine.resetTaskStates()
                        try? modelContext.save()
                    }
                    triggerBanner("Tasks reset!")
                    WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                }
                
                secondaryActionButton(
                    title: "Run",
                    icon: "playwavy"
                ) {
                    let run = RoutineManager.shared.startRun(
                        for: routine,
                        context: modelContext
                    )
                    try? modelContext.save()
                    if run.isActive { activeRoutine = routine }
                    WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                }
            } else {
                primaryActionButton(
                    title: routine.phasesEnabled ? "Complete" : "Complete",
                    icon: "checkwavy"
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        if routine.phasesEnabled {
                            completeCurrentPhase()
                        } else {
                            routine.completeRoutine()
                        }
                        try? modelContext.save()
                        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                    }
                    triggerBanner(
                        routine.phasesEnabled
                        ? (routine.allTasksDone ? "Routine completed!" : "Phase completed!")
                        : "Routine completed!"
                    )
                    WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                }
                
                secondaryActionButton(
                    title: "Skip",
                    icon: "skipwavy"
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        routine.skipRoutine()
                        try? modelContext.save()
                    }
                    triggerBanner("Routine skipped")
                    WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                }
                
                secondaryActionButton(
                    title: "Run",
                    icon: "playwavy"
                ) {
                    let run = RoutineManager.shared.startRun(
                        for: routine,
                        context: modelContext
                    )
                    try? modelContext.save()
                    if run.isActive { activeRoutine = routine }
                    WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
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
            statCard(value: "\(totalRuns)", label: "Runs")
            
            VStack(spacing: 5) {
                RoutineTaskDottedProgressRing(
                    progress: routineTaskProgress,
                    size: 38,
                    dotCount: 18,
                    dotDiameter: 3,
                    trackColor: adaptiveRoutineTextColor.opacity(0.18),
                    progressColor: routineTint
                ) {
                    Text(routineTaskProgressPercentText)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(adaptiveRoutineTextColor)
                }

                Text("\(completedRoutineTaskCount)/\(totalRoutineTaskCount) Done")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(adaptiveRoutineSecondaryTextColor)
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
            
            statCard(value: String(format: "%.1f", averageTasksCompleted), label: "Avg Done")
        }
    }
    
    private var scheduledDaysCard: some View {
        detailSectionCard(title: "Scheduled Days", icon: "starcal") {
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
                                    .foregroundStyle(adaptiveRoutineTextColor)
                                Text("Routine is scheduled for this day")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        if index < routine.scheduledDays.count - 1 { divider }
                    }
                }
            }
        }
    }
    
    private var scheduleTimeCard: some View {
        detailSectionCard(title: "Schedule Time", icon: "clockfill") {
            VStack(spacing: 12) {
                detailRow(icon: "sun", label: "Starts", value: routine.formattedStartTime)
                divider
                detailRow(icon: "moonzs", label: "Ends", value: routine.formattedEndTime)
                divider
                detailRow(icon: "hourglass", label: "Duration", value: "\(routine.durationMinutes) minutes")
            }
        }
    }
    
    private var taskFlowCard: some View {
        detailSectionCard(title: "Routine Flow", icon: "starnote") {
            if routine.sortedTasks.isEmpty {
                emptySectionText("No tasks have been added to this routine yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(routine.sortedTasks.enumerated()), id: \.element.id) { index, task in
                        taskRow(task: task)
                        if index < routine.sortedTasks.count - 1 { divider }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Reusable Task Row
    
    @ViewBuilder
    private func taskRow(task: LureliaRoutineTask) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                Circle()
                    .strokeBorder(routineTint.opacity(0.8), lineWidth: 1)
                    .frame(width: 34, height: 34)
                LureliaIconView(iconId: task.icon, size: 15)
                    .foregroundStyle(task.isPending ? routineTint : adaptiveRoutineSecondaryTextColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(task.isPending ? adaptiveRoutineTextColor : adaptiveRoutineSecondaryTextColor)
                    .strikethrough(!task.isPending, color: adaptiveRoutineSecondaryTextColor)
                
                let cleanedNotes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedNotes.isEmpty {
                    Text(cleanedNotes)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if task.isSkipped {
                    HStack(spacing: 5) {
                        Image("skipwavy").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 11, height: 11)
                        Text("Skipped").font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        if task.isCompleted { task.resetState() } else { task.markCompleted() }
                        try? modelContext.save()
                        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                    }
                } label: {
                    ZStack {
                        Circle().fill(task.isCompleted ? routineTint.opacity(0.18) : Color.clear)
                        Circle().strokeBorder(
                            task.isSkipped ? adaptiveRoutineSecondaryTextColor : routineTint.opacity(0.75),
                            lineWidth: 1.5
                        )
                        if task.isCompleted {
                            Image("checkwavy").renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 10, height: 10).foregroundStyle(routineTint)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                
                if task.isPending {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            task.markSkipped(); try? modelContext.save()
                            WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                        }
                    } label: {
                        Image("skipwavy").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                            .frame(width: 28, height: 28)
                            .background(LColors.glassSurface2, in: Circle())
                            .overlay(Circle().strokeBorder(LColors.glassBorder.opacity(0.75), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else if task.isSkipped {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            task.resetState(); try? modelContext.save()
                            WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                        }
                    } label: {
                        Image("repeatfill").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                            .frame(width: 28, height: 28)
                            .background(LColors.glassSurface2, in: Circle())
                            .overlay(Circle().strokeBorder(LColors.glassBorder.opacity(0.75), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editingTask = task
            } label: {
                Label { Text("Edit") } icon: { Image("settings").renderingMode(.template) }
            }
        }
    }

    // MARK: - Phases Flow Section
    
    private var phasesFlowSection: some View {
        VStack(spacing: 16) {
            ForEach(routine.sortedPhases) { phase in
                detailSectionCard(
                    title: phase.name.isEmpty ? "Phase" : phase.name,
                    icon: phase.icon
                ) {
                    VStack(spacing: 0) {
                        // Phase schedule if enabled
                        if phase.scheduleEnabled && !phase.scheduledDays.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    ForEach(phase.scheduledDays.sorted(), id: \.self) { weekday in
                                        ZStack {
                                            Circle()
                                                .fill(routineTint.opacity(0.18))
                                                .frame(width: 28, height: 28)
                                            Circle()
                                                .strokeBorder(routineTint.opacity(0.6), lineWidth: 1)
                                                .frame(width: 28, height: 28)
                                            Text(shortWeekdayLabel(for: weekday))
                                                .font(.system(size: 9, weight: .black, design: .rounded))
                                                .foregroundStyle(adaptiveRoutineTextColor)
                                        }
                                    }
                                    Spacer()

                                    HStack(spacing: 14) {
                                        Button {
                                            let run = RoutineManager.shared.startPhaseRun(
                                                for: routine,
                                                phase: phase,
                                                context: modelContext
                                            )

                                            try? modelContext.save()

                                            if run.isActive {
                                                activeRoutine = routine
                                                WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
                                            }
                                        } label: {
                                            Image("playwavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                                .foregroundStyle(routineTint)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            editingPhase = phase
                                        } label: {
                                            Image("pencil")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 17, height: 17)
                                                .foregroundStyle(routineTint)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                HStack(spacing: 8) {
                                    HStack(spacing: 5) {
                                        Image("clockfill").renderingMode(.template).resizable().scaledToFit()
                                            .frame(width: 11, height: 11).foregroundStyle(routineTint)
                                        Text(phase.formattedTimeRange)
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(routineTint.opacity(0.18), in: Capsule())
                                    .overlay(Capsule().strokeBorder(routineTint.opacity(0.45), lineWidth: 1))
                                    
                                    HStack(spacing: 5) {
                                        Image("hourglassfill").renderingMode(.template).resizable().scaledToFit()
                                            .frame(width: 11, height: 11).foregroundStyle(routineTint)
                                        Text(phaseDurationText(for: phase))
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(routineTint.opacity(0.18), in: Capsule())
                                    .overlay(Capsule().strokeBorder(routineTint.opacity(0.45), lineWidth: 1))
                                }
                            }
                            .padding(.bottom, 8)
                            Divider().overlay(LColors.glassBorder)
                                .padding(.bottom, 4)
                        }
                        
                        // Phase tasks
                        let phaseTasks = routine.tasksForPhase(phase)
                        if phaseTasks.isEmpty {
                            emptySectionText("No tasks in this phase.")
                        } else {
                            ForEach(Array(phaseTasks.enumerated()), id: \.element.id) { idx, task in
                                taskRow(task: task)
                                if idx < phaseTasks.count - 1 {
                                    Divider().overlay(LColors.glassBorder)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Principles Card
    
    private var principlesCard: some View {
        detailSectionCard(title: "Principles", icon: "sparkleprogress") {
            VStack(spacing: 12) {
                ForEach(routine.principles.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(routineTint.opacity(0.18))
                                .frame(width: 34, height: 34)
                            Circle()
                                .strokeBorder(routineTint.opacity(0.8), lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(adaptiveRoutineTextColor)
                        }
                        Text(routine.principles[index])
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(adaptiveRoutineTextColor)
                        Spacer()
                    }
                    if index < routine.principles.count - 1 {
                        Divider().overlay(LColors.glassBorder)
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
                            .contextMenu {
                                Button {
                                    deleteRunHistory(run)
                                } label: {
                                    Label {
                                        Text("Delete")
                                            .foregroundStyle(adaptiveRoutineTextColor)
                                    } icon: {
                                        Image("trash")
                                            .renderingMode(.template)
                                            .foregroundStyle(adaptiveRoutineTextColor)
                                    }
                                }
                            }
                        if index < min(sortedRuns.count, 10) - 1 { divider }
                    }
                }
            }
        }
    }
}

// MARK: - Components
extension RoutineDetailView {
    
    private func routineMiniPill(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Group {
                if UIImage(named: icon) != nil {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                }
            }
            .foregroundStyle(routineTint)
            .frame(width: 13, height: 13)

            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(adaptiveRoutineTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(subtitle)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
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
    
    private var displayTaskCount: Int {
        if routine.phasesEnabled {
            return routine.sortedPhases.reduce(0) { total, phase in
                total + routine.tasksForPhase(phase).count
            }
        }

        return (routine.tasks ?? []).count
    }
    
    private var totalRoutineTaskCount: Int {
        if routine.phasesEnabled {
            return routine.sortedPhases.reduce(0) { total, phase in
                total + routine.tasksForPhase(phase).count
            }
        }

        return routine.sortedTasks.count
    }

    private var completedRoutineTaskCount: Int {
        if routine.phasesEnabled {
            return routine.sortedPhases.reduce(0) { total, phase in
                total + routine.tasksForPhase(phase).filter { $0.isCompleted }.count
            }
        }

        return routine.sortedTasks.filter { $0.isCompleted }.count
    }

    private var routineTaskProgress: Double {
        guard totalRoutineTaskCount > 0 else { return 0 }
        return Double(completedRoutineTaskCount) / Double(totalRoutineTaskCount)
    }

    private var routineTaskProgressPercentText: String {
        "\(Int((routineTaskProgress * 100).rounded()))%"
    }

    private var displayDurationMinutes: Int {
        if routine.phasesEnabled {
            return routine.sortedPhases.reduce(0) { total, phase in
                total + phaseDurationMinutes(for: phase)
            }
        }

        return routine.durationMinutes
    }

    private var displayDurationText: String {
        let minutes = displayDurationMinutes
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(remainingMinutes)m"
    }

    private var displayScheduleIsOn: Bool {
        if routine.phasesEnabled {
            return routine.sortedPhases.contains { phase in
                phase.scheduleEnabled && !phase.scheduledDays.isEmpty
            }
        }

        return routine.scheduleEnabled
    }

    private var displayScheduleText: String {
        displayScheduleIsOn ? "On" : "Off"
    }

    private var displayScheduleIcon: String {
        displayScheduleIsOn ? "bellfill" : "bell.slash.fill"
    }

    private func phaseDurationMinutes(for phase: LureliaRoutinePhase) -> Int {
        let startMinutes = phase.startHour * 60 + phase.startMinute
        let endMinutes = phase.endHour * 60 + phase.endMinute
        let difference = endMinutes - startMinutes

        return max(
            1,
            difference > 0 ? difference : difference + 1440
        )
    }
    
    private func heroMetaLabel(
        icon: String,
        text: String,
        color: Color
    ) -> some View {
        HStack(spacing: 5) {
            Group {
                if UIImage(named: icon) != nil {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 12, height: 12)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
    }
    
    private func primaryActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        routineActionButton(
            title: title,
            icon: icon,
            isPrimary: true,
            action: action
        )
    }

    private func secondaryActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        routineActionButton(
            title: title,
            icon: icon,
            isPrimary: false,
            action: action
        )
    }
    
    private func routineActionButton(
        title: String,
        icon: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Group {
                    if UIImage(named: icon) != nil {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 17, height: 17)

                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(adaptiveRoutineTextColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isPrimary ? routineTint : LColors.glassSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isPrimary ? Color.clear : routineTint.opacity(0.18))
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isPrimary ? Color.white.opacity(0.14) : routineTint.opacity(0.45),
                        lineWidth: 1.05
                    )
            )
            .shadow(
                color: isPrimary ? routineTint.opacity(0.22) : Color.clear,
                radius: 14,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(adaptiveRoutineTextColor)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(adaptiveRoutineSecondaryTextColor)
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
    
    private func detailSectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Group {
                    if UIImage(named: icon) != nil {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .foregroundStyle(routineTint)
                .frame(width: 15, height: 15)
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(routineTint)
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
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Group {
                if UIImage(named: icon) != nil {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                }
            }
            .foregroundStyle(routineTint)
            .frame(width: 14, height: 14)
            .frame(width: 18)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(adaptiveRoutineSecondaryTextColor)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(adaptiveRoutineTextColor)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func runHistoryRow(_ run: LureliaRoutineRun) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(run.wasCompleted ? routineTint.opacity(0.24) : LColors.glassSurface2)
                    .frame(width: 34, height: 34)
                Image(run.wasCompleted ? "checkwavy" : "xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(run.wasCompleted ? routineTint : adaptiveRoutineSecondaryTextColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(run.startedAt, style: .date)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(adaptiveRoutineTextColor)
                Text("\(run.completedCount)/\(run.totalCount) tasks completed · \(run.skippedCount) skipped")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(adaptiveRoutineSecondaryTextColor)
            }
            Spacer()
            if let endedAt = run.endedAt {
                let minutes = Int(endedAt.timeIntervalSince(run.startedAt) / 60)
                Text("\(minutes)m")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(adaptiveRoutineSecondaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(routineTint.opacity(0.18), in: Capsule())
            }
        }
        .padding(.vertical, 10)
    }
    
    private func deleteRunHistory(_ run: LureliaRoutineRun) {
        modelContext.delete(run)
        routine.updatedAt = Date()
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
    }
    
    private func emptySectionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(adaptiveRoutineSecondaryTextColor)
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

private func phaseDurationText(for phase: LureliaRoutinePhase) -> String {
    let startMinutes = phase.startHour * 60 + phase.startMinute
    let endMinutes = phase.endHour * 60 + phase.endMinute
    let difference = endMinutes - startMinutes

    let totalMinutes = max(
        1,
        difference > 0 ? difference : difference + 1440
    )

    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    }

    if hours > 0 {
        return "\(hours)h"
    }

    return "\(minutes)m"
}

private struct EditRoutinePhaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var phase: LureliaRoutinePhase
    let routineTint: Color

    @State private var name: String
    @State private var selectedIcon: String
    @State private var scheduleEnabled: Bool
    @State private var selectedDays: Set<Int>
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var showIconPicker = false

    init(
        phase: LureliaRoutinePhase,
        routineTint: Color
    ) {
        self.phase = phase
        self.routineTint = routineTint

        _name = State(initialValue: phase.name)
        _selectedIcon = State(initialValue: phase.icon)
        _scheduleEnabled = State(initialValue: phase.scheduleEnabled)
        _selectedDays = State(initialValue: Set(phase.scheduledDays))
        _startHour = State(initialValue: phase.startHour)
        _startMinute = State(initialValue: phase.startMinute)
        _endHour = State(initialValue: phase.endHour)
        _endMinute = State(initialValue: phase.endMinute)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var adaptiveTextColor: Color {
        routineTint.isLightColor ? .black.opacity(0.88) : .white
    }

    private var adaptiveSecondaryTextColor: Color {
        routineTint.isLightColor ? .black.opacity(0.62) : .white.opacity(0.72)
    }

    private var sheetTextColor: Color { routineTint }
    private var sheetSecondaryTextColor: Color { routineTint.opacity(0.72) }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header
                        iconCard

                        fieldCard(title: "Phase Name") {
                            TextField("Phase name", text: $name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(sheetTextColor)
                        }

                        scheduleCard
                        timeCard
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Edit Phase")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(sheetTextColor)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(adaptiveTextColor)
                    .frame(width: 40, height: 40)
                    .background(routineTint, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var iconCard: some View {
        Button {
            showIconPicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Circle()
                        .strokeBorder(routineTint.opacity(0.85), lineWidth: 1)
                        .frame(width: 48, height: 48)

                    LureliaIconView(iconId: selectedIcon, size: 23)
                        .foregroundStyle(routineTint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Phase Icon")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(sheetTextColor)

                    Text("Tap to change the icon")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(sheetSecondaryTextColor)
                }

                Spacer()

                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(routineTint)
            }
            .padding(14)
            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(routineTint.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var scheduleCard: some View {
        fieldCard(title: "Schedule") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Scheduled Phase", isOn: $scheduleEnabled)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(sheetTextColor)
                    .tint(routineTint)

                if scheduleEnabled {
                    HStack(spacing: 7) {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                if selectedDays.contains(weekday) {
                                    selectedDays.remove(weekday)
                                } else {
                                    selectedDays.insert(weekday)
                                }
                            } label: {
                                Text(shortWeekdayLabel(for: weekday))
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        selectedDays.contains(weekday)
                                        ? sheetTextColor
                                        : sheetSecondaryTextColor
                                    )
                                    .frame(width: 32, height: 32)
                                    .background(
                                        selectedDays.contains(weekday)
                                        ? routineTint.opacity(0.28)
                                        : Color.white.opacity(0.06),
                                        in: Circle()
                                    )
                                    .overlay {
                                        Circle()
                                            .strokeBorder(
                                                selectedDays.contains(weekday)
                                                ? routineTint.opacity(0.85)
                                                : Color.white.opacity(0.14),
                                                lineWidth: 1
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var timeCard: some View {
        fieldCard(title: "Time") {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start time")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(sheetSecondaryTextColor)
                    LureliaTintedTimeDrumPicker(hour: $startHour, minute: $startMinute, tint: routineTint)
                }
                Divider().overlay(LColors.glassBorder)
                VStack(alignment: .leading, spacing: 6) {
                    Text("End time")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(sheetSecondaryTextColor)
                    LureliaTintedTimeDrumPicker(hour: $endHour, minute: $endMinute, tint: routineTint)
                }
            }
        }
    }

    private func fieldCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(sheetSecondaryTextColor)

            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(routineTint.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save Phase")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(canSave ? adaptiveTextColor : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canSave ? routineTint : Color.white.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func save() {
        phase.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        phase.icon = selectedIcon
        phase.scheduleEnabled = scheduleEnabled
        phase.scheduledDays = Array(selectedDays).sorted()
        phase.startHour = startHour
        phase.startMinute = startMinute
        phase.endHour = endHour
        phase.endMinute = endMinute
        phase.updatedAt = Date()

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
        dismiss()
    }

    private func shortWeekdayLabel(for weekday: Int) -> String {
        guard weekday >= 1 && weekday <= 7 else { return "--" }
        return Calendar.current.veryShortWeekdaySymbols[weekday - 1]
    }
}

private struct EditRoutineTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: LureliaRoutineTask
    let routineTint: Color

    @State private var title: String
    @State private var notes: String
    @State private var selectedIcon: String
    @State private var showIconPicker = false

    init(
        task: LureliaRoutineTask,
        routineTint: Color
    ) {
        self.task = task
        self.routineTint = routineTint

        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        _selectedIcon = State(initialValue: task.icon)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var adaptiveRoutineTextColor: Color {
        routineTint.isLightColor ? .black.opacity(0.88) : .white
    }
    
    private var adaptiveRoutineSecondaryTextColor: Color {
        routineTint.isLightColor ? .black.opacity(0.62) : .white.opacity(0.72)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header

                        iconCard

                        fieldCard(
                            title: "Task Name"
                        ) {
                            TextField("Task name", text: $title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(adaptiveRoutineTextColor)
                        }

                        fieldCard(
                            title: "Notes"
                        ) {
                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(adaptiveRoutineTextColor)
                        }

                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Edit Task")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(adaptiveRoutineTextColor)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(adaptiveRoutineTextColor)
                    .frame(width: 40, height: 40)
                    .background(routineTint, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var iconCard: some View {
        Button {
            showIconPicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Circle()
                        .strokeBorder(routineTint.opacity(0.85), lineWidth: 1)

                    LureliaIconView(iconId: selectedIcon, size: 23)
                        .foregroundStyle(routineTint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Task Icon")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(adaptiveRoutineTextColor)

                    Text("Tap to change the icon")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image("chevright")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(routineTint)
            }
            .padding(14)
            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(routineTint.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func fieldCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(routineTint.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save Task")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(canSave ? adaptiveRoutineTextColor : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canSave ? routineTint : Color.white.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func save() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        task.icon = selectedIcon
        task.updatedAt = Date()

        try? modelContext.save()
        dismiss()
        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRoutinesWidget")
    }
}

private struct RoutineTaskDottedProgressRing<CenterContent: View>: View {
    let progress: Double
    let size: CGFloat
    let dotCount: Int
    let dotDiameter: CGFloat
    let trackColor: Color
    let progressColor: Color
    let centerContent: () -> CenterContent

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var filledDotCount: Int {
        Int((clampedProgress * Double(dotCount)).rounded())
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(index < filledDotCount ? AnyShapeStyle(progressColor) : AnyShapeStyle(trackColor))
                    .frame(width: dotDiameter, height: dotDiameter)
                    .offset(y: -(size / 2))
                    .rotationEffect(.degrees(Double(index) / Double(dotCount) * 360))
            }

            centerContent()
        }
        .frame(width: size, height: size)
    }
}
