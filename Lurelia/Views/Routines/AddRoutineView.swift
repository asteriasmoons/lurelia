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

// MARK: - Phase Draft

struct LureliaRoutinePhaseDraft: Identifiable {
    let id = UUID()
    var name: String
    var icon: String = "sparkle"
    var tasks: [LureliaRoutineTaskDraft] = []
    var scheduleEnabled: Bool = false
    var scheduledDays: Set<Int> = []
    var startHour: Int = 8
    var startMinute: Int = 0
    var endHour: Int = 8
    var endMinute: Int = 30
    var durationMode: Bool = false
    var durationMinutesOverride: Int = 30
}

private struct PhaseTaskSheetTarget: Identifiable {
    enum Mode {
        case add
        case edit(taskIndex: Int)
    }

    let id = UUID()
    let phaseIndex: Int
    let mode: Mode
}

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
    
    // Enhanced fields
    @State private var purpose = ""
    @State private var descriptionText = ""
    @State private var principles: [String] = []
    @State private var newPrinciple = ""
    
    // Phases
    @State private var phasesEnabled = false
    @State private var phaseDrafts: [LureliaRoutinePhaseDraft] = []
    @State private var showAddPhase = false
    @State private var editingPhaseScheduleIndex: Int? = nil
    @State private var editingPhaseIconIndex: Int? = nil
    
    // Schedule (routine-level, hidden when phases enabled)
    @State private var reminderEnabled = false
    @State private var scheduleEnabled = false
    @State private var selectedDays: Set<Int> = []
    @State private var startHour = 8
    @State private var startMinute = 0
    @State private var endHour = 8
    @State private var endMinute = 30
    @State private var durationMode = false
    @State private var durationMinutesOverride = 30
    
    // Tasks (routine-level, hidden when phases enabled)
    @State private var routineTasks: [LureliaRoutineTaskDraft] = []
    @State private var showAddCustomTask = false
    @State private var editingRoutineTaskIndex: Int? = nil
    
    // Phase-level task add
    @State private var addingTaskForPhaseIndex: Int? = nil
    @State private var editingPhaseTaskIndices: (phase: Int, task: Int)? = nil
    @State private var phaseTaskSheetTarget: PhaseTaskSheetTarget? = nil
    
    private var isEditing: Bool { editingRoutine != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
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
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { timeOfDay = tod }
                                    } label: {
                                        Text(tod.rawValue)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isSelected ? .white : LColors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(
                                                isSelected ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LColors.glassSurface),
                                                in: RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                                    .strokeBorder(isSelected ? LColors.glassBorderStrong : LColors.glassBorder, lineWidth: 1)
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
                                    .overlay(Circle().strokeBorder(LColors.glassBorderStrong, lineWidth: 1))
                            }
                        }
                        
                        field("Icon") {
                            Button { showIconPicker = true } label: {
                                HStack(spacing: 14) {
                                    LureliaIconView(iconId: selectedIcon, size: 26)
                                        .foregroundStyle(LColors.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: LSpacing.inputRadius))
                                    Text("Choose icon")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                    Image("chevright")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 13, height: 13)
                                        .foregroundStyle(LColors.textSecondary.opacity(0.55))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // MARK: - Purpose
                        
                        field("Purpose") {
                            TextField("Why this routine exists...", text: $purpose, axis: .vertical)
                                .lineLimit(2, reservesSpace: true)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        // MARK: - Description
                        
                        field("Description") {
                            TextField("What this routine covers...", text: $descriptionText, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        // MARK: - Principles
                        
                        field("Principles") {
                            VStack(spacing: 10) {
                                ForEach(principles.indices, id: \.self) { index in
                                    HStack(spacing: 10) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                            .frame(width: 24)
                                        Text(principles[index])
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                        Spacer()
                                        Button { principles.remove(at: index) } label: {
                                            Image("trash").renderingMode(.template).resizable().scaledToFit()
                                                .frame(width: 13, height: 13).foregroundStyle(LColors.gradientCyan)
                                        }.buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                    if index < principles.count - 1 { Divider().overlay(LColors.glassBorder) }
                                }
                                if !principles.isEmpty { Divider().overlay(LColors.glassBorder) }
                                HStack(spacing: 10) {
                                    TextField("e.g. Progress over perfection", text: $newPrinciple)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    Button {
                                        let trimmed = newPrinciple.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmed.isEmpty else { return }
                                        principles.append(trimmed)
                                        newPrinciple = ""
                                    } label: {
                                        Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                                            .frame(width: 14, height: 14).foregroundStyle(LGradients.header)
                                            .frame(width: 32, height: 32)
                                            .background(LColors.glassSurface2, in: Circle())
                                            .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // MARK: - Phases Toggle
                        
                        field("Phases") {
                            Toggle(isOn: $phasesEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable phases")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    Text("Split this routine into named phases with their own tasks and schedules")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                            .tint(LColors.gradientBlue)
                        }
                        
                        // MARK: - Reminders
                        
                        field("Reminders") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $reminderEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enable reminders")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                        Text("Send reminders at the start, halfway point, and end of this routine")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                                .tint(LColors.gradientBlue)
                                
                                if reminderEnabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        reminderPreviewRow(title: "Start", time: formattedTime(hour: startHour, minute: startMinute))
                                        reminderPreviewRow(title: "Halfway", time: formattedTime(hour: halfwayReminderHour, minute: halfwayReminderMinute))
                                        reminderPreviewRow(title: "End", time: formattedTime(hour: endReminderHour, minute: endReminderMinute))
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Schedule (hidden when phases enabled)
                        
                        if !phasesEnabled {
                            field("Schedule") {
                                VStack(spacing: 14) {
                                    Toggle(isOn: $scheduleEnabled) {
                                        Text("Enable schedule")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                    }
                                    .tint(LColors.gradientBlue)
                                    
                                    if scheduleEnabled {
                                        scheduleContent(
                                            selectedDays: $selectedDays,
                                            startHour: $startHour,
                                            startMinute: $startMinute,
                                            endHour: $endHour,
                                            endMinute: $endMinute,
                                            durationMode: $durationMode,
                                            durationMinutesOverride: $durationMinutesOverride
                                        )
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Tasks (hidden when phases enabled)
                        
                        if !phasesEnabled {
                            field("Tasks") {
                                taskListContent(
                                    tasks: $routineTasks,
                                    onAdd: {
                                        addingTaskForPhaseIndex = nil
                                        editingRoutineTaskIndex = nil
                                        showAddCustomTask = true
                                    },
                                    onEdit: { index in
                                        addingTaskForPhaseIndex = nil
                                        editingRoutineTaskIndex = index
                                        showAddCustomTask = true
                                    }
                                )
                            }
                        }
                        
                        // MARK: - Phases (shown when phases enabled)
                        
                        if phasesEnabled {
                            ForEach(phaseDrafts.indices, id: \.self) { phaseIndex in
                                let phaseDraft = phaseDrafts[phaseIndex]
                                
                                // Use the phase name or fallback placeholder for the section header label
                                field(phaseDrafts[phaseIndex].name.isEmpty ? "Phase \(phaseIndex + 1)" : phaseDrafts[phaseIndex].name) {
                                    VStack(spacing: 16) {
                                        
                                        // 1. PHASE NAME & ICON ROW
                                        HStack(spacing: 12) {
                                            Button {
                                                editingPhaseIconIndex = phaseIndex
                                            } label: {
                                                LureliaIconView(iconId: phaseDrafts[phaseIndex].icon, size: 18)
                                                    .foregroundStyle(selectedColor)
                                                    .frame(width: 38, height: 38)
                                                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .strokeBorder(selectedColor.opacity(0.35), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            
                                            TextField("Phase name", text: $phaseDrafts[phaseIndex].name)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                            
                                            Spacer()
                                            
                                            Button { phaseDrafts.remove(at: phaseIndex) } label: {
                                                Image("trash").renderingMode(.template).resizable().scaledToFit()
                                                    .frame(width: 14, height: 14).foregroundStyle(LColors.gradientCyan)
                                            }.buttonStyle(.plain)
                                        }
                                        
                                        Divider().overlay(LColors.glassBorder)
                                        
                                        // 2. PHASE TASKS LIST & ADD TASK BUTTON
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Tasks for this Phase")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                                
                                            phaseTaskListContent(phaseIndex: phaseIndex)
                                        }
                                        
                                        Divider().overlay(LColors.glassBorder)
                                        
                                        // 3. PER-PHASE SCHEDULE CARD
                                        Button {
                                            editingPhaseScheduleIndex = phaseIndex
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image("starcal").renderingMode(.template).resizable().scaledToFit()
                                                    .frame(width: 14, height: 14).foregroundStyle(selectedColor)
                                                
                                                if phaseDrafts[phaseIndex].scheduleEnabled {
                                                    let days = phaseDrafts[phaseIndex].scheduledDays.sorted()
                                                        .compactMap { d in d >= 1 && d <= 7 ? Calendar.current.shortWeekdaySymbols[d - 1] : nil }
                                                        .joined(separator: ", ")
                                                    Text(days.isEmpty ? "Schedule" : days)
                                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(LColors.textPrimary)
                                                } else {
                                                    Text("Add Schedule")
                                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(LColors.textSecondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Image("chevright").renderingMode(.template).resizable().scaledToFit()
                                                    .frame(width: 11, height: 11).foregroundStyle(LColors.textSecondary.opacity(0.55))
                                            }
                                            .padding(12)
                                            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .strokeBorder(selectedColor.opacity(0.35), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            // Add Phase Button
                            Button {
                                phaseDrafts.append(LureliaRoutinePhaseDraft(name: ""))
                            } label: {
                                HStack(spacing: 6) {
                                    Image("addwavy").renderingMode(.template).resizable().scaledToFit()
                                        .frame(width: 10, height: 10).foregroundStyle(.white)
                                    Text("Add Phase")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(LColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.inputRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                        .strokeBorder(selectedColor.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
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
                    Button("Cancel") { dismiss() }.foregroundStyle(LColors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .fontWeight(.semibold).foregroundStyle(LColors.textPrimary).disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddCustomTask, onDismiss: {
                editingRoutineTaskIndex = nil
            }) {
                addTaskSheet
            }
            .sheet(item: $phaseTaskSheetTarget) { target in
                phaseTaskSheet(target: target)
            }
            .sheet(isPresented: $showIconPicker) {
                LureliaIconPickerView(selectedIcon: $selectedIcon)
            }
            .sheet(isPresented: Binding(
                get: { editingPhaseScheduleIndex != nil },
                set: { if !$0 { editingPhaseScheduleIndex = nil } }
            )) {
                if let phaseIndex = editingPhaseScheduleIndex, phaseIndex < phaseDrafts.count {
                    PhaseScheduleSheet(draft: $phaseDrafts[phaseIndex], tintColor: selectedColor)
                }
            }
            .sheet(isPresented: Binding(
                get: { editingPhaseIconIndex != nil },
                set: { if !$0 { editingPhaseIconIndex = nil } }
            )) {
                if let phaseIndex = editingPhaseIconIndex, phaseIndex < phaseDrafts.count {
                    LureliaIconPickerView(selectedIcon: $phaseDrafts[phaseIndex].icon)
                }
            }
        }
        .onAppear { populate() }
    }
    
    // MARK: - Add Task Sheet
    
    @ViewBuilder
    private var addTaskSheet: some View {
        if let editIndex = editingRoutineTaskIndex {
            AddCustomRoutineTaskView(
                initialTaskName: routineTasks[editIndex].name,
                initialNotes: routineTasks[editIndex].notes,
                initialIcon: routineTasks[editIndex].icon
            ) { name, notes, icon in
                routineTasks[editIndex].name = name
                routineTasks[editIndex].notes = notes
                routineTasks[editIndex].icon = icon
            }
        } else {
            AddCustomRoutineTaskView { name, notes, icon in
                routineTasks.append(
                    LureliaRoutineTaskDraft(
                        name: name,
                        icon: icon,
                        notes: notes
                    )
                )
            }
        }
    }
    
    @ViewBuilder
    private func phaseTaskSheet(target: PhaseTaskSheetTarget) -> some View {
        if target.phaseIndex < phaseDrafts.count {
            switch target.mode {

            case .add:
                AddCustomRoutineTaskView { name, notes, icon in
                    phaseDrafts[target.phaseIndex].tasks.append(
                        LureliaRoutineTaskDraft(
                            name: name,
                            icon: icon,
                            notes: notes
                        )
                    )

                    print("Added phase task")
                    print("Phase:", target.phaseIndex)
                    print("Task Count:", phaseDrafts[target.phaseIndex].tasks.count)
                    print(phaseDrafts[target.phaseIndex].tasks.map(\.name))
                }

            case .edit(let taskIndex):
                if taskIndex < phaseDrafts[target.phaseIndex].tasks.count {
                    let draft = phaseDrafts[target.phaseIndex].tasks[taskIndex]

                    AddCustomRoutineTaskView(
                        initialTaskName: draft.name,
                        initialNotes: draft.notes,
                        initialIcon: draft.icon
                    ) { name, notes, icon in
                        phaseDrafts[target.phaseIndex].tasks[taskIndex] = LureliaRoutineTaskDraft(
                            name: name,
                            icon: icon,
                            notes: notes
                        )

                        print("Edited phase task")
                        print("Phase:", target.phaseIndex)
                        print("Task Count:", phaseDrafts[target.phaseIndex].tasks.count)
                    }
                } else {
                    Text("Task not found")
                }
            }
        } else {
            Text("Phase not found")
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
                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [LColors.gradientBlue.opacity(0.95), LColors.gradientPurple.opacity(0.95), Color.white.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                )
        }
    }
    
    // MARK: - Schedule Content (reusable)
    
    private func scheduleContent(
        selectedDays: Binding<Set<Int>>,
        startHour: Binding<Int>,
        startMinute: Binding<Int>,
        endHour: Binding<Int>,
        endMinute: Binding<Int>,
        durationMode: Binding<Bool>,
        durationMinutesOverride: Binding<Int>
    ) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(lureliaWeekdays, id: \.value) { day in
                    Button {
                        if selectedDays.wrappedValue.contains(day.value) {
                            selectedDays.wrappedValue.remove(day.value)
                        } else {
                            selectedDays.wrappedValue.insert(day.value)
                        }
                    } label: {
                        Text(day.label)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(
                                selectedDays.wrappedValue.contains(day.value) ? selectedColor.opacity(0.5) : LColors.glassSurface,
                                in: Circle()
                            )
                            .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            
            Divider().overlay(LColors.glassBorder)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Start time").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
                LureliaGradientTimeDrumPicker(hour: startHour, minute: startMinute)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("End time").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
                LureliaGradientTimeDrumPicker(hour: endHour, minute: endMinute)
            }
            
            Divider().overlay(LColors.glassBorder)
            
            Toggle(isOn: durationMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration countdown")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Text("Count down from a set duration instead of end time")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }
            }.tint(LColors.gradientBlue)
            
            if durationMode.wrappedValue {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration (minutes)").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
                    TextField("e.g. 45", value: durationMinutesOverride, format: .number)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                }
            }
        }
    }
        
    // MARK: - Task List Content (reusable for routine-level and phase-level)

    private func taskListContent(
        tasks: Binding<[LureliaRoutineTaskDraft]>,
        onAdd: @escaping () -> Void,
        onEdit: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 10) {

            Button {
                onAdd()
            } label: {
                HStack(spacing: 6) {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.white)

                    Text("Add Task")
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

            if !tasks.wrappedValue.isEmpty {
                Divider().overlay(LColors.glassBorder)

                VStack(spacing: 10) {
                    ForEach(Array(tasks.wrappedValue.enumerated()), id: \.element.id) { index, taskDraft in
                        HStack(spacing: 10) {
                            Button {
                                onEdit(index)
                            } label: {
                                Image("settings")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 13, height: 13)
                                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
                            }
                            .buttonStyle(.plain)

                            LureliaIconView(iconId: taskDraft.icon, size: 16)
                                .foregroundStyle(selectedColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(taskDraft.name)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)

                                if !taskDraft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(taskDraft.notes)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Button {
                                tasks.wrappedValue.remove(at: index)
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

                        if index < tasks.wrappedValue.count - 1 {
                            Divider().overlay(LColors.glassBorder)
                        }
                    }
                }
            }
        }
    }
    
    private func phaseTaskListContent(phaseIndex: Int) -> some View {
        VStack(spacing: 10) {

            Button {
                phaseTaskSheetTarget = PhaseTaskSheetTarget(
                    phaseIndex: phaseIndex,
                    mode: .add
                )
            } label: {
                HStack(spacing: 6) {
                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.white)

                    Text("Add Task")
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

            if phaseIndex < phaseDrafts.count,
               !phaseDrafts[phaseIndex].tasks.isEmpty {

                Divider().overlay(LColors.glassBorder)

                VStack(spacing: 10) {
                    ForEach(phaseDrafts[phaseIndex].tasks.indices, id: \.self) { taskIndex in
                        let taskDraft = phaseDrafts[phaseIndex].tasks[taskIndex]

                        HStack(spacing: 10) {
                            Button {
                                phaseTaskSheetTarget = PhaseTaskSheetTarget(
                                    phaseIndex: phaseIndex,
                                    mode: .edit(taskIndex: taskIndex)
                                )
                            } label: {
                                Image("settings")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 13, height: 13)
                                    .foregroundStyle(LColors.textSecondary.opacity(0.55))
                            }
                            .buttonStyle(.plain)

                            LureliaIconView(iconId: taskDraft.icon, size: 16)
                                .foregroundStyle(selectedColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(taskDraft.name)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)

                                if !taskDraft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(taskDraft.notes)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Button {
                                phaseDrafts[phaseIndex].tasks.remove(at: taskIndex)
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

                        if taskIndex < phaseDrafts[phaseIndex].tasks.count - 1 {
                            Divider().overlay(LColors.glassBorder)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Reminder Helpers
    
    private var calculatedDurationMinutes: Int {
        if durationMode { return max(1, durationMinutesOverride) }
        let diff = (endHour * 60 + endMinute) - (startHour * 60 + startMinute)
        return max(1, diff > 0 ? diff : diff + 1440)
    }
    
    private var halfwayReminderTotalMinutes: Int { ((startHour * 60 + startMinute) + (calculatedDurationMinutes / 2)) % 1440 }
    private var halfwayReminderHour: Int { halfwayReminderTotalMinutes / 60 }
    private var halfwayReminderMinute: Int { halfwayReminderTotalMinutes % 60 }
    private var endReminderTotalMinutes: Int { durationMode ? ((startHour * 60 + startMinute) + calculatedDurationMinutes) % 1440 : endHour * 60 + endMinute }
    private var endReminderHour: Int { endReminderTotalMinutes / 60 }
    private var endReminderMinute: Int { endReminderTotalMinutes % 60 }
    
    private func formattedTime(hour: Int, minute: Int) -> String {
        var c = DateComponents(); c.hour = hour; c.minute = minute
        guard let d = Calendar.current.date(from: c) else { return "\(hour):\(String(format: "%02d", minute))" }
        return d.formatted(date: .omitted, time: .shortened)
    }
    
    private func reminderPreviewRow(title: String, time: String) -> some View {
        HStack(spacing: 8) {
            Image("bellfill").renderingMode(.template).resizable().scaledToFit()
                .frame(width: 12, height: 12).foregroundStyle(selectedColor)
            Text(title).font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(LColors.textPrimary)
            Spacer()
            Text(time).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(LColors.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Populate
    
    private func populate() {
        guard let routine = editingRoutine else { return }
        
        name = routine.name
        selectedIcon = routine.icon
        timeOfDay = routine.timeOfDay
        selectedColor = Color(lureliaHex: routine.colorHex)
        purpose = routine.purpose
        descriptionText = routine.descriptionText
        principles = routine.principles
        phasesEnabled = routine.phasesEnabled
        reminderEnabled = routine.remindersEnabled
        scheduleEnabled = routine.scheduleEnabled
        selectedDays = Set(routine.scheduledDays)
        startHour = routine.startHour
        startMinute = routine.startMinute
        endHour = routine.endHour
        endMinute = routine.endMinute
        durationMode = routine.durationMode
        durationMinutesOverride = routine.durationMinutesOverride
        
        if routine.phasesEnabled {
            phaseDrafts = routine.sortedPhases.map { phase in
                var draft = LureliaRoutinePhaseDraft(name: phase.name)
                draft.icon = phase.icon
                draft.scheduleEnabled = phase.scheduleEnabled
                draft.scheduledDays = Set(phase.scheduledDays)
                draft.startHour = phase.startHour
                draft.startMinute = phase.startMinute
                draft.endHour = phase.endHour
                draft.endMinute = phase.endMinute
                draft.durationMode = phase.durationMode
                draft.durationMinutesOverride = phase.durationMinutesOverride
                
                let phaseIDString = phase.id.uuidString
                draft.tasks = routine.sortedTasks
                    .filter { $0.phaseID == phaseIDString }
                    .map { LureliaRoutineTaskDraft(name: $0.title, icon: $0.icon, notes: $0.notes) }
                return draft
            }
        } else {
            routineTasks = routine.sortedTasks.map {
                LureliaRoutineTaskDraft(name: $0.title, icon: $0.icon, notes: $0.notes)
            }
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
            existing.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.principles = principles
            existing.phasesEnabled = phasesEnabled
            existing.remindersEnabled = reminderEnabled
            existing.scheduleEnabled = phasesEnabled ? false : scheduleEnabled
            existing.scheduledDays = Array(selectedDays).sorted()
            existing.startHour = startHour
            existing.startMinute = startMinute
            existing.endHour = endHour
            existing.endMinute = endMinute
            existing.durationMode = durationMode
            existing.durationMinutesOverride = durationMinutesOverride
            existing.updatedAt = Date()
            
            // Delete old tasks and phases
            (existing.tasks ?? []).forEach { modelContext.delete($0) }
            (existing.phases ?? []).forEach { modelContext.delete($0) }
            
            routine = existing
        } else {
            routine = LureliaRoutine(
                name: trimmed, icon: selectedIcon, timeOfDay: timeOfDay,
                colorHex: selectedColor.toLureliaHex() ?? "#7d19f7",
                scheduledDays: Array(selectedDays).sorted(),
                startHour: startHour, startMinute: startMinute,
                endHour: endHour, endMinute: endMinute,
                scheduleEnabled: phasesEnabled ? false : scheduleEnabled,
                sortOrder: routines.count,
                durationMode: durationMode,
                durationMinutesOverride: durationMinutesOverride
            )
            modelContext.insert(routine)
            routine.remindersEnabled = reminderEnabled
            routine.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
            routine.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            routine.principles = principles
            routine.phasesEnabled = phasesEnabled
        }
        
        if phasesEnabled {
            // Create phases and their tasks
            for (phaseIndex, draft) in phaseDrafts.enumerated() {
                let phase = LureliaRoutinePhase(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    icon: draft.icon,
                    sortOrder: phaseIndex
                )
                phase.scheduleEnabled = draft.scheduleEnabled
                phase.scheduledDays = Array(draft.scheduledDays).sorted()
                phase.startHour = draft.startHour
                phase.startMinute = draft.startMinute
                phase.endHour = draft.endHour
                phase.endMinute = draft.endMinute
                phase.durationMode = draft.durationMode
                phase.durationMinutesOverride = draft.durationMinutesOverride
                phase.routine = routine
                modelContext.insert(phase)
                
                let phaseIDString = phase.id.uuidString
                for (taskIndex, taskDraft) in draft.tasks.enumerated() {
                    let task = LureliaRoutineTask(
                        title: taskDraft.name, icon: taskDraft.icon,
                        notes: taskDraft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        sortOrder: taskIndex
                    )
                    task.phaseID = phaseIDString
                    task.routine = routine
                    modelContext.insert(task)
                }
            }
        } else {
            // Create routine-level tasks
            for (index, draft) in routineTasks.enumerated() {
                let task = LureliaRoutineTask(
                    title: draft.name, icon: draft.icon,
                    notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    sortOrder: index
                )
                task.routine = routine
                modelContext.insert(task)
            }
        }
        
        try? modelContext.save()
        let reminderSyncResults = syncRoutineReminders(for: routine)
        try? modelContext.save()
        if editingRoutine == nil { onCreated?(routine) }
        
        Task {
            for result in reminderSyncResults {
                switch result {
                case .schedule(let reminder):
                    await LureliaNotificationManager.shared.cancelReminder(reminder)
                    await LureliaNotificationManager.shared.scheduleReminder(reminder)
                case .cancel(let reminder):
                    await LureliaNotificationManager.shared.cancelReminder(reminder)
                case .none: break
                }
            }
        }
        dismiss()
    }
    
    // MARK: - Reminder Sync
    
    private func syncRoutineReminders(for routine: LureliaRoutine) -> [RoutineReminderSyncResult] {
        let routineID = routine.persistentModelID.hashValue.description
        let reminderConfigs: [(key: String, title: String, note: String, hour: Int, minute: Int)] = [
            ("start", "\(routine.name) Start", "Routine start reminder", startHour, startMinute),
            ("halfway", "\(routine.name) Halfway", "Routine halfway reminder", halfwayReminderHour, halfwayReminderMinute),
            ("end", "\(routine.name) End", "Routine end reminder", endReminderHour, endReminderMinute)
        ]
        let validKeys = reminderConfigs.map { "\(routineID)::\($0.key)" }
        
        if !reminderEnabled {
            return reminders
                .filter { $0.kind == .routine && (validKeys.contains($0.routinePersistentID ?? "") || $0.routinePersistentID == routineID) }
                .map { r in r.isEnabled = false; r.updatedAt = Date(); return .cancel(r) }
        }
        
        return reminderConfigs.map { config in
            let reminderKey = "\(routineID)::\(config.key)"
            let scheduledDate = reminderDate(hour: config.hour, minute: config.minute)
            let reminder: LureliaReminder
            if let existing = reminders.first(where: { $0.kind == .routine && $0.routinePersistentID == reminderKey }) {
                reminder = existing
            } else {
                reminder = LureliaReminder(title: config.title, notes: config.note, category: "Routines", kind: .routine, scheduledDate: scheduledDate, repeatUnit: selectedDays.isEmpty ? .none : .weeks, repeatInterval: 1)
                reminder.routinePersistentID = reminderKey
                modelContext.insert(reminder)
            }
            reminder.title = config.title; reminder.notes = config.note; reminder.category = "Routines"
            reminder.kind = .routine; reminder.routinePersistentID = reminderKey; reminder.isEnabled = true
            reminder.scheduledDate = scheduledDate; reminder.repeatUnit = selectedDays.isEmpty ? .none : .weeks
            reminder.repeatInterval = 1; reminder.repeatWeekdays = Array(selectedDays).sorted()
            reminder.nextFireAt = scheduledDate; reminder.updatedAt = Date()
            return .schedule(reminder)
        }
    }
    
    private func reminderDate(hour: Int, minute: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c) ?? Date()
    }
}

private enum RoutineReminderSyncResult {
    case schedule(LureliaReminder)
    case cancel(LureliaReminder)
    case none
}

// MARK: - Phase Schedule Sheet

struct PhaseScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: LureliaRoutinePhaseDraft
    let tintColor: Color
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schedule for \(draft.name.isEmpty ? "Phase" : draft.name)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                            
                            VStack(spacing: 14) {
                                Toggle(isOn: $draft.scheduleEnabled) {
                                    Text("Enable schedule")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                }.tint(LColors.gradientBlue)
                                
                                if draft.scheduleEnabled {
                                    HStack(spacing: 6) {
                                        ForEach(lureliaWeekdays, id: \.value) { day in
                                            Button {
                                                if draft.scheduledDays.contains(day.value) {
                                                    draft.scheduledDays.remove(day.value)
                                                } else {
                                                    draft.scheduledDays.insert(day.value)
                                                }
                                            } label: {
                                                Text(day.label)
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundStyle(LColors.textPrimary)
                                                    .frame(width: 34, height: 34)
                                                    .background(
                                                        draft.scheduledDays.contains(day.value) ? tintColor.opacity(0.5) : LColors.glassSurface,
                                                        in: Circle()
                                                    )
                                                    .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                    
                                    Divider().overlay(LColors.glassBorder)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Start time").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
                                        LureliaGradientTimeDrumPicker(hour: $draft.startHour, minute: $draft.startMinute)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("End time").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
                                        LureliaGradientTimeDrumPicker(hour: $draft.endHour, minute: $draft.endMinute)
                                    }
                                    
                                    Divider().overlay(LColors.glassBorder)
                                    
                                    Toggle(isOn: $draft.durationMode) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Duration countdown")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                            Text("Count down from a set duration instead of end time")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                        }
                                    }.tint(LColors.gradientBlue)
                                    
                                    if draft.durationMode {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Duration (minutes)").font(.system(size: 12, design: .rounded)).foregroundStyle(LColors.textSecondary)
                                            TextField("e.g. 45", value: $draft.durationMinutesOverride, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 15, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: LSpacing.cardRadius)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [LColors.gradientBlue.opacity(0.95), LColors.gradientPurple.opacity(0.95), Color.white.opacity(0.55)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.15
                                    )
                            )
                        }
                    }
                    .padding(.horizontal).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .navigationTitle("Phase Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(LColors.textPrimary)
                }
            }
        }
    }
}

// MARK: - Add Custom Routine Task Sheet

struct AddCustomRoutineTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, String, String) -> Void
    private let isEditing: Bool
    @State private var taskName: String
    @State private var notes: String
    @State private var selectedIcon: String
    @State private var showIconPicker = false

    init(initialTaskName: String = "", initialNotes: String = "", initialIcon: String = "sparkle", onAdd: @escaping (String, String, String) -> Void) {
        self.onAdd = onAdd
        self.isEditing = !initialTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        _taskName = State(initialValue: initialTaskName)
        _notes = State(initialValue: initialNotes)
        _selectedIcon = State(initialValue: initialIcon)
    }
    private var canAdd: Bool { !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Task Name").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(LColors.textSecondary)
                            TextField("e.g. Wipe down surfaces", text: $taskName)
                                .font(.system(size: 15, design: .rounded)).foregroundStyle(LColors.textPrimary)
                                .padding(14).background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                                .overlay(RoundedRectangle(cornerRadius: LSpacing.cardRadius).strokeBorder(LColors.glassBorder, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Icon").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(LColors.textSecondary)
                            Button { showIconPicker = true } label: {
                                HStack(spacing: 14) {
                                    LureliaIconView(iconId: selectedIcon, size: 26).foregroundStyle(LColors.textPrimary)
                                        .frame(width: 44, height: 44).background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: LSpacing.inputRadius))
                                    Text("Choose icon").font(.system(size: 14, design: .rounded)).foregroundStyle(LColors.textSecondary)
                                    Spacer()
                                    Image("chevright").renderingMode(.template).resizable().scaledToFit()
                                        .frame(width: 13, height: 13).foregroundStyle(LColors.textSecondary.opacity(0.55))
                                }.padding(14).background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                                .overlay(RoundedRectangle(cornerRadius: LSpacing.cardRadius).strokeBorder(LColors.glassBorder, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes (optional)").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(LColors.textSecondary)
                            TextField("Any details...", text: $notes, axis: .vertical).lineLimit(3, reservesSpace: true)
                                .font(.system(size: 15, design: .rounded)).foregroundStyle(LColors.textPrimary)
                                .padding(14).background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                                .overlay(RoundedRectangle(cornerRadius: LSpacing.cardRadius).strokeBorder(LColors.glassBorder, lineWidth: 1))
                        }
                        Spacer(minLength: 32)
                    }.padding(.horizontal).padding(.top, 16)
                }.scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit Task" : "Add Task").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(LColors.textPrimary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        let t = taskName.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
                        onAdd(t, notes.trimmingCharacters(in: .whitespacesAndNewlines), selectedIcon); dismiss()
                    }.fontWeight(.semibold).foregroundStyle(LColors.textPrimary).disabled(!canAdd)
                }
            }
            .sheet(isPresented: $showIconPicker) { LureliaIconPickerView(selectedIcon: $selectedIcon) }
        }
    }
}

// MARK: - Routine Task Draft

struct LureliaRoutineTaskDraft: Identifiable {
    let id = UUID()
    var name: String
    var icon: String = "sparkle"
    var notes: String = ""
    var isFromBank: Bool = false
    var bankTaskID: String? = nil
}

// MARK: - Icon Picker

struct LureliaIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    @State private var searchText = ""
    
    private var filteredIcons: [LureliaIconItem] { LureliaIconLibrary.search(searchText) }
    private var groupedIcons: [(category: String, icons: [LureliaIconItem])] {
        Dictionary(grouping: filteredIcons) { $0.category }
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
                            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(LColors.textSecondary.opacity(0.7))
                            TextField("Search icons", text: $searchText).font(.system(size: 14, design: .rounded)).foregroundStyle(LColors.textPrimary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: LSpacing.cardRadius))
                        .overlay(RoundedRectangle(cornerRadius: LSpacing.cardRadius).strokeBorder(LColors.glassBorder, lineWidth: 1))
                        
                        ForEach(groupedIcons, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.category).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(LColors.textSecondary)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                                    ForEach(group.icons) { icon in
                                        Button { selectedIcon = icon.name; dismiss() } label: {
                                            LureliaIconView(iconId: icon.name, size: 24)
                                                .foregroundStyle(selectedIcon == icon.name ? .white : LColors.textPrimary.opacity(0.75))
                                                .frame(width: 52, height: 52)
                                                .background(selectedIcon == icon.name ? AnyShapeStyle(LGradients.header) : AnyShapeStyle(LColors.glassSurface), in: RoundedRectangle(cornerRadius: 16))
                                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selectedIcon == icon.name ? LColors.glassBorderStrong : LColors.glassBorder, lineWidth: 1))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }.padding(.horizontal).padding(.vertical, 16)
                }.scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Choose Icon").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(LColors.textPrimary) }
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
            Picker("Hour", selection: $hour) { ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }
                .pickerStyle(.wheel).frame(maxWidth: .infinity).frame(height: 110).clipped()
            Text(":").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LColors.textPrimary)
            Picker("Minute", selection: $minute) { ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }
                .pickerStyle(.wheel).frame(maxWidth: .infinity).frame(height: 110).clipped()
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    func toLureliaHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
