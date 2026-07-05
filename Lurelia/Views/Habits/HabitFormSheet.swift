//
//  HabitFormSheet.swift
//  Lurelia
//
//  Unified Add / Edit habit sheet.
//  Pass `nil` for create mode, or an existing habit for edit mode.
//

import SwiftUI
import SwiftData
import WidgetKit

struct LureliaHabitFormSheet: View {
    @Environment(\.modelContext) private var modelContext

    /// `nil` = create mode, non-nil = edit mode
    let habit: LureliaHabit?
    let onClose: () -> Void

    private var isEditing: Bool { habit != nil }

    // MARK: - Core state

    @State private var title = ""
    @State private var details = ""
    @State private var daysPerWeek = 7
    @State private var activeWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var timesPerDay = 1
    @State private var iconName = "flame"
    @State private var showIconPicker = false
    @State private var isArchived = false

    // MARK: - Notification state

    @State private var notificationEnabled = false
    @State private var notifKind: LureliaHabitNotificationKind = .daily
    @State private var startDate: Date = Date()
    @State private var reminderTimes: [Date] = [Date()]
    @State private var intervalValue: Int = 1
    @State private var intervalValueText: String = "1"
    @State private var intervalWindowStart: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var intervalWindowEnd: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()

    // MARK: - Blueprint state

    @State private var identityStatement = ""
    @State private var habitPurpose = ""
    @State private var implementationIntention = ""
    @State private var selectedCueType: LureliaCueType? = nil
    @State private var cueDescription = ""
    @State private var cueReason = ""
    @State private var currentEnvironment = ""
    @State private var idealEnvironment = ""
    @State private var environmentChanges = ""
    @State private var temptationNeed = ""
    @State private var temptationWant = ""
    @State private var habitRules: [String] = []
    @State private var habitObstacles: [String] = []
    @State private var habitSolutions: [String] = []
    @State private var immediateReward = ""
    @State private var longTermReward = ""

    // MARK: - Validation

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        formSection(label: "TITLE") {
                            textField(placeholder: "Habit title", text: $title)
                        }

                        formSection(label: "ICON") {
                            LureliaHabitIconPickerButton(iconName: $iconName) {
                                showIconPicker = true
                            }
                        }

