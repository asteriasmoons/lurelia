//
//  OnboardingView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var settings: [UserSettings]
    @Query private var routines: [LureliaRoutine]
    
    @State private var currentPage = 0
    
    @State private var selectedCategories: Set<String> = []
    @State private var selectedRoutines: Set<String> = []
    
    @State private var notificationsGranted = false
    
    private let totalPages = 5
    
    // MARK: - Categories
    
    private let categories: [(icon: String, title: String)] = [
        ("health", "Health"),
        ("dumbbell", "Fitness"),
        ("houseoutline", "Home"),
        ("briefcase.fill", "Work"),
        ("book.fill", "Study"),
        ("heartfill", "Care"),
        ("crystalball", "Spirituality"),
        ("chatsparkle", "Relationships"),
        ("walletfill", "Finances"),
        ("sparkle", "Intention"),
        ("bolt", "Productivity"),
        ("flame", "Habits"),
        ("towel", "Hygiene"),
        ("clock.arrow.circlepath", "Routines"),
        ("artboard", "Creativity")
    ]
    
    // MARK: - Starter Routines
    
    private var starterRoutines: [LureliaStarterRoutine] {
        RoutinesBank.all
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            VStack(spacing: 0) {
                topBar
                
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    categoryPage.tag(1)
                    routinePage.tag(2)
                    permissionsPage.tag(3)
                    completionPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth(duration: 0.35), value: currentPage)
            }
        }
    }
}

// MARK: - Top Bar

extension OnboardingView {
    
