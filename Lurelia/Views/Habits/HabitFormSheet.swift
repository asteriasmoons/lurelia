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
    let onSaved: ((LureliaHabit) -> Void)?
    let onClose: () -> Void

    init(
        habit: LureliaHabit?,
        onSaved: ((LureliaHabit) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.habit = habit
        self.onSaved = onSaved
        self.onClose = onClose
    }

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

    /// User-selected habit color. In create mode this stays `nil` so the sheet
    /// uses the normal neutral glass aesthetic. In edit mode it is loaded from
    /// the habit's saved `colorHex` and drives the sheet's visual identity.
    @State private var selectedColor: Color? = nil

    /// The tint that in-sheet glass containers use.
    /// - Edit mode: the habit's saved color (once chosen)
    /// - New mode: nil, which lets `GlassCard` use the shared neutral surface
    private var formTint: Color? {
        selectedColor
    }

    // MARK: - Notification state

    @State private var notificationEnabled = false
    @State private var notifKind: LureliaHabitNotificationKind = .daily
    @State private var startDate: Date = Date()
    @State private var reminderTimes: [Date] = [Date()]
    @State private var intervalValue: Int = 1
    @State private var intervalValueText: String = "1"
    @State private var intervalWindowStart: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var intervalWindowEnd: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var alarmEnabled = false
    @State private var alarmDate = Date()
    @State private var alarmSoundName = LureliaReminderAlarmSound.defaultSound.fileName
    @State private var alarmFireTimes: Set<String> = []
    @State private var showAlarmConfig = false

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
    @State private var levels: [LureliaHabitLevel] = []
    @State private var habitRules: [String] = []
    @State private var habitObstacles: [String] = []
    @State private var habitSolutions: [String] = []
    @State private var immediateReward = ""
    @State private var longTermReward = ""

    // MARK: - Validation

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var useFullScreenCover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var currentHabitFireTimes: [String] {
        switch notifKind {
        case .daily:
            return uniqueTimes(reminderTimes.map { hhmm(from: $0) })
        case .everyXHours:
            return intervalFireTimes(intervalMinutes: max(1, intervalValue) * 60)
        case .everyXMinutes:
            return intervalFireTimes(intervalMinutes: max(1, intervalValue))
        }
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

                        formSection(label: "APPEARANCE") {
                            VStack(spacing: 10) {
                                LureliaHabitIconPickerButton(iconName: $iconName, tint: formTint) {
                                    showIconPicker = true
                                }

                                habitColorPickerRow
                            }
                        }

                        formSection(label: "DESCRIPTION") {
                            GlassCard(tint: formTint) {
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
                                tint: formTint,
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
                                daysPerWeek: daysPerWeek,
                                tint: formTint
                            )
                        }

                        formSection(label: "ALARM") {
                            habitAlarmSection
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
                            levels: $levels,
                            immediateReward: $immediateReward,
                            longTermReward: $longTermReward,
                            tint: formTint
                        )

                        // Archive (edit mode only)
                        if isEditing {
                            formSection(label: "ARCHIVE") {
                                GlassCard(tint: formTint) {
                                    Toggle(isOn: $isArchived) {
                                        Text("Archive this habit")
                                            .font(.system(size: 15, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    .tint(selectedColor ?? LColors.neutralPearl.opacity(0.72))
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
                        .foregroundStyle(canSave ? (selectedColor ?? LColors.textPrimary) : .white.opacity(0.25))
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { if isEditing { loadFromModel() } }
        .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
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
        .sheet(isPresented: Binding(
            get: { !useFullScreenCover && showAlarmConfig },
            set: { showAlarmConfig = $0 }
        )) {
            alarmConfigSheet
        }
        .fullScreenCover(isPresented: Binding(
            get: { useFullScreenCover && showAlarmConfig },
            set: { showAlarmConfig = $0 }
        )) {
            alarmConfigSheet
        }
    }

    // MARK: - Form helpers

    private var alarmConfigSheet: some View {
        LureliaReminderAlarmConfigSheet(
            alarmEnabled: $alarmEnabled,
            availableFireTimes: currentHabitFireTimes,
            selectedFireTimes: $alarmFireTimes,
            alarmSoundName: $alarmSoundName,
            fireTimesTitle: "Habit Times",
            fireTimeSubtitle: "Alarm at this habit time.",
            tint: formTint
        )
    }

    private var habitAlarmSection: some View {
        GlassCard(tint: formTint) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: alarmEnabledBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alarmEnabled ? "Alarm On" : "Alarm Off")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(alarmEnabled ? alarmSummaryText : "Use a system alarm for this habit.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                    }
                }
                .tint(selectedColor ?? LColors.neutralPearl.opacity(0.72))

                if alarmEnabled {
                    Button {
                        showAlarmConfig = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(selectedColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(LColors.neutralPearl.opacity(0.82)))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08), in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Alarm Settings")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(alarmSummaryText)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var alarmEnabledBinding: Binding<Bool> {
        Binding(
            get: { alarmEnabled },
            set: { newValue in
                alarmEnabled = newValue
                if newValue {
                    notificationEnabled = true
                    syncAlarmFireTimesToHabitTimes()
                    showAlarmConfig = true
                }
            }
        )
    }

    private var alarmSummaryText: String {
        let sound = LureliaReminderAlarmSound.sound(named: alarmSoundName).displayName
        let selectedCount = alarmFireTimes.intersection(Set(currentHabitFireTimes)).count
        let countText = selectedCount == 1 ? "1 time" : "\(selectedCount) times"
        return "\(countText) • \(sound)"
    }

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
        GlassCard(tint: formTint) {
            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Color Picker Row

    @ViewBuilder
    private var habitColorPickerRow: some View {
        GlassCard(tint: formTint) {
            HStack(spacing: 12) {
                Text("Habit Color")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                if selectedColor != nil {
                    Button {
                        selectedColor = nil
                    } label: {
                        Text("Reset")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }

                ColorPicker(
                    "Habit Color",
                    selection: colorPickerBinding,
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 32, height: 32)
            }
        }
    }

    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: { selectedColor ?? Color(lureliaHex: "#7d19f7") },
            set: { selectedColor = $0 }
        )
    }

    private func syncReminderTimes(to count: Int) {
        while reminderTimes.count < count { reminderTimes.append(reminderTimes.last ?? Date()) }
        if reminderTimes.count > count { reminderTimes = Array(reminderTimes.prefix(count)) }
    }

    private func syncAlarmFireTimesToHabitTimes() {
        let currentTimes = currentHabitFireTimes
        let currentSet = Set(currentTimes)
        alarmFireTimes = alarmFireTimes.intersection(currentSet)

        if alarmFireTimes.isEmpty, let firstTime = currentTimes.first {
            alarmFireTimes = [firstTime]
        }
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

        // Load the habit's saved user-selected color so the Edit sheet inherits
        // that individual habit's visual identity.
        let trimmedColorHex = habit.colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedColor = Color(lureliaHex: trimmedColorHex.isEmpty ? "#7d19f7" : trimmedColorHex)
        notificationEnabled = habit.reminderEnabled
        alarmEnabled = habit.alarmEnabled
        alarmDate = habit.alarmDate ?? Date()
        alarmSoundName = habit.alarmSoundName ?? LureliaReminderAlarmSound.defaultSound.fileName
        alarmFireTimes = Set(habit.alarmFireTimes)

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
        levels = habit.levels
        immediateReward = habit.immediateReward ?? ""
        longTermReward = habit.longTermReward ?? ""

        // Notification times
        let parsedTimes = habit.timesOfDay.compactMap { dateFromHHMM($0) }
        reminderTimes = parsedTimes.isEmpty ? [Date()] : parsedTimes

        if !habit.reminderEnabled {
            notifKind = .daily
            if alarmEnabled && alarmFireTimes.isEmpty {
                syncAlarmFireTimesToHabitTimes()
            }
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

        if alarmEnabled && alarmFireTimes.isEmpty {
            syncAlarmFireTimesToHabitTimes()
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
        // Persist the user-selected color. Fall back to the existing value (or
        // the model default) if the user didn't touch the picker, so we never
        // clobber an existing habit's color with a blank.
        if let picked = selectedColor, let hex = picked.toHex() {
            target.colorHex = hex
        }
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
        target.levels = levels
        target.immediateReward = immediateReward.isEmpty ? nil : immediateReward
        target.longTermReward = longTermReward.isEmpty ? nil : longTermReward

        // Insert if new
        if habit == nil {
            modelContext.insert(target)
        }

        let selectedAlarmTimes = normalizedSelectedAlarmTimes()
        let shouldEnableAlarm = alarmEnabled && !isArchived
        let shouldScheduleHabitTimes = notificationEnabled || shouldEnableAlarm

        // Notifications
        if shouldScheduleHabitTimes {
            applyNotificationSettings(to: target)
        } else {
            target.reminderEnabled = false
            target.timesOfDay = []
            target.reminderDaysOfWeek = []
        }

        target.alarmEnabled = shouldEnableAlarm
        target.alarmDate = shouldEnableAlarm ? alarmDateForSelectedTimes(selectedAlarmTimes) : nil
        target.alarmSoundName = shouldEnableAlarm ? alarmSoundName : nil
        target.alarmFireTimes = shouldEnableAlarm ? selectedAlarmTimes : []
        target.keepAlarmIdentifiers(for: shouldEnableAlarm ? selectedAlarmTimes : [])
        if shouldEnableAlarm && target.alarmID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            target.alarmID = UUID().uuidString
        }

        if shouldScheduleHabitTimes {
            HabitManager.shared.schedule(target)
        } else {
            HabitManager.shared.cancel(target)
        }

        LureliaWidgetReloads.reloadAll()
        onSaved?(target)
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

    private func uniqueTimes(_ times: [String]) -> [String] {
        Array(
            Set(times.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        )
        .filter { !$0.isEmpty }
        .sorted()
    }

    private func normalizedSelectedAlarmTimes() -> [String] {
        let availableTimes = currentHabitFireTimes
        let selectedAvailableTimes = availableTimes.filter { alarmFireTimes.contains($0) }

        if !selectedAvailableTimes.isEmpty {
            return selectedAvailableTimes
        }

        return alarmEnabled ? Array(availableTimes.prefix(1)) : []
    }

    private func alarmDateForSelectedTimes(_ selectedTimes: [String]) -> Date? {
        guard let firstTime = selectedTimes.first else { return nil }
        return dateFromHHMM(firstTime)
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
