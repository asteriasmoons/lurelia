//
//  CreateCustomTaskView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct CreateCustomTaskView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var settings: [UserSettings]
    @Query private var allTasks: [LureliaTask]
    
    var onCreated: ((LureliaTask) -> Void)? = nil
    
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedCategory = ""
    @State private var coinReward = 10
    
    @State private var addToToday = true
    @State private var showDuplicateWarning = false
    
    // MARK: - Settings
    
    var userSettings: UserSettings? {
        settings.first
    }
    
    var userCategories: [String] {
        let selected = userSettings?.selectedCategories ?? []
        
        if selected.isEmpty {
            return LureliaTaskBank.categories
        }
        
        return selected.sorted()
    }
    
    // MARK: - Validation
    
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedNotes: String? {
        let clean = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
    
    var isDuplicate: Bool {
        allTasks.contains {
            $0.title.localizedCaseInsensitiveCompare(trimmedTitle) == .orderedSame
            && $0.category == selectedCategory
        }
    }
    
    var canSave: Bool {
        !trimmedTitle.isEmpty
        && !selectedCategory.isEmpty
    }

    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    // MARK: - Header
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Task")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Create a task for your routines and schedules.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundStyle(LGradients.header)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // MARK: - Preview Card
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LGradients.header)
                                    .frame(width: 52, height: 52)
                                
                                Image("checkwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trimmedTitle.isEmpty ? "Your Task" : trimmedTitle)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text(
                                    selectedCategory.isEmpty
                                    ? "No category selected"
                                    : selectedCategory
                                )
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.gradientBlue)
                            }
                            
                            Spacer()

                            coinRewardChip
                        }
                        
                        if let notes = trimmedNotes {
                            Text(notes)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(18)
                    .background(LColors.glassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
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
                    .padding(.horizontal, 24)
                    
                    // MARK: - Task Name
                    
                    LureliaFormSection(title: "Task Name") {
                        TextField(
                            "What do you need to do?",
                            text: $title
                        )
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
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
                    }
                    
                    // MARK: - Notes
                    
                    LureliaFormSection(title: "Notes (optional)") {
                        TextField(
                            "Add extra details if needed",
                            text: $notes,
                            axis: .vertical
                        )
                        .lineLimit(4, reservesSpace: true)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
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
                    }
                    
                    // MARK: - Categories
                    // MARK: - Coin Reward

                    LureliaFormSection(title: "Coin Reward") {
                        HStack(spacing: 14) {
                            coinRewardChip

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Coins earned when completed")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text("Custom tasks can have their own reward amount.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            Spacer()

                            Stepper("", value: $coinReward, in: 0...100, step: 5)
                                .labelsHidden()
                                .tint(LColors.gradientBlue)
                        }
                        .padding(14)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
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
                    }
                    
                    LureliaFormSection(title: "Category") {
                        if userCategories.isEmpty {
                            Text("No categories available.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        } else {
                            TagFlowLayout(spacing: 8) {
                                ForEach(userCategories, id: \.self) { category in
                                    Button {
                                        selectedCategory = category
                                    } label: {
                                        Text(category)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(
                                                selectedCategory == category
                                                ? .white
                                                : .white.opacity(0.6)
                                            )
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(
                                                selectedCategory == category
                                                ? AnyShapeStyle(LGradients.header)
                                                : AnyShapeStyle(Color.white.opacity(0.08))
                                            )
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(
                                                        selectedCategory == category
                                                        ? Color.clear
                                                        : Color.white.opacity(0.12),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Add To Today
                    
                    LureliaFormSection(title: "Task Visibility") {
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                addToToday.toggle()
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            addToToday
                                            ? AnyShapeStyle(LGradients.header)
                                            : AnyShapeStyle(Color.white.opacity(0.08))
                                        )
                                        .frame(width: 24, height: 24)
                                    
                                    if addToToday {
                                        Image("checkwavy")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 11, height: 11)
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Add to today’s task list")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    
                                    Text("The task will immediately appear in your active tasks.")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                            }
                            .padding(14)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
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
                        }
                        .buttonStyle(.plain)
                    }

                    
                    // MARK: - Duplicate Warning
                    
                    if isDuplicate && canSave {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            
                            Text("A task with this name already exists in this category.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                    }
                    
                    // MARK: - Create Button
                    
                    Button {
                        save()
                    } label: {
                        HStack(spacing: 10) {
                            Image("addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)
                            
                            Text("Create Task")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(LGradients.header)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(
                            color: LColors.gradientPurple.opacity(0.25),
                            radius: 18,
                            y: 10
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || isDuplicate)
                    .opacity((!canSave || isDuplicate) ? 0.45 : 1)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .onAppear {
            if selectedCategory.isEmpty {
                selectedCategory = userCategories.first ?? ""
            }
        }
    }
    
    // MARK: - Coin Reward Chip

    private var coinRewardChip: some View {
        HStack(spacing: 4) {
            Image("sparkle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)

            Text("+\(coinReward)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color(lureliaHex: "#ffe6a3"))
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(Color(lureliaHex: "#5a3b12").opacity(0.42))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(lureliaHex: "#ffd36a").opacity(0.55), lineWidth: 1)
        )
    }

    // MARK: - Save
    
    func save() {
        guard canSave else { return }
        guard !isDuplicate else { return }
        
        let task = LureliaTask(
            title: trimmedTitle,
            category: selectedCategory,
            notes: trimmedNotes,
            coinReward: coinReward
        )
        
        task.isCustom = true
        task.isActive = true
        
        if addToToday {
            task.isSelectedToday = true
            task.selectedDate = Date()
        }
        
        context.insert(task)
        
        
        try? context.save()
        onCreated?(task)
        dismiss()
    }
}

// MARK: - Form Section

struct LureliaFormSection<Content: View>: View {
    let title: String
    
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
            
            content
        }
        .padding(.horizontal, 24)
    }
}