    private var topBar: some View {
        VStack(spacing: 18) {
            HStack {
                if currentPage > 0 {
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            currentPage -= 1
                        }
                    } label: {
                        Image("chevleft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(12)
                            .background(LColors.glassSurface)
                            .clipShape(Circle())
                    }
                } else {
                    Color.clear.frame(width: 42, height: 42)
                }
                
                Spacer()
                
                Text("LURELIA")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(LGradients.header)
                
                Spacer()
                
                Color.clear.frame(width: 42, height: 42)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(
                            index <= currentPage
                            ? AnyShapeStyle(LGradients.header)
                            : AnyShapeStyle(Color.white.opacity(0.12))
                        )
                        .frame(
                            width: index == currentPage ? 34 : 10,
                            height: 10
                        )
                        .animation(.spring(duration: 0.25), value: currentPage)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }
}

// MARK: - Welcome

extension OnboardingView {
    
    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LColors.glassSurface)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .stroke(LColors.glassBorderStrong, lineWidth: 1)
                    .frame(width: 160, height: 160)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 58))
                    .foregroundStyle(LGradients.header)
            }
            
            VStack(spacing: 14) {
                Text("Welcome to\nLurelia")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("Organize reminders, routines, schedules, and recurring life tasks in one intentional space.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            continueButton(title: "Begin") {
                currentPage = 1
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

// MARK: - Categories

extension OnboardingView {
    
    private var categoryPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: 30)
                
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(LGradients.header)
                    
                    Text("Choose Your\nCategories")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Select the areas of life you want to organize inside Lurelia.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 14
                ) {
                    ForEach(categories, id: \.title) { category in
                        categoryCard(category)
                    }
                }
                
                continueButton(title: "Continue") {
                    currentPage = 2
                }
                .disabled(selectedCategories.isEmpty)
                .opacity(selectedCategories.isEmpty ? 0.45 : 1)
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func categoryCard(_ category: (icon: String, title: String)) -> some View {
        let isSelected = selectedCategories.contains(category.title)
        
        return Button {
            if isSelected {
                selectedCategories.remove(category.title)
            } else {
                selectedCategories.insert(category.title)
            }
        } label: {
            VStack(spacing: 14) {
                Group {
                    if UIImage(named: category.icon) != nil {
                        Image(category.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: category.icon)
                            .font(.system(size: 30))
                    }
                }
                .foregroundStyle(
                    isSelected
                    ? AnyShapeStyle(.white)
                    : AnyShapeStyle(LGradients.header)
                )
                
                Text(category.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LGradients.header)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LColors.glassSurface)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.clear
                        : LColors.glassBorder,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Routines

extension OnboardingView {
    
    private var routinePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: 30)
                
                VStack(spacing: 10) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(LGradients.header)
                    
                    Text("Starter\nRoutines")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Optional routines to help you get started faster.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 14) {
                    ForEach(starterRoutines, id: \.id) { routine in
                        routineCard(routine)
                    }
                }
                
                VStack(spacing: 12) {
                    continueButton(title: "Continue") {
                        currentPage = 3
                    }
                    
                    Button {
                        currentPage = 3
                    } label: {
                        Text("Skip For Now")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func routineCard(_ routine: LureliaStarterRoutine) -> some View {
        let isSelected = selectedRoutines.contains(routine.id)
        
        return Button {
            if isSelected {
                selectedRoutines.remove(routine.id)
            } else {
                selectedRoutines.insert(routine.id)
            }
        } label: {
            HStack(spacing: 16) {
                Group {
                    if UIImage(named: routine.icon) != nil {
                        Image(routine.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: routine.icon)
                            .font(.system(size: 24))
                    }
                }
                .foregroundStyle(
                    isSelected
                    ? AnyShapeStyle(.white)
                    : AnyShapeStyle(LGradients.header)
                )
                .frame(width: 34)
                
                Text(routine.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Circle()
                    .fill(
                        isSelected
                        ? AnyShapeStyle(.white)
                        : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(LGradients.header)
                                .frame(width: 12, height: 12)
                        }
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LGradients.header.opacity(0.9))
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LColors.glassSurface)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        isSelected
                        ? Color.clear
                        : LColors.glassBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions

extension OnboardingView {
    
    private var permissionsPage: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LColors.glassSurface)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .stroke(LColors.glassBorderStrong, lineWidth: 1)
                    .frame(width: 160, height: 160)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LGradients.header)
            }
            
            VStack(spacing: 14) {
                Text("Stay In Sync")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Lurelia uses notifications to help keep your reminders and routines visible throughout your day.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 14) {
                continueButton(
                    title: notificationsGranted
                    ? "Notifications Enabled"
                    : "Enable Notifications"
                ) {
                    requestNotifications()
                }
                
                Button {
                    currentPage = 4
                } label: {
                    Text("Maybe Later")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
                currentPage = 4
            }
        }
    }
}

// MARK: - Completion

extension OnboardingView {
    
    private var completionPage: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LColors.glassSurface)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .stroke(LColors.glassBorderStrong, lineWidth: 1)
                    .frame(width: 180, height: 180)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(LGradients.header)
            }
            
            VStack(spacing: 14) {
                Text("Your Space\nIs Ready")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your selected categories have been prepared and your task space is ready to customize.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            continueButton(title: "Enter Lurelia") {
                completeOnboarding()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private func completeOnboarding() {
        let userSettings: UserSettings
        
        if let existing = settings.first {
            userSettings = existing
        } else {
            userSettings = UserSettings()
            modelContext.insert(userSettings)
        }
        
        userSettings.hasCompletedOnboarding = true
        userSettings.selectedCategories = Array(selectedCategories)
        userSettings.selectedStarterRoutines = Array(selectedRoutines)
        createSelectedStarterRoutines()
        userSettings.notificationsEnabled = notificationsGranted
        
        try? modelContext.save()
    }

    private func createSelectedStarterRoutines() {
        let selectedStarterRoutineTemplates = RoutinesBank.all.filter { starterRoutine in
            selectedRoutines.contains(starterRoutine.id)
        }

        for starterRoutine in selectedStarterRoutineTemplates {
            guard routines.contains(where: { $0.starterRoutineID == starterRoutine.id }) == false else {
                continue
            }

            let routine = LureliaRoutine(
                name: starterRoutine.title,
                icon: starterRoutine.icon,
                timeOfDay: .anytime,
                scheduleEnabled: false,
                sortOrder: routines.count
            )

            routine.persistentID = "starter-routine::\(starterRoutine.id)"
            routine.starterRoutineID = starterRoutine.id
            routine.colorHex = starterRoutine.colorHex
            routine.createdAt = Date()
            routine.updatedAt = Date()

            modelContext.insert(routine)

            for taskIndex in starterRoutine.tasks.indices {
                let starterTask = starterRoutine.tasks[taskIndex]
                let task = LureliaRoutineTask(
                    title: starterTask.title,
                    notes: starterTask.notes ?? "",
                    sortOrder: taskIndex,
                    isFromBank: true,
                    bankTaskID: "starter-routine::\(starterRoutine.id)::task::\(taskIndex)"
                )

                task.stableTaskID = "starter-routine::\(starterRoutine.id)::task::\(taskIndex)"
                task.routine = routine
                task.createdAt = Date()
                task.updatedAt = Date()

                modelContext.insert(task)
            }
        }
    }
}

// MARK: - Continue Button

extension OnboardingView {
    
    private func continueButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LGradients.header)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(
                color: LColors.gradientPurple.opacity(0.25),
                radius: 18,
                y: 10
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}
