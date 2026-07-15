//
//  AddReminderView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit
import MapKit

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
    @State private var checklistItems: [LureliaReminderChecklistItem] = [
        LureliaReminderChecklistItem(title: "", sortOrder: 0)
    ]
    @State private var emptyChecklistSubmitCount = 0
    @FocusState private var focusedChecklistItemID: UUID?
    
    
    @State private var reminderDate = Date()
    @State private var reminderHour = 9
    @State private var reminderMinute = 0
    @State private var additionalFireTimes: [LureliaAdditionalFireTime] = []
    
    @State private var repeatUnit: LureliaReminderRepeatUnit = .none
    @State private var repeatInterval = 1
    @State private var repeatWeekdays: Set<Int> = []
    @State private var repeatEnds = false
    @State private var repeatEndsAt = Date()

    // Detail fields
    @State private var motivation = ""
    @State private var consequences = ""
    @State private var recoveryPlan = ""
    @State private var temptationNeed = ""
    @State private var temptationWant = ""

    // Location fields
    @State private var locationLabel = ""
    @State private var locationAddress = ""
    @State private var locationLatitude: Double? = nil
    @State private var locationLongitude: Double? = nil
    @State private var locationSearchText = ""
    @State private var locationSearchResults: [MKMapItem] = []
    @State private var showLocationSearch = false
    
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
                        focusedChecklistItemID = nil
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

                        checklistField

                        field("Icon") {
                            Button {
                                showIconPicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.14))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(LGradients.header, lineWidth: 1.4)
                                            )

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

                                    Image("settings")
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

                        // Detail fields

                        field("Motivation") {
                            TextField("What makes this reminder worth doing?", text: $motivation, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }

                        field("Consequences") {
                            TextField("What happens if this gets skipped or ignored?", text: $consequences, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }

                        field("Recovery Plan") {
                            TextField("How do I recover if this does not go as planned?", text: $recoveryPlan, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        field("Temptation Bundling") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Need: what do I need to do?", text: $temptationNeed, axis: .vertical)
                                    .lineLimit(2, reservesSpace: true)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)

                                Rectangle()
                                    .fill(.white.opacity(0.08))
                                    .frame(height: 1)

                                TextField("Want: what do I want to do?", text: $temptationWant, axis: .vertical)
                                    .lineLimit(2, reservesSpace: true)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                        }

                        // Location

                        locationField

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
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle()
                                .strokeBorder(LGradients.header, lineWidth: 1.6)
                        )

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
    private var checklistField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Completion Steps")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(nonEmptyChecklistItems.count) items")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)

                        Text("Add small steps to complete this reminder.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(LColors.textSecondary.opacity(0.75))
                    }

                    Spacer()

                    Button {
                        addChecklistItemAndFocus()
                    } label: {
                        Image("addwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 10) {
                    ForEach(checklistItems) { item in
                        checklistRow(item)
                    }
                }
            }
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
    
    private func checklistRow(_ item: LureliaReminderChecklistItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .strokeBorder(LGradients.header, lineWidth: 1.4)
                .frame(width: 20, height: 20)

            TextField("Step", text: checklistTitleBinding(for: item.id))
                .focused($focusedChecklistItemID, equals: item.id)
                .submitLabel(.return)
                .onSubmit {
                    handleChecklistSubmit(for: item.id)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            if checklistItems.count > 1 {
                Button {
                    removeChecklistItem(item.id)
                } label: {
                    Image("xmarkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LColors.textSecondary.opacity(0.75))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var nonEmptyChecklistItems: [LureliaReminderChecklistItem] {
        checklistItems.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func checklistTitleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                checklistItems.first(where: { $0.id == id })?.title ?? ""
            },
            set: { newValue in
                guard let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
                checklistItems[index].title = newValue
                checklistItems[index].updatedAt = Date()
                emptyChecklistSubmitCount = 0
            }
        )
    }
    
    private func addChecklistItemAndFocus() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            let newItem = LureliaReminderChecklistItem(
                title: "",
                sortOrder: checklistItems.count
            )
            checklistItems.append(newItem)
            focusedChecklistItemID = newItem.id
            emptyChecklistSubmitCount = 0
        }
    }

    private func handleChecklistSubmit(for id: UUID) {
        let trimmed = checklistItems.first(where: { $0.id == id })?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmed.isEmpty {
            emptyChecklistSubmitCount += 1

            if emptyChecklistSubmitCount >= 2 {
                focusedChecklistItemID = nil
                emptyChecklistSubmitCount = 0
            }

            return
        }

        emptyChecklistSubmitCount = 0
        addChecklistItemAndFocus()
    }

    private func removeChecklistItem(_ id: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            checklistItems.removeAll { $0.id == id }

            if checklistItems.isEmpty {
                checklistItems = [LureliaReminderChecklistItem(title: "", sortOrder: 0)]
            }

            normalizeChecklistSortOrder()
        }
    }

    private func normalizeChecklistSortOrder() {
        for index in checklistItems.indices {
            checklistItems[index].sortOrder = index
            checklistItems[index].updatedAt = Date()
        }
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
    
    
    
    private var locationField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            VStack(alignment: .leading, spacing: 14) {
                TextField("Label (e.g. Home, Walmart, Work)", text: $locationLabel)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                if locationLatitude != nil {
                    HStack(spacing: 8) {
                        Image("lovelocation")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(LGradients.header)

                        Text(locationAddress.isEmpty ? "Location selected" : locationAddress)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(2)

                        Spacer()

                        Button {
                            locationLatitude = nil
                            locationLongitude = nil
                            locationAddress = ""
                        } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(LColors.textSecondary.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }

                    let lat = locationLatitude!
                    let lon = locationLongitude!
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    ), interactionModes: []) {
                        Marker(locationLabel.isEmpty ? "Location" : locationLabel,
                               coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                    .allowsHitTesting(false)
                }

                // Search
                TextField("Search for a location", text: $locationSearchText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .onChange(of: locationSearchText) { _, newValue in
                        searchLocation(query: newValue)
                    }

                if !locationSearchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(locationSearchResults.prefix(5), id: \.self) { item in
                            Button {
                                selectMapItem(item)
                            } label: {
                                HStack(spacing: 10) {
                                    Image("lovelocation")
                                        .renderingMode(.template)
                                        .resizable().scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(LGradients.header)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(LColors.textPrimary)
                                            .lineLimit(1)
                                        if let address = item.placemark.formattedAddress {
                                            Text(address)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if item != locationSearchResults.prefix(5).last {
                                Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
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

    private func searchLocation(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            locationSearchResults = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            locationSearchResults = response?.mapItems ?? []
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        locationLatitude = item.placemark.coordinate.latitude
        locationLongitude = item.placemark.coordinate.longitude
        locationAddress = item.placemark.formattedAddress ?? ""
        if locationLabel.isEmpty {
            locationLabel = item.name ?? ""
        }
        locationSearchText = ""
        locationSearchResults = []
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
        let existingChecklist = reminder.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
        checklistItems = existingChecklist.isEmpty
            ? [LureliaReminderChecklistItem(title: "", sortOrder: 0)]
            : existingChecklist
        
        repeatUnit = reminder.repeatUnit
        repeatInterval = reminder.repeatInterval
        repeatWeekdays = Set(reminder.repeatWeekdays)

        if let repeatEndsAt = reminder.repeatEndsAt {
            repeatEnds = true
            self.repeatEndsAt = repeatEndsAt
        }

        // Detail fields
        motivation = reminder.motivation ?? ""
        consequences = reminder.consequences ?? ""
        recoveryPlan = reminder.recoveryPlan ?? ""
        temptationNeed = reminder.temptationNeed ?? ""
        temptationWant = reminder.temptationWant ?? ""

        // Location
        locationLabel = reminder.locationLabel ?? ""
        locationAddress = reminder.locationAddress ?? ""
        locationLatitude = reminder.locationLatitude
        locationLongitude = reminder.locationLongitude
    }
    
    private func save() {
        guard canSave else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let reminder: LureliaReminder
        let isCreatingNewReminder = editingReminder == nil
        let existingScheduleKey = editingReminder.map { scheduleKey(for: $0) }
        let newScheduleKey = currentScheduleKey()
        let scheduleDidChange = isCreatingNewReminder || existingScheduleKey != newScheduleKey

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

        // Detail fields
        reminder.purpose = nil
        reminder.importance = nil
        reminder.reminderOutcome = nil
        reminder.motivation = motivation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.consequences = consequences.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : consequences.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.recoveryPlan = recoveryPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : recoveryPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.temptationNeed = temptationNeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : temptationNeed.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.temptationWant = temptationWant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : temptationWant.trimmingCharacters(in: .whitespacesAndNewlines)

        // Location
        reminder.locationLabel = locationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.locationAddress = locationAddress.isEmpty ? nil : locationAddress
        reminder.locationLatitude = locationLatitude
        reminder.locationLongitude = locationLongitude

        reminder.checklistItems = nonEmptyChecklistItems.enumerated().map { index, item in
            LureliaReminderChecklistItem(
                id: item.id,
                title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                isCompleted: item.isCompleted,
                sortOrder: index,
                createdAt: item.createdAt,
                updatedAt: Date()
            )
        }
        reminder.levels = []
        if scheduleDidChange {
            reminder.nextFireAt = nextUnfiredDateFromCurrentForm()
        }
        reminder.isEnabled = true
        reminder.updatedAt = Date()

        // Only rewrite the configured primary fire time when creating or changing the schedule.
        if isCreatingNewReminder || scheduleDidChange || reminder.primaryHour == -1 {
            reminder.primaryHour = reminderHour
            reminder.primaryMinute = reminderMinute
        }

        // Store all fire times as HH:mm strings — single source of truth
        var allTimes: [String] = [String(format: "%02d:%02d", reminderHour, reminderMinute)]
        for ft in additionalFireTimes {
            allTimes.append(String(format: "%02d:%02d", ft.hour, ft.minute))
        }
        reminder.timesOfDay = Array(Set(allTimes)).sorted()

        let descriptor = FetchDescriptor<LureliaReminder>()
        let existingReminders = (try? modelContext.fetch(descriptor)) ?? []
        let duplicateMatches = existingReminders.filter { existing in
            existing.persistentModelID != reminder.persistentModelID &&
            existing.isDuplicateConfiguration(of: reminder)
        }

        for duplicate in duplicateMatches {
            LureliaNotificationManager.shared.cancelReminder(duplicate)
            modelContext.delete(duplicate)
        }

        if isCreatingNewReminder {
            modelContext.insert(reminder)
        }

        try? modelContext.save()
        if isCreatingNewReminder { onCreated?(reminder) }

        WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRemindersWidget")

        Task {
            await LureliaNotificationManager.shared.scheduleReminder(reminder)
            WidgetCenter.shared.reloadTimelines(ofKind: "LureliaDueRemindersWidget")
        }

        dismiss()
    }

    private func currentScheduleKey() -> String {
        let normalizedAdditionalTimes = additionalFireTimes
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            .sorted()
            .joined(separator: ",")

        let normalizedWeekdays = repeatWeekdays
            .sorted()
            .map(String.init)
            .joined(separator: ",")

        let endDateKey = repeatEnds
            ? String(Int(repeatEndsAt.timeIntervalSince1970))
            : "none"

        return [
            String(Int(scheduledDate.timeIntervalSince1970)),
            String(format: "%02d:%02d", reminderHour, reminderMinute),
            normalizedAdditionalTimes,
            repeatUnit.rawValue,
            String(max(1, repeatInterval)),
            normalizedWeekdays,
            endDateKey
        ].joined(separator: "|")
    }

    private func nextUnfiredDateFromCurrentForm(now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let sortedFireTimes = allCurrentFireTimes()

        for fireTime in sortedFireTimes {
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            components.hour = fireTime.hour
            components.minute = fireTime.minute
            components.second = 0

            guard let candidate = calendar.date(from: components) else { continue }

            if candidate > now {
                return candidate
            }
        }

        if repeatUnit != .none,
           let nextRepeatDate = nextRepeatDateAfterCurrentReminderDate() {
            let firstFireTime = sortedFireTimes.first ?? (hour: reminderHour, minute: reminderMinute)
            var components = calendar.dateComponents([.year, .month, .day], from: nextRepeatDate)
            components.hour = firstFireTime.hour
            components.minute = firstFireTime.minute
            components.second = 0

            return calendar.date(from: components) ?? scheduledDate
        }

        return scheduledDate
    }

    private func allCurrentFireTimes() -> [(hour: Int, minute: Int)] {
        var fireTimes: [(hour: Int, minute: Int)] = [
            (hour: reminderHour, minute: reminderMinute)
        ]

        fireTimes.append(contentsOf: additionalFireTimes.map { additionalTime in
            (hour: additionalTime.hour, minute: additionalTime.minute)
        })

        return fireTimes
            .reduce(into: [(hour: Int, minute: Int)]()) { uniqueTimes, fireTime in
                guard !uniqueTimes.contains(where: { $0.hour == fireTime.hour && $0.minute == fireTime.minute }) else { return }
                uniqueTimes.append(fireTime)
            }
            .sorted { lhs, rhs in
                if lhs.hour == rhs.hour {
                    return lhs.minute < rhs.minute
                }
                return lhs.hour < rhs.hour
            }
    }

    private func nextRepeatDateAfterCurrentReminderDate() -> Date? {
        let calendar = Calendar.current
        let interval = max(1, repeatInterval)

        switch repeatUnit {
        case .none:
            return nil
        case .minutes, .hours:
            return calendar.date(byAdding: .day, value: 1, to: reminderDate)
        case .days:
            return calendar.date(byAdding: .day, value: interval, to: reminderDate)
        case .weeks:
            if !repeatWeekdays.isEmpty {
                let todayStart = calendar.startOfDay(for: reminderDate)

                for dayOffset in 1...14 {
                    guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
                    let weekday = calendar.component(.weekday, from: candidate)

                    if repeatWeekdays.contains(weekday) {
                        return candidate
                    }
                }
            }

            return calendar.date(byAdding: .weekOfYear, value: interval, to: reminderDate)
        case .months:
            return calendar.date(byAdding: .month, value: interval, to: reminderDate)
        case .years:
            return calendar.date(byAdding: .year, value: interval, to: reminderDate)
        }
    }

    private func scheduleKey(for reminder: LureliaReminder) -> String {
        let primaryHour = reminder.primaryHour != -1
            ? reminder.primaryHour
            : Calendar.current.component(.hour, from: reminder.scheduledDate)

        let primaryMinute = reminder.primaryHour != -1
            ? reminder.primaryMinute
            : Calendar.current.component(.minute, from: reminder.scheduledDate)

        let normalizedAdditionalTimes = reminder.additionalFireTimes
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            .sorted()
            .joined(separator: ",")

        let normalizedWeekdays = reminder.repeatWeekdays
            .sorted()
            .map(String.init)
            .joined(separator: ",")

        let endDateKey = reminder.repeatEndsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "none"

        return [
            String(Int(reminder.scheduledDate.timeIntervalSince1970)),
            String(format: "%02d:%02d", primaryHour, primaryMinute),
            normalizedAdditionalTimes,
            reminder.repeatUnit.rawValue,
            String(max(1, reminder.repeatInterval)),
            normalizedWeekdays,
            endDateKey
        ].joined(separator: "|")
    }
}

// MARK: - CLPlacemark Address Helper

extension CLPlacemark {
    var formattedAddress: String? {
        let parts = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            postalCode
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
