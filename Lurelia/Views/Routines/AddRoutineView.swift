//
//  AddRoutineView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

private let lureliaWeekdays: [(label: String, value: Int)] = [
    ("Su", 1), ("Mo", 2), ("Tu", 3), ("We", 4),
    ("Th", 5), ("Fr", 6), ("Sa", 7)
]

struct AddRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]
    
    @Query private var reminders: [LureliaReminder]
    
    var editingRoutine: LureliaRoutine? = nil
    var onCreated: ((LureliaRoutine) -> Void)? = nil
    
    @State private var name = ""
    @State private var timeOfDay: LureliaRoutineTimeOfDay = .morning
    @State private var selectedColor: Color = LColors.gradientPurple
    @State private var selectedIcon = "sparkle"
    @State private var showIconPicker = false
    
    @State private var scheduleEnabled = false
    @State private var selectedDays: Set<Int> = []
    @State private var startHour = 8
    @State private var startMinute = 0
    @State private var endHour = 8
    @State private var endMinute = 30
    @State private var durationMode = false
    @State private var durationMinutesOverride = 30
    
    @State private var routineTasks: [LureliaRoutineTaskDraft] = []
    @State private var showAddCustomTask = false
    @State private var showTaskPicker = false
    
    private var isEditing: Bool {
        editingRoutine != nil
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        field("Routine Name") {
                            TextField("e.g. Morning Reset", text: $name)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        field("Time of Day") {
                            HStack(spacing: 8) {
                                ForEach(LureliaRoutineTimeOfDay.allCases, id: \.self) { tod in
                                    let isSelected = timeOfDay == tod
                                    
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            timeOfDay = tod
                                        }
                                    } label: {
                                        Text(tod.rawValue)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isSelected ? .white : LColors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(
                                                isSelected
                                                ? AnyShapeStyle(LGradients.header)
                                                : AnyShapeStyle(LColors.glassSurface),
                                                in: RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                                    .strokeBorder(
                                                        isSelected ? LColors.glassBorderStrong : LColors.glassBorder,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        field("Color") {
                            HStack(spacing: 14) {
                                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 44, height: 44)
                                
                                Text("Tap to pick a color")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                
                                Spacer()
                                
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(LColors.glassBorderStrong, lineWidth: 1)
                                    )
                            }
                        }
                        
                        field("Icon") {
                            Button {
                                showIconPicker = true
                            } label: {
                                HStack(spacing: 14) {
                                    LureliaIconView(iconId: selectedIcon, size: 26)
                                        .foregroundStyle(LColors.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            LColors.glassSurface2,
                                            in: RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                        )
                                    
                                    Text("Choose icon")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        field("Schedule") {
                            VStack(spacing: 14) {
                                Toggle(isOn: $scheduleEnabled) {
                                    Text("Enable schedule")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .tint(LColors.gradientBlue)
                                
                                if scheduleEnabled {
                                    HStack(spacing: 6) {
                                        ForEach(lureliaWeekdays, id: \.value) { day in
                                            Button {
                                                if selectedDays.contains(day.value) {
                                                    selectedDays.remove(day.value)
                                                } else {
                                                    selectedDays.insert(day.value)
                                                }
                                            } label: {
                                                Text(day.label)
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundStyle(LColors.textPrimary)
                                                    .frame(width: 34, height: 34)
                                                    .background(
                                                        selectedDays.contains(day.value)
                                                        ? selectedColor.opacity(0.5)
                                                        : LColors.glassSurface,
                                                        in: Circle()
                                                    )
                                                    .overlay(
                                                        Circle()
                                                            .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    
                                    Divider()
                                        .overlay(LColors.glassBorder)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Start time")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                        
                                        LureliaGradientTimeDrumPicker(
                                            hour: $startHour,
                                            minute: $startMinute
                                        )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("End time")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                        
                                        LureliaGradientTimeDrumPicker(
                                            hour: $endHour,
                                            minute: $endMinute
                                        )
                                    }
                                    
                                    Divider()
                                        .overlay(LColors.glassBorder)
                                    
                                    Toggle(isOn: $durationMode) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Duration countdown")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                            Text("Count down from a set duration instead of end time")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                        }
                                    }
                                    .tint(LColors.gradientBlue)
                                    
                                    if durationMode {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Duration (minutes)")
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                            
                                            TextField("e.g. 45", value: $durationMinutesOverride, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 15, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        field("Tasks") {
                            VStack(spacing: 10) {
                                if !routineTasks.isEmpty {
                                    ForEach(routineTasks.indices, id: \.self) { index in
                                        HStack(spacing: 10) {
                                            Image(systemName: "line.3.horizontal")
                                                .font(.caption)
                                                .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                            
                                            Text(routineTasks[index].name)
                                                .font(.system(size: 14, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                            
                                            if routineTasks[index].isFromBank {
                                                Image(systemName: "link")
                                                    .font(.caption2)
                                                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                            }
                                            
                                            Spacer()
                                            
                                            Button {
                                                routineTasks.remove(at: index)
                                            } label: {
                                                Image("trash")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 13, height: 13)
                                                    .foregroundStyle(LColors.gradientCyan)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                        
                                        if index < routineTasks.count - 1 {
                                            Divider()
                                                .overlay(LColors.glassBorder)
                                        }
                                    }
                                    
                                    Divider()
                                        .overlay(LColors.glassBorder)
                                }
                                
                                HStack(spacing: 10) {
                                    Button {
                                        showTaskPicker = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.caption)
                                            
                                            Text("From bank")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundStyle(LColors.gradientBlue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            LColors.gradientBlue.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        showAddCustomTask = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image("addwavy")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 10, height: 10)
                                                .foregroundStyle(.white)
                                            
                                            Text("Custom")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundStyle(LColors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            LColors.glassSurface,
                                            in: RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(LColors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LColors.textPrimary)
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddCustomTask) {
                AddCustomRoutineTaskView { taskName in
                    routineTasks.append(
                        LureliaRoutineTaskDraft(
                            name: taskName,
                            isFromBank: false,
                            bankTaskID: nil
                        )
                    )
                }
            }
            .sheet(isPresented: $showIconPicker) {
                LureliaIconPickerView(selectedIcon: $selectedIcon)
            }
            .sheet(isPresented: $showTaskPicker) {
                LureliaRoutineTaskPickerView(existing: routineTasks) { picked in
                    for task in picked {
                        if !routineTasks.contains(where: { $0.bankTaskID == task.id }) {
                            routineTasks.append(
                                LureliaRoutineTaskDraft(
                                    name: task.title,
                                    isFromBank: true,
                                    bankTaskID: task.id
                                )
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            populate()
        }
    }
    
    // MARK: - Field
    
    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
            
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LColors.glassSurface,
                    in: RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.95),
                                    LColors.gradientPurple.opacity(0.95),
                                    Color.white.opacity(0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                )
        }
    }
    
    // MARK: - Populate
    
    private func populate() {
        guard let routine = editingRoutine else { return }
        
        name = routine.name
        selectedIcon = routine.icon
        timeOfDay = routine.timeOfDay
        selectedColor = Color(lureliaHex: routine.colorHex)
        scheduleEnabled = routine.scheduleEnabled
        selectedDays = Set(routine.scheduledDays)
        
        startHour = routine.startHour
        startMinute = routine.startMinute
        endHour = routine.endHour
        endMinute = routine.endMinute
        durationMode = routine.durationMode
        durationMinutesOverride = routine.durationMinutesOverride
        
        routineTasks = routine.sortedTasks.map {
            LureliaRoutineTaskDraft(
                name: $0.title,
                isFromBank: $0.isFromBank,
                bankTaskID: $0.bankTaskID
            )
        }
    }
    
    // MARK: - Save
    
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let routine: LureliaRoutine
        
        if let existing = editingRoutine {
            existing.name = trimmed
            existing.icon = selectedIcon
            existing.timeOfDay = timeOfDay
            existing.colorHex = selectedColor.toLureliaHex() ?? "#7d19f7"
            existing.scheduleEnabled = scheduleEnabled
            existing.scheduledDays = Array(selectedDays).sorted()
            existing.startHour = startHour
            existing.startMinute = startMinute
            existing.endHour = endHour
            existing.endMinute = endMinute
            existing.durationMode = durationMode
            existing.durationMinutesOverride = durationMinutesOverride
            existing.updatedAt = Date()
            
            (existing.tasks ?? []).forEach {
                modelContext.delete($0)
            }
            
            routine = existing
        } else {
            routine = LureliaRoutine(
                name: trimmed,
                icon: selectedIcon,
                timeOfDay: timeOfDay,
                colorHex: selectedColor.toLureliaHex() ?? "#7d19f7",
                scheduledDays: Array(selectedDays).sorted(),
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                scheduleEnabled: scheduleEnabled,
                sortOrder: routines.count,
                durationMode: durationMode,
                durationMinutesOverride: durationMinutesOverride
            )
            
            modelContext.insert(routine)
        }
        
        for (index, draft) in routineTasks.enumerated() {
            let task = LureliaRoutineTask(
                title: draft.name,
                notes: "",
                sortOrder: index,
                isFromBank: draft.isFromBank,
                bankTaskID: draft.bankTaskID
            )
            
            task.routine = routine
            modelContext.insert(task)
        }
        
        try? modelContext.save()
        let reminderSyncResult = syncReminder(for: routine)
        try? modelContext.save()
        if editingRoutine == nil { onCreated?(routine) }
        
        Task {
            switch reminderSyncResult {
            case .schedule(let reminder):
                await LureliaNotificationManager.shared.cancelReminder(reminder)
                await LureliaNotificationManager.shared.scheduleReminder(reminder)
            case .cancel(let reminder):
                await LureliaNotificationManager.shared.cancelReminder(reminder)
            case .none:
                break
            }
        }
        
        dismiss()
    }

    // MARK: - Reminder Sync
    
    private func syncReminder(for routine: LureliaRoutine) -> RoutineReminderSyncResult {
        let routineID = routine.persistentModelID.hashValue.description
        
        if !scheduleEnabled {
            guard let existingReminder = reminders.first(where: {
                $0.kind == .routine && $0.routinePersistentID == routineID
            }) else {
                return .none
            }

            existingReminder.isEnabled = false
            existingReminder.updatedAt = Date()
            return .cancel(existingReminder)
        }
        
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        components.hour = startHour
        components.minute = startMinute
        components.second = 0
        
        let scheduledDate = Calendar.current.date(from: components) ?? Date()
        
        let reminder: LureliaReminder
        
        if let existing = reminders.first(where: {
            $0.kind == .routine && $0.routinePersistentID == routineID
        }) {
            reminder = existing
        } else {
            reminder = LureliaReminder(
                title: routine.name,
                notes: "Routine start reminder",
                category: "Routines",
                kind: .routine,
                scheduledDate: scheduledDate,
                repeatUnit: selectedDays.isEmpty ? .none : .weeks,
                repeatInterval: 1
            )
            
            reminder.routinePersistentID = routineID
            modelContext.insert(reminder)
        }
        
        reminder.title = routine.name
        reminder.notes = "Routine start reminder"
        reminder.category = "Routines"
        reminder.kind = .routine
        reminder.routinePersistentID = routineID
        reminder.isEnabled = true
        reminder.scheduledDate = scheduledDate
        reminder.repeatUnit = selectedDays.isEmpty ? .none : .weeks
        reminder.repeatInterval = 1
        reminder.repeatWeekdays = Array(selectedDays).sorted()
        reminder.nextFireAt = scheduledDate
        reminder.updatedAt = Date()
        return .schedule(reminder)
    }
}

private enum RoutineReminderSyncResult {
    case schedule(LureliaReminder)
    case cancel(LureliaReminder)
    case none
}

// MARK: - Add Custom Routine Task Sheet

struct AddCustomRoutineTaskView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (String) -> Void
    
    @State private var taskName = ""
    @State private var notes = ""
    
    private var canAdd: Bool {
        !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Task Name")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                            
                            TextField("e.g. Wipe down surfaces", text: $taskName)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(14)
                                .background(
                                    LColors.glassSurface,
                                    in: RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes (optional)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                            
                            TextField("Any details...", text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(14)
                                .background(
                                    LColors.glassSurface,
                                    in: RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Custom Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(LColors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        
                        onAdd(trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LColors.textPrimary)
                    .disabled(!canAdd)
                }
            }
        }
    }
}

// MARK: - Routine Task Draft

struct LureliaRoutineTaskDraft: Identifiable {
    let id = UUID()
    var name: String
    var isFromBank: Bool
    var bankTaskID: String?
}

// MARK: - Task Picker Sheet

struct LureliaRoutineTaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let existing: [LureliaRoutineTaskDraft]
    let onConfirm: ([LureliaTaskBankItem]) -> Void
    
    @State private var selected: Set<String> = []
    @State private var searchText = ""
    
    private var filteredTasks: [LureliaTaskBankItem] {
        LureliaTaskBank.search(searchText)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        searchField
                        
                        ForEach(filteredTasks) { task in
                            let isSelected = selected.contains(task.id)
                            let alreadyAdded = existing.contains { $0.bankTaskID == task.id }
                            
                            Button {
                                if alreadyAdded { return }
                                
                                if isSelected {
                                    selected.remove(task.id)
                                } else {
                                    selected.insert(task.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(LColors.glassBorderStrong, lineWidth: 1.5)
                                            .frame(width: 22, height: 22)
                                        
                                        if isSelected || alreadyAdded {
                                            Circle()
                                                .fill(
                                                    alreadyAdded
                                                    ? LColors.glassSurface2
                                                    : LColors.gradientBlue
                                                )
                                                .frame(width: 13, height: 13)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title)
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundStyle(
                                                alreadyAdded
                                                ? LColors.textSecondary.opacity(0.55)
                                                : LColors.textPrimary
                                            )
                                        
                                        Text(task.category)
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary.opacity(0.65))
                                    }
                                    
                                    Spacer()
                                    
                                    if alreadyAdded {
                                        Text("Added")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary.opacity(0.65))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    LColors.glassSurface,
                                    in: RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                        .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Pick Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(LColors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selected.isEmpty ? "" : "(\(selected.count))")") {
                        let picked = LureliaTaskBank.allItems.filter {
                            selected.contains($0.id)
                        }
                        
                        onConfirm(picked)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LColors.textPrimary)
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textSecondary.opacity(0.7))
            
            TextField("Search task bank", text: $searchText)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LColors.glassSurface,
            in: RoundedRectangle(cornerRadius: LSpacing.cardRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                .strokeBorder(LColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Icon Picker

struct LureliaIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedIcon: String
    
    @State private var searchText = ""
    
    private var filteredIcons: [LureliaIconItem] {
        LureliaIconLibrary.search(searchText)
    }
    
    private var groupedIcons: [(category: String, icons: [LureliaIconItem])] {
        let grouped = Dictionary(grouping: filteredIcons) { $0.category }
        
        return grouped
            .map { (category: $0.key, icons: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category < $1.category }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary.opacity(0.7))
                            
                            TextField("Search icons", text: $searchText)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            LColors.glassSurface,
                            in: RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                        )
                        
                        ForEach(groupedIcons, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.category)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)
                                
                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(.flexible(), spacing: 10),
                                        count: 5
                                    ),
                                    spacing: 10
                                ) {
                                    ForEach(group.icons) { icon in
                                        Button {
                                            selectedIcon = icon.name
                                            dismiss()
                                        } label: {
                                            LureliaIconView(iconId: icon.name, size: 24)
                                                .foregroundStyle(
                                                    selectedIcon == icon.name
                                                    ? .white
                                                    : LColors.textPrimary.opacity(0.75)
                                                )
                                                .frame(width: 52, height: 52)
                                                .background(
                                                    selectedIcon == icon.name
                                                    ? AnyShapeStyle(LGradients.header)
                                                    : AnyShapeStyle(LColors.glassSurface),
                                                    in: RoundedRectangle(cornerRadius: 16)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .strokeBorder(
                                                            selectedIcon == icon.name
                                                            ? LColors.glassBorderStrong
                                                            : LColors.glassBorder,
                                                            lineWidth: 1
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(LColors.textPrimary)
                }
            }
        }
    }
}

// MARK: - Time Picker

struct LureliaTimeDrumPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    
    var body: some View {
        HStack(spacing: 10) {
            Picker("Hour", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .clipped()
            
            Text(":")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
            
            Picker("Minute", selection: $minute) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .clipped()
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    func toLureliaHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return nil
        }
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return String(
            format: "#%02X%02X%02X",
            r,
            g,
            b
        )
    }
}