                        formSection(label: "DESCRIPTION") {
                            GlassCard {
                                ZStack(alignment: .topLeading) {
                                    if details.isEmpty {
                                        Text("Optional description")
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.25))
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                    }
                                    TextEditor(text: $details)
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(.white)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 60)
                                }
                            }
                        }

                        formSection(label: "SCHEDULE") {
                            HabitScheduleForm(
                                activeWeekdays: $activeWeekdays,
                                daysPerWeek: $daysPerWeek,
                                timesPerDay: $timesPerDay,
                                hideTimesPerDay: notificationEnabled && (notifKind == .everyXHours || notifKind == .everyXMinutes),
                                onTimesPerDayChange: { v in syncReminderTimes(to: v) }
                            )
                        }

                        formSection(label: "NOTIFICATION") {
                            HabitNotificationForm(
                                notificationEnabled: $notificationEnabled,
                                notifKind: $notifKind,
                                startDate: $startDate,
                                reminderTimes: $reminderTimes,
                                intervalValue: $intervalValue,
                                intervalValueText: $intervalValueText,
                                intervalWindowStart: $intervalWindowStart,
                                intervalWindowEnd: $intervalWindowEnd,
                                timesPerDay: timesPerDay,
                                iconName: iconName,
                                daysPerWeek: daysPerWeek
                            )
                        }

                        // MARK: - Blueprint

                        HabitBlueprintFormSection(
                            identityStatement: $identityStatement,
                            habitPurpose: $habitPurpose,
                            implementationIntention: $implementationIntention,
                            selectedCueType: $selectedCueType,
                            cueDescription: $cueDescription,
                            cueReason: $cueReason,
                            currentEnvironment: $currentEnvironment,
                            idealEnvironment: $idealEnvironment,
                            environmentChanges: $environmentChanges,
                            temptationNeed: $temptationNeed,
                            temptationWant: $temptationWant,
                            habitRules: $habitRules,
                            habitObstacles: $habitObstacles,
                            habitSolutions: $habitSolutions,
                            immediateReward: $immediateReward,
                            longTermReward: $longTermReward
                        )

                        // Archive (edit mode only)
                        if isEditing {
                            formSection(label: "ARCHIVE") {
                                GlassCard {
                                    Toggle(isOn: $isArchived) {
                                        Text("Archive this habit")
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    .tint(LColors.gradientPurple)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onClose() }
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Create") { commitHabit() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(canSave ? LColors.gradientBlue : .white.opacity(0.25))
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { if isEditing { loadFromModel() } }
        .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $iconName)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Form helpers

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.8)
            content()
        }
    }

    @ViewBuilder
    private func textField(placeholder: String, text: Binding<String>) -> some View {
        GlassCard {
            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func syncReminderTimes(to count: Int) {
        while reminderTimes.count < count { reminderTimes.append(reminderTimes.last ?? Date()) }
        if reminderTimes.count > count { reminderTimes = Array(reminderTimes.prefix(count)) }
    }

    // MARK: - Load (edit mode)

    private func loadFromModel() {
        guard let habit else { return }
        title = habit.title
        details = habit.details ?? ""
        daysPerWeek = habit.daysPerWeek
        activeWeekdays = Set(habit.activeWeekdays)
        daysPerWeek = activeWeekdays.count
        timesPerDay = habit.timesPerDay
        iconName = habit.iconName ?? "flame"
        isArchived = habit.isArchived
        notificationEnabled = habit.reminderEnabled

        // Blueprint
        identityStatement = habit.identityStatement ?? ""
        habitPurpose = habit.habitPurpose ?? ""
        implementationIntention = habit.implementationIntention ?? ""
        selectedCueType = habit.cueType
        cueDescription = habit.cueDescription ?? ""
        cueReason = habit.cueReason ?? ""
        currentEnvironment = habit.currentEnvironment ?? ""
        idealEnvironment = habit.idealEnvironment ?? ""
        environmentChanges = habit.environmentChanges ?? ""
        temptationNeed = habit.temptationNeed ?? ""
        temptationWant = habit.temptationWant ?? ""
        habitRules = habit.habitRules
        habitObstacles = habit.habitObstacles
        habitSolutions = habit.habitSolutions
        immediateReward = habit.immediateReward ?? ""
        longTermReward = habit.longTermReward ?? ""

        // Notification times
        let parsedTimes = habit.timesOfDay.compactMap { dateFromHHMM($0) }
        reminderTimes = parsedTimes.isEmpty ? [Date()] : parsedTimes

        if !habit.reminderEnabled {
            notifKind = .daily
            return
        }

        if let inferred = inferredIntervalSettings(from: habit.timesOfDay) {
            notifKind = inferred.kind
            intervalValue = inferred.value
            intervalValueText = "\(inferred.value)"
            intervalWindowStart = inferred.start
            intervalWindowEnd = inferred.end
        } else {
            notifKind = .daily
        }
    }

    // MARK: - Save / Apply

    private func commitHabit() {
        let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleTrimmed.isEmpty else { return }
        let detailsTrimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTimesPerDay = (notificationEnabled && (notifKind == .everyXHours || notifKind == .everyXMinutes))
            ? computedIntervalTimesPerDay() : timesPerDay

        let target: LureliaHabit
        if let existing = habit {
            target = existing
            HabitManager.shared.cancel(target)
        } else {
            target = LureliaHabit(
                title: titleTrimmed,
                details: detailsTrimmed.isEmpty ? nil : detailsTrimmed,
                iconName: iconName,
                daysPerWeek: daysPerWeek,
                timesPerDay: resolvedTimesPerDay
            )
        }

        // Core fields
        target.title = titleTrimmed
        target.details = detailsTrimmed.isEmpty ? nil : detailsTrimmed
        target.iconName = iconName
        target.activeWeekdays = Array(activeWeekdays).sorted()
        target.timesPerDay = resolvedTimesPerDay
        target.isArchived = isArchived
        target.updatedAt = Date()

        // Blueprint
        target.identityStatement = identityStatement.isEmpty ? nil : identityStatement
        target.habitPurpose = habitPurpose.isEmpty ? nil : habitPurpose
        target.implementationIntention = implementationIntention.isEmpty ? nil : implementationIntention
        target.cueType = selectedCueType
        target.cueDescription = cueDescription.isEmpty ? nil : cueDescription
        target.cueReason = cueReason.isEmpty ? nil : cueReason
        target.currentEnvironment = currentEnvironment.isEmpty ? nil : currentEnvironment
        target.idealEnvironment = idealEnvironment.isEmpty ? nil : idealEnvironment
        target.environmentChanges = environmentChanges.isEmpty ? nil : environmentChanges
        target.temptationNeed = temptationNeed.isEmpty ? nil : temptationNeed
        target.temptationWant = temptationWant.isEmpty ? nil : temptationWant
        target.habitRules = habitRules.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        target.habitObstacles = habitObstacles.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        target.habitSolutions = habitSolutions
        target.immediateReward = immediateReward.isEmpty ? nil : immediateReward
        target.longTermReward = longTermReward.isEmpty ? nil : longTermReward

        // Insert if new
        if habit == nil {
            modelContext.insert(target)
        }

        // Notifications
        if notificationEnabled {
            applyNotificationSettings(to: target)
            HabitManager.shared.schedule(target)
        } else {
            target.reminderEnabled = false
            target.timesOfDay = []
            target.reminderDaysOfWeek = []
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaHabitsWidget")
        onClose()
    }

    // MARK: - Notification helpers

    private func applyNotificationSettings(to habit: LureliaHabit) {
        habit.reminderEnabled = true
        switch notifKind {
        case .daily:
            habit.timesOfDay = reminderTimes.map { hhmm(from: $0) }
            habit.reminderDaysOfWeek = Array(activeWeekdays).sorted()
        case .everyXHours:
            habit.timesOfDay = intervalFireTimes(intervalMinutes: max(1, intervalValue) * 60)
            habit.reminderDaysOfWeek = Array(activeWeekdays).sorted()
        case .everyXMinutes:
            habit.timesOfDay = intervalFireTimes(intervalMinutes: max(1, intervalValue))
            habit.reminderDaysOfWeek = Array(activeWeekdays).sorted()
        }
    }

    private func hhmm(from date: Date) -> String {
        String(format: "%02d:%02d",
               Calendar.current.component(.hour, from: date),
               Calendar.current.component(.minute, from: date))
    }

    private func intervalFireTimes(intervalMinutes: Int) -> [String] {
        let cal = Calendar.current
        let startTotal = cal.component(.hour, from: intervalWindowStart) * 60 + cal.component(.minute, from: intervalWindowStart)
        let endTotal   = cal.component(.hour, from: intervalWindowEnd)   * 60 + cal.component(.minute, from: intervalWindowEnd)
        guard endTotal >= startTotal, intervalMinutes > 0 else { return [] }
        var times: [String] = []
        var cursor = startTotal
        while cursor <= endTotal {
            times.append(String(format: "%02d:%02d", cursor / 60, cursor % 60))
            cursor += intervalMinutes
        }
        return times
    }

    private func computedIntervalTimesPerDay() -> Int {
        let cal = Calendar.current
        let startTotal = cal.component(.hour, from: intervalWindowStart) * 60 + cal.component(.minute, from: intervalWindowStart)
        let endTotal   = cal.component(.hour, from: intervalWindowEnd)   * 60 + cal.component(.minute, from: intervalWindowEnd)
        let intervalMins = notifKind == .everyXHours ? max(1, intervalValue) * 60 : max(1, intervalValue)
        guard endTotal >= startTotal, intervalMins > 0 else { return 1 }
        return max(1, (endTotal - startTotal) / intervalMins + 1)
    }

    private func dateFromHHMM(_ value: String) -> Date? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private func inferredIntervalSettings(from values: [String]) -> (kind: LureliaHabitNotificationKind, value: Int, start: Date, end: Date)? {
        let dates = values.compactMap { dateFromHHMM($0) }.sorted()
        guard dates.count >= 2 else { return nil }

        let calendar = Calendar.current
        let minutes = dates.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
        let deltas = zip(minutes.dropFirst(), minutes).map { $0 - $1 }
        guard let firstDelta = deltas.first, firstDelta > 0, deltas.allSatisfy({ $0 == firstDelta }) else { return nil }

        let kind: LureliaHabitNotificationKind = firstDelta % 60 == 0 ? .everyXHours : .everyXMinutes
        let value = kind == .everyXHours ? firstDelta / 60 : firstDelta
        guard let start = dates.first, let end = dates.last else { return nil }
        return (kind, max(1, value), start, end)
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
