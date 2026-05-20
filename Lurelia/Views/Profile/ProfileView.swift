//
//  ProfileView.swift
//  Lurelia
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var settings: [UserSettings]
    @Query private var reminders: [LureliaReminder]
    
    @State private var showGoalSettings = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showOnboardingResetConfirmation = false
    @State private var showCoinsPage = false
    
    private var userSettings: UserSettings? {
        settings.first
    }
    
    private var selectedCategories: [String] {
        (userSettings?.selectedCategories ?? []).sorted()
    }
    
    private var selectedRoutines: [String] {
        (userSettings?.selectedStarterRoutines ?? []).sorted()
    }

    private var coinBalance: Int {
        userSettings?.coinBalance ?? 0
    }
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    
                    // MARK: - Header
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Button {
                            showCoinsPage = true
                        } label: {
                            HStack(spacing: 6) {
                                Image("sparkle")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)

                                Text("\(coinBalance)")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(Color(lureliaHex: "#ffe6a3"))
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(
                                Capsule()
                                    .fill(Color(lureliaHex: "#5a3b12").opacity(0.42))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(lureliaHex: "#ffd36a").opacity(0.55), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    reminderStreakCard
                        .padding(.horizontal, 24)
                    
                    // MARK: - Profile Card
                    
                    profileCard
                        .padding(.horizontal, 24)
                    
                    categoriesCard
                        .padding(.horizontal, 24)
                    
                    routinesCard
                        .padding(.horizontal, 24)

                    devControlsCard
                        .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 110)
                }
            }
            
            if showPhotoSourceDialog {
                photoSourcePopup
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(10)
            }

            if showOnboardingResetConfirmation {
                onboardingResetPopup
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .sheet(isPresented: $showGoalSettings) {
            ProfileGoalSettingsSheet()
        }
        .fullScreenCover(isPresented: $showCoinsPage) {
            LureliaCoinsView()
        }
        .sheet(isPresented: $showCamera) {
            LureliaImagePicker(sourceType: .camera) { image in
                saveProfileImage(image)
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) {
            Task {
                guard let item = selectedPhotoItem else { return }
                
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    saveProfileImage(image)
                }
            }
        }
    }

    private var photoSourcePopup: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.22)) {
                        showPhotoSourceDialog = false
                    }
                }
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LColors.glassSurface2)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(LGradients.header)
                }
                
                VStack(spacing: 5) {
                    Text("Profile Photo")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Choose a source for your profile picture.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showPhotoSourceDialog = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            showPhotoPicker = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("Choose From Gallery")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(LGradients.header)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showPhotoSourceDialog = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            showCamera = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("Use Camera")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(LColors.glassSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showPhotoSourceDialog = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(lureliaHex: "#10101A").opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.42),
                                LColors.gradientPurple.opacity(0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
    
    private var onboardingResetPopup: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.22)) {
                        showOnboardingResetConfirmation = false
                    }
                }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.red.opacity(0.92))
                }

                VStack(spacing: 5) {
                    Text("Reset Onboarding?")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("This will mark onboarding as incomplete so you can go through it again. Your profile photo and other saved profile details will stay intact.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        resetOnboardingState()

                        withAnimation(.spring(duration: 0.22)) {
                            showOnboardingResetConfirmation = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))

                            Text("Reset Onboarding")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Color.red.opacity(0.32))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.48), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            showOnboardingResetConfirmation = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(lureliaHex: "#10101A").opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.42),
                                LColors.gradientPurple.opacity(0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
    
    private func saveProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            return
        }
        
        let userSettings: UserSettings
        
        if let existing = settings.first {
            userSettings = existing
        } else {
            userSettings = UserSettings()
            modelContext.insert(userSettings)
        }
        
        userSettings.profileImageData = data
        
        try? modelContext.save()
    }

    private func resetOnboardingState() {
        let userSettings: UserSettings

        if let existing = settings.first {
            userSettings = existing
        } else {
            userSettings = UserSettings()
            modelContext.insert(userSettings)
        }

        userSettings.hasCompletedOnboarding = false
        userSettings.selectedCategories = []
        userSettings.selectedStarterRoutines = []

        try? modelContext.save()
    }

    // MARK: - Reminder Streak Card

    private var reminderStreakCount: Int {
        let activeReminders = reminders.filter { $0.isEnabled }
        guard !activeReminders.isEmpty else { return 0 }

        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        while true {
            let dueFireCount = activeReminders.reduce(0) { total, reminder in
                total + fireTimes(for: reminder, on: day, calendar: calendar).count
            }

            guard dueFireCount > 0 else {
                break
            }

            let completedFireTotal = activeReminders.reduce(0) { total, reminder in
                total + completedFireCount(for: reminder, on: day, calendar: calendar)
            }

            if completedFireTotal >= dueFireCount {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previousDay
            } else {
                break
            }
        }

        return streak
    }

    private var remindersDueTodayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return reminders
            .filter { $0.isEnabled }
            .reduce(0) { total, reminder in
                total + fireTimes(for: reminder, on: today, calendar: calendar).count
            }
    }

    private var remindersCompletedTodayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return reminders
            .filter { $0.isEnabled }
            .reduce(0) { total, reminder in
                total + completedFireCount(for: reminder, on: today, calendar: calendar)
            }
    }

    private func completedFireCount(for reminder: LureliaReminder, on day: Date, calendar: Calendar) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        var count = reminder.completionTimestamps.filter {
            calendar.isDate($0, inSameDayAs: dayStart)
        }.count

        if count == 0,
           reminder.repeatUnit == .none,
           reminder.isCompleted,
           let completedAt = reminder.completedAt,
           calendar.isDate(completedAt, inSameDayAs: dayStart) {
            count = 1
        }

        return min(count, fireTimes(for: reminder, on: dayStart, calendar: calendar).count)
    }

    private func fireTimes(for reminder: LureliaReminder, on day: Date, calendar: Calendar) -> [Date] {
        guard reminder.isEnabled else { return [] }
        let dayStart = calendar.startOfDay(for: day)

        if reminder.repeatUnit == .none {
            let anchor = reminder.nextFireAt ?? reminder.scheduledDate
            guard calendar.isDate(anchor, inSameDayAs: dayStart) else { return [] }
            return resolvedTimesOfDay(for: reminder, on: dayStart, calendar: calendar)
        }

        if let nextFire = reminder.nextFireAt,
           !calendar.isDate(nextFire, inSameDayAs: dayStart) {
            return []
        }

        if !isRepeatingReminderDue(reminder, on: dayStart, calendar: calendar) {
            return []
        }

        return resolvedTimesOfDay(for: reminder, on: dayStart, calendar: calendar)
    }

    private func isRepeatingReminderDue(_ reminder: LureliaReminder, on day: Date, calendar: Calendar) -> Bool {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        guard reminder.scheduledDate <= endOfDay else { return false }

        switch reminder.repeatUnit {
        case .minutes, .hours, .days:
            return true

        case .weeks:
            if !reminder.repeatWeekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: day)
                return reminder.repeatWeekdays.contains(weekday)
            }
            return true

        case .months:
            let scheduledDay = calendar.component(.day, from: reminder.scheduledDate)
            let currentDay = calendar.component(.day, from: day)
            return scheduledDay == currentDay

        case .years:
            let scheduled = calendar.dateComponents([.month, .day], from: reminder.scheduledDate)
            let current = calendar.dateComponents([.month, .day], from: day)
            return scheduled.month == current.month && scheduled.day == current.day

        case .none:
            return false
        }
    }

    private func resolvedTimesOfDay(for reminder: LureliaReminder, on day: Date, calendar: Calendar) -> [Date] {
        var timeStrings = reminder.timesOfDay.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if timeStrings.isEmpty {
            if reminder.primaryHour != -1 {
                timeStrings.append(String(format: "%02d:%02d", reminder.primaryHour, reminder.primaryMinute))
            } else {
                let hour = calendar.component(.hour, from: reminder.scheduledDate)
                let minute = calendar.component(.minute, from: reminder.scheduledDate)
                timeStrings.append(String(format: "%02d:%02d", hour, minute))
            }

            for fireTime in reminder.additionalFireTimes {
                timeStrings.append(String(format: "%02d:%02d", fireTime.hour, fireTime.minute))
            }
        }

        var seen = Set<String>()

        return timeStrings.compactMap { rawValue -> Date? in
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = value.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { return nil }

            let normalized = String(format: "%02d:%02d", hour, minute)
            guard !seen.contains(normalized) else { return nil }
            seen.insert(normalized)

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }
        .sorted()
    }

    private var reminderStreakSubtitle: String {
        let activeReminders = reminders.filter { $0.isEnabled }
        let dueTodayCount = remindersDueTodayCount

        if activeReminders.isEmpty {
            return "Create reminders to start building your streak."
        }

        if dueTodayCount == 0 {
            return "No active reminder fire times are due today."
        }

        if reminderStreakCount == 0 {
            return "Complete all \(dueTodayCount) scheduled fire time\(dueTodayCount == 1 ? "" : "s") due today to begin a streak."
        }

        if reminderStreakCount == 1 {
            return "You completed every scheduled reminder fire time due today."
        }

        return "You completed every scheduled reminder fire time for \(reminderStreakCount) days in a row."
    }

    private var reminderStreakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LColors.gradientPurple.opacity(0.16))
                    .frame(width: 58, height: 58)

                Circle()
                    .fill(LColors.gradientBlue.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .blur(radius: 10)

                Image("flame")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(LGradients.header)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Reminder Streak")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(reminderStreakSubtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            VStack(spacing: 8) {
                streakStatBox(
                    value: remindersCompletedTodayCount,
                    label: "COMPLETED TODAY"
                )

                streakStatBox(
                    value: reminderStreakCount,
                    label: "STREAK TOTAL"
                )
            }
        }
        .padding(16)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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

    private func streakStatBox(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(LGradients.header)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 92, height: 48)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LColors.gradientBlue.opacity(0.65),
                            LColors.gradientPurple.opacity(0.65),
                            Color.white.opacity(0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }


    private var profileCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LColors.glassSurface)
                    .frame(width: 92, height: 92)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.18),
                                LColors.gradientPurple.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.65),
                                LColors.gradientPurple.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 92, height: 92)
                
                Group {
                    if let data = userSettings?.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image("profilewavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(
                                Circle()
                                    .fill(LGradients.header)
                            )
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            showPhotoSourceDialog = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(LGradients.header, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 92, height: 92)
            }
            
            VStack(spacing: 8) {
                Text("Your Lurelia Space")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Your chosen categories and starter goals help shape the reminders, tasks, and routines Lurelia shows you first.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showGoalSettings = true
            } label: {
                HStack(spacing: 8) {
                    Image("sparkle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    
                    Text("Edit Goals & Categories")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LGradients.header)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
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
    
    
    private var categoriesCard: some View {
        profileSectionCard(
            title: "Categories",
            icon: "tagsparkle"
        ) {
            if selectedCategories.isEmpty {
                emptyText("No categories selected yet.")
            } else {
                flowChips(selectedCategories)
            }
        }
    }
    
    private var routinesCard: some View {
        profileSectionCard(
            title: "Starter Routines",
            icon: "playwavy"
        ) {
            if selectedRoutines.isEmpty {
                emptyText("No starter routines selected yet.")
            } else {
                flowChips(selectedRoutines)
            }
        }
    }

    private var devControlsCard: some View {
        profileSectionCard(
            title: "Dev Controls",
            icon: "wrench.and.screwdriver.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Temporary testing controls for pre-release setup.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        showOnboardingResetConfirmation = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))

                        Text("Reset Onboarding State")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.opacity(0.24))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.42), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func profileSectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                iconView(icon, size: 18)
                    .foregroundStyle(LGradients.header)
                    .frame(width: 36, height: 36)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12))
                
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            content()
        }
        .padding(16)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 22))
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
    }
    
    private func flowChips(_ items: [String]) -> some View {
        FlexibleChipGrid(items: items)
    }
    
    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(.white.opacity(0.48))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func iconView(_ icon: String, size: CGFloat) -> some View {
        Group {
            if UIImage(named: icon) != nil {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
    }
}


// MARK: - Image Picker

struct LureliaImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: LureliaImagePicker
        
        init(_ parent: LureliaImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Goal Settings Sheet

struct ProfileGoalSettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var settings: [UserSettings]
    
    @State private var selectedCategories: Set<String> = []
    @State private var selectedRoutines: Set<String> = []
    
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
    
    private let starterRoutines: [(icon: String, title: String)] = [
        ("sun", "Morning Routine"),
        ("moonzs", "Evening Routine"),
        ("medication", "Medication Routine"),
        ("sparkle", "Self-Care Reset"),
        ("bookstand", "Study Session"),
        ("houseoutline", "Cleaning Reset")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        header
                        
                        categorySection
                        
                        routineSection
                        
                        saveButton
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            loadExistingSelections()
        }
    }
    
    private var header: some View {
        VStack(spacing: 10) {
            Image("goalsparkle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .foregroundStyle(LGradients.header)
            
            Text("Goals & Categories")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            Text("Choose the life areas and starter routines you want Lurelia to keep close.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Categories")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
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
        }
    }
    
    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Starter Goals")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            VStack(spacing: 14) {
                ForEach(starterRoutines, id: \.title) { routine in
                    routineCard(routine)
                }
            }
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
                iconView(category.icon, size: 32)
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
    
    private func routineCard(_ routine: (icon: String, title: String)) -> some View {
        let isSelected = selectedRoutines.contains(routine.title)
        
        return Button {
            if isSelected {
                selectedRoutines.remove(routine.title)
            } else {
                selectedRoutines.insert(routine.title)
            }
        } label: {
            HStack(spacing: 16) {
                iconView(routine.icon, size: 24)
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
    
    private var saveButton: some View {
        Button {
            saveSelections()
        } label: {
            HStack(spacing: 10) {
                Text("Save Changes")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                
                Image(systemName: "checkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(LGradients.header)
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
        .disabled(selectedCategories.isEmpty)
        .opacity(selectedCategories.isEmpty ? 0.45 : 1)
    }
    
    private func loadExistingSelections() {
        guard let settings = settings.first else { return }
        selectedCategories = Set(settings.selectedCategories)
        selectedRoutines = Set(settings.selectedStarterRoutines)
    }
    
    private func saveSelections() {
        let userSettings: UserSettings
        
        if let existing = settings.first {
            userSettings = existing
        } else {
            userSettings = UserSettings()
            modelContext.insert(userSettings)
        }
        
        userSettings.selectedCategories = Array(selectedCategories)
        userSettings.selectedStarterRoutines = Array(selectedRoutines)
        
        try? modelContext.save()
        dismiss()
    }
    
    private func iconView(_ icon: String, size: CGFloat) -> some View {
        Group {
            if UIImage(named: icon) != nil {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Flexible Chip Grid

struct FlexibleChipGrid: View {
    let items: [String]
    
    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.28),
                                LColors.gradientPurple.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(LColors.glassBorder, lineWidth: 1)
                    )
            }
        }
    }
}
