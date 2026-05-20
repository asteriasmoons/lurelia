//
//  AddReminderView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UserNotifications

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var settings: [UserSettings]
    
    var editingReminder: LureliaReminder? = nil
    var onCreated: ((LureliaReminder) -> Void)? = nil
    
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedCategory = ""
    @State private var selectedIcon = "bellfill"
    @State private var showIconPicker = false
    @FocusState private var notesFieldIsFocused: Bool
    
    
    @State private var reminderDate = Date()
    @State private var reminderHour = 9
    @State private var reminderMinute = 0
    @State private var additionalFireTimes: [LureliaAdditionalFireTime] = []
    
    @State private var repeatUnit: LureliaReminderRepeatUnit = .none
    @State private var repeatInterval = 1
    @State private var repeatWeekdays: Set<Int> = []
    @State private var repeatEnds = false
    @State private var repeatEndsAt = Date()
    
    private let weekdays: [(label: String, value: Int)] = [
        ("Su", 1), ("Mo", 2), ("Tu", 3), ("We", 4),
        ("Th", 5), ("Fr", 6), ("Sa", 7)
    ]
    
    private var isEditing: Bool {
        editingReminder != nil
    }
    
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var scheduledDate: Date {
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: reminderDate
        )
        
        components.hour = reminderHour
        components.minute = reminderMinute
        components.second = 0
        
        return Calendar.current.date(from: components) ?? Date()
    }

    private var allPreviewFireDates: [Date] {
        let calendar = Calendar.current
        let extraDates = additionalFireTimes.compactMap { fireTime -> Date? in
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            components.hour = fireTime.hour
            components.minute = fireTime.minute
            components.second = 0
            return calendar.date(from: components)
        }

        return ([scheduledDate] + extraDates).sorted()
    }

    private func repeatUnitText(for unit: LureliaReminderRepeatUnit) -> String {
        switch unit {
        case .none:
            return "None"
        case .minutes:
            return "Minutes"
        case .hours:
            return "Hours"
        case .days:
            return "Days"
        case .weeks:
            return "Weeks"
        case .months:
            return "Months"
        case .years:
            return "Years"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        notesFieldIsFocused = false
                    }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        previewCard
                        
                        field("Reminder Title") {
                            TextField("What should Lurelia remind you about?", text: $title)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        field("Notes") {
                            TextField("Optional details", text: $notes, axis: .vertical)
                                .focused($notesFieldIsFocused)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }

                        field("Icon") {
                            Button {
                                showIconPicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(LColors.gradientBlue.opacity(0.16))
                                            .frame(width: 44, height: 44)

                                        LureliaIconView(iconId: selectedIcon, size: 22)
                                            .foregroundStyle(LGradients.header)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Reminder Icon")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)

                                        Text("Tap to choose a custom icon.")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(LColors.textSecondary.opacity(0.75))
                                    }

                                    Spacer()

                                    Image("slider")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .foregroundStyle(LGradients.header)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        field("Date") {
                            DatePicker(
                                "Reminder date",
                                selection: $reminderDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .tint(LColors.gradientBlue)
                            .foregroundStyle(LColors.textPrimary)
                        }
                        
                        field("Time") {
                            LureliaGradientTimeDrumPicker(
                                hour: $reminderHour,
                                minute: $reminderMinute
                            )
                        }

                        field("Additional Times") {
                            additionalFireTimesSection
                        }
                        
                        field("Repeat") {
                            repeatSection
                        }
                        
                        Button {
                            save()
                        } label: {
                            Text(isEditing ? "Save Reminder" : "Create Reminder")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(LGradients.header)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(width: 78, height: 34)
                            .background(
                                Capsule()
                                    .fill(LColors.glassSurface)
                            )
                            .overlay(
                                Capsule()
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
                                        lineWidth: 1.1
                                    )
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            populate()
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LColors.gradientBlue.opacity(0.16))
                        .frame(width: 58, height: 58)

                    LureliaIconView(iconId: selectedIcon, size: 28)
                        .foregroundStyle(LGradients.header)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reminder Preview" : title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(2)

                    Text(scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.gradientBlue)
                        .lineLimit(2)
                }

                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 70), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Array(allPreviewFireDates.enumerated()), id: \.offset) { _, fireDate in
                    Text(fireDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(LColors.glassSurface2, in: Capsule())
                }
            }
            
            if repeatUnit != .none {
                Text(repeatPreviewText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LColors.glassSurface2, in: Capsule())
            }
        }
        .padding(18)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
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
                    lineWidth: 1.2
                )
        )
    }
    private var additionalFireTimesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if additionalFireTimes.isEmpty {
                Text("Add another time when this reminder needs to fire more than once on the same day.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 12) {
                    ForEach(additionalFireTimes) { fireTime in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text("Extra Fire Time")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(LColors.textSecondary)

                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        additionalFireTimes.removeAll { $0.id == fireTime.id }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                        .frame(width: 30, height: 30)
                                        .background(LColors.glassSurface2, in: Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            LureliaGradientTimeDrumPicker(
                                hour: bindingForAdditionalFireHour(fireTime.id),
                                minute: bindingForAdditionalFireMinute(fireTime.id)
                            )
                        }
                        .padding(12)
                        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            LColors.gradientBlue.opacity(0.78),
                                            LColors.gradientPurple.opacity(0.78)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }

            Button {
                addAdditionalFireTime()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .black, design: .rounded))

                    Text("Add Another Time")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LGradients.header, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    private func addAdditionalFireTime() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            additionalFireTimes.append(
                LureliaAdditionalFireTime(
                    hour: reminderHour,
                    minute: reminderMinute
                )
            )
        }
    }

    private func bindingForAdditionalFireHour(_ id: UUID) -> Binding<Int> {
        Binding(
            get: {
                additionalFireTimes.first(where: { $0.id == id })?.hour ?? reminderHour
            },
            set: { newValue in
                guard let index = additionalFireTimes.firstIndex(where: { $0.id == id }) else { return }
                additionalFireTimes[index].hour = newValue
            }
        )
    }

    private func bindingForAdditionalFireMinute(_ id: UUID) -> Binding<Int> {
        Binding(
            get: {
                additionalFireTimes.first(where: { $0.id == id })?.minute ?? reminderMinute
            },
            set: { newValue in
                guard let index = additionalFireTimes.firstIndex(where: { $0.id == id }) else { return }
                additionalFireTimes[index].minute = newValue
            }
        )
    }
    
    
    
    private var repeatSection: some View {
        VStack(spacing: 14) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(LureliaReminderRepeatUnit.allCases, id: \.self) { unit in
                    Button {
                        repeatUnit = unit
                    } label: {
                        Text(repeatUnitText(for: unit))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(repeatUnit == unit ? .white : LColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                repeatUnit == unit
                                ? AnyShapeStyle(LGradients.header)
                                : AnyShapeStyle(LColors.glassSurface2),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if repeatUnit != .none {
                Stepper(value: $repeatInterval, in: 1...999) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Every \(repeatInterval) \(repeatUnit.rawValue.lowercased())")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        
                        Text("Controls how often this reminder repeats.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.75))
                    }
                }
                .tint(LColors.gradientBlue)
                
                if repeatUnit == .weeks {
                    HStack(spacing: 6) {
                        ForEach(weekdays, id: \.value) { day in
                            Button {
                                if repeatWeekdays.contains(day.value) {
                                    repeatWeekdays.remove(day.value)
                                } else {
                                    repeatWeekdays.insert(day.value)
                                }
                            } label: {
                                Text(day.label)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        repeatWeekdays.contains(day.value)
                                        ? AnyShapeStyle(LGradients.header)
                                        : AnyShapeStyle(LColors.glassSurface2),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Toggle(isOn: $repeatEnds) {
                    Text("Repeat ends")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                }
                .tint(LColors.gradientBlue)
                
                if repeatEnds {
                    DatePicker(
                        "End date",
                        selection: $repeatEndsAt,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .tint(LColors.gradientBlue)
                }
            }
        }
    }
    
    private var repeatPreviewText: String {
        guard repeatUnit != .none else { return "Does not repeat" }
        return "Repeats every \(repeatInterval) \(repeatUnit.rawValue.lowercased())"
    }
    
    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
            
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.85),
                                    LColors.gradientPurple.opacity(0.85),
                                    Color.white.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
        }
    }
    
    private func populate() {
        guard let reminder = editingReminder else { return }

        title = reminder.title
        selectedIcon = reminder.icon
        notes = reminder.notes ?? ""
        selectedCategory = ""
        reminderDate = reminder.scheduledDate

        // Use the originally configured primary hour/minute, not the advanced scheduledDate
        if reminder.primaryHour != -1 {
            reminderHour = reminder.primaryHour
            reminderMinute = reminder.primaryMinute
        } else {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminder.scheduledDate)
            reminderHour = components.hour ?? 9
            reminderMinute = components.minute ?? 0
        }
        additionalFireTimes = reminder.additionalFireTimes

        repeatUnit = reminder.repeatUnit
        repeatInterval = reminder.repeatInterval
        repeatWeekdays = Set(reminder.repeatWeekdays)

        if let repeatEndsAt = reminder.repeatEndsAt {
            repeatEnds = true
            self.repeatEndsAt = repeatEndsAt
        }
    }
    
    private func save() {
        guard canSave else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let reminder: LureliaReminder

        if let editingReminder {
            reminder = editingReminder
        } else {
            reminder = LureliaReminder(
                title: cleanTitle,
                icon: selectedIcon,
                notes: cleanNotes.isEmpty ? nil : cleanNotes,
                category: "",
                kind: .standalone,
                scheduledDate: scheduledDate,
                repeatUnit: repeatUnit,
                repeatInterval: repeatInterval
            )

            modelContext.insert(reminder)
        }

        reminder.title = cleanTitle
        reminder.icon = selectedIcon
        reminder.notes = cleanNotes.isEmpty ? nil : cleanNotes
        reminder.category = ""
        reminder.kind = .standalone
        reminder.scheduledDate = scheduledDate
        reminder.repeatUnit = repeatUnit
        reminder.repeatInterval = max(1, repeatInterval)
        reminder.repeatWeekdays = Array(repeatWeekdays).sorted()
        reminder.repeatEndsAt = repeatEnds ? repeatEndsAt : nil
        reminder.additionalFireTimes = additionalFireTimes
        reminder.nextFireAt = scheduledDate
        reminder.isEnabled = true
        reminder.updatedAt = Date()

        // Store all fire times as HH:mm strings — single source of truth
        var allTimes: [String] = [String(format: "%02d:%02d", reminderHour, reminderMinute)]
        for ft in additionalFireTimes {
            allTimes.append(String(format: "%02d:%02d", ft.hour, ft.minute))
        }
        reminder.timesOfDay = allTimes

        // Preserve originally configured primary fire time
        if editingReminder == nil {
            reminder.primaryHour = reminderHour
            reminder.primaryMinute = reminderMinute
        } else if reminder.primaryHour == -1 {
            reminder.primaryHour = reminderHour
            reminder.primaryMinute = reminderMinute
        }

        try? modelContext.save()
        if editingReminder == nil { onCreated?(reminder) }

        Task {
            await LureliaNotificationManager.shared.scheduleReminder(reminder)
        }

        dismiss()
    }
}
