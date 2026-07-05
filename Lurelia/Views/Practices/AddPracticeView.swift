//
//  AddPracticeView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct AddPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \LureliaPractice.sortOrder)
    private var practices: [LureliaPractice]
    
    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]
    
    var editingPractice: LureliaPractice? = nil
    
    // MARK: - State
    
    @State private var title = ""
    @State private var purpose = ""
    @State private var descriptionText = ""
    @State private var selectedColor: Color = LColors.gradientPurple
    @State private var selectedIcon = "sparkle"
    @State private var showIconPicker = false
    @State private var principles: [String] = []
    @State private var newPrinciple = ""
    @State private var linkedRoutineIDs: Set<String> = []
    
    private var isEditing: Bool {
        editingPractice != nil
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Adaptive Colors
    
    private var practiceTint: Color {
        selectedColor
    }
    
    private var adaptiveTextColor: Color {
        practiceTint.isLightColor ? .black.opacity(0.88) : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        practiceTint.isLightColor ? .black.opacity(0.62) : .white.opacity(0.72)
    }
    
    private var availableRoutines: [LureliaRoutine] {
        let practiceIDString = editingPractice?.id.uuidString
        return routines.filter { routine in
            routine.practiceID == nil ||
            routine.practiceID == practiceIDString
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        
                        // MARK: - Custom Header
                        
                        customHeader
                        
                        // MARK: - Live Preview Card
                        
                        livePreviewCard
                        
                        // MARK: - Title
                        
                        fieldCard(title: "Practice Name") {
                            TextField("e.g. Morning Wellness", text: $title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        // MARK: - Purpose
                        
                        fieldCard(title: "Purpose") {
                            TextField("Why this practice exists...", text: $purpose, axis: .vertical)
                                .lineLimit(2, reservesSpace: true)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        // MARK: - Description
                        
                        fieldCard(title: "Description") {
                            TextField("What this practice covers...", text: $descriptionText, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        // MARK: - Color
                        
                        fieldCard(title: "Color") {
                            HStack(spacing: 14) {
                                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 44, height: 44)
                                
                                Text("Tap to pick a color")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
                        
                        // MARK: - Icon
                        
                        fieldCard(title: "Icon") {
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
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
                        
                        // MARK: - Principles
                        
                        fieldCard(title: "Principles") {
                            VStack(spacing: 10) {
                                if !principles.isEmpty {
                                    ForEach(principles.indices, id: \.self) { index in
                                        HStack(spacing: 10) {
                                            Text("\(index + 1).")
                                                .font(.system(size: 14, weight: .black, design: .rounded))
                                                .foregroundStyle(LColors.textSecondary)
                                                .frame(width: 24)
                                            
                                            Text(principles[index])
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(LColors.textPrimary)
                                            
                                            Spacer()
                                            
                                            Button {
                                                principles.remove(at: index)
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
                                        
                                        if index < principles.count - 1 {
                                            Divider()
                                                .overlay(LColors.glassBorder)
                                        }
                                    }
                                    
                                    Divider()
                                        .overlay(LColors.glassBorder)
                                }
                                
                                HStack(spacing: 10) {
                                    TextField("e.g. Progress over perfection", text: $newPrinciple)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(LColors.textPrimary)
                                    
                                    Button {
                                        let trimmed = newPrinciple
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmed.isEmpty else { return }
                                        principles.append(trimmed)
                                        newPrinciple = ""
                                    } label: {
                                        Image("addwavy")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)
                                            .foregroundStyle(LGradients.header)
                                            .frame(width: 32, height: 32)
                                            .background(LColors.glassSurface2, in: Circle())
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(
                                        newPrinciple
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                            .isEmpty
                                    )
                                }
                            }
                        }
                        
                        // MARK: - Link Routines
                        
                        fieldCard(title: "Routines") {
                            VStack(spacing: 10) {
                                if availableRoutines.isEmpty {
                                    Text("No routines available to link.")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(LColors.textSecondary)
                                } else {
                                    ForEach(availableRoutines) { routine in
                                        let isLinked = linkedRoutineIDs.contains(routine.persistentID)
                                        
                                        Button {
                                            if isLinked {
                                                linkedRoutineIDs.remove(routine.persistentID)
                                            } else {
                                                linkedRoutineIDs.insert(routine.persistentID)
                                            }
                                        } label: {
                                            HStack(spacing: 12) {
                                                LureliaIconView(iconId: routine.icon, size: 18)
                                                    .foregroundStyle(
                                                        Color(lureliaHex: routine.colorHex)
                                                    )
                                                
                                                Text(routine.name)
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundStyle(LColors.textPrimary)
                                                
                                                Spacer()
                                                
                                                Image(isLinked ? "checkwavy" : "addwavy")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundStyle(
                                                        isLinked
                                                        ? AnyShapeStyle(LGradients.header)
                                                        : AnyShapeStyle(LColors.textSecondary)
                                                    )
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if routine.id != availableRoutines.last?.id {
                                            Divider()
                                                .overlay(LColors.glassBorder)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Save Button
                        
                        saveButton
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showIconPicker) {
                LureliaIconPickerView(selectedIcon: $selectedIcon)
            }
        }
        .onAppear {
            populate()
        }
    }
    
    // MARK: - Custom Header
    
    private var customHeader: some View {
        HStack(spacing: 12) {
            Text(isEditing ? "Edit Practice" : "New Practice")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
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
                    .background(practiceTint, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Live Preview Card
    
    private var livePreviewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(adaptiveTextColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                LureliaIconView(iconId: selectedIcon, size: 20)
                    .foregroundStyle(adaptiveTextColor)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "Practice Name" : title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(adaptiveTextColor)
                    .lineLimit(1)
                
                if !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(purpose)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(adaptiveSecondaryTextColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(
                        adaptiveTextColor.opacity(0.15),
                        style: StrokeStyle(lineWidth: 2.5, dash: [3, 3])
                    )
                    .frame(width: 36, height: 36)
                
                Text("0%")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(adaptiveTextColor)
            }
            .frame(width: 36, height: 36)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(practiceTint)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(adaptiveTextColor.opacity(0.12), lineWidth: 1)
                }
        }
        .shadow(color: practiceTint.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Field Card
    
    private func fieldCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            
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
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(isEditing ? "Save Practice" : "Create Practice")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(canSave ? adaptiveTextColor : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canSave ? practiceTint : Color.white.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }
    
    // MARK: - Populate
    
    private func populate() {
        guard let practice = editingPractice else { return }
        
        title = practice.title
        purpose = practice.purpose
        descriptionText = practice.descriptionText
        selectedColor = Color(lureliaHex: practice.colorHex)
        selectedIcon = practice.icon
        principles = practice.principles
        
        let practiceIDString = practice.id.uuidString
        linkedRoutineIDs = Set(
            routines
                .filter { $0.practiceID == practiceIDString }
                .map { $0.persistentID }
        )
    }
    
    // MARK: - Save
    
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let colorHex = selectedColor.toLureliaHex() ?? "#7d19f7"
        
        if let existing = editingPractice {
            existing.title = trimmed
            existing.icon = selectedIcon
            existing.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.colorHex = colorHex
            existing.principles = principles
            existing.updatedAt = Date()
            
            let practiceIDString = existing.id.uuidString
            for routine in routines where routine.practiceID == practiceIDString {
                routine.practiceID = nil
                routine.updatedAt = Date()
            }
            
            for routine in routines where linkedRoutineIDs.contains(routine.persistentID) {
                routine.practiceID = practiceIDString
                routine.updatedAt = Date()
            }
        } else {
            let practice = LureliaPractice(
                title: trimmed,
                icon: selectedIcon,
                purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: colorHex,
                sortOrder: practices.count
            )
            practice.principles = principles
            
            modelContext.insert(practice)
            
            let practiceIDString = practice.id.uuidString
            for routine in routines where linkedRoutineIDs.contains(routine.persistentID) {
                routine.practiceID = practiceIDString
                routine.updatedAt = Date()
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
}
