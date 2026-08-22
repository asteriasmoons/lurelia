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
    
    @State private var currentPage = 0
    
    @State private var notificationsGranted = false
    
    private let totalPages = 3
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            VStack(spacing: 0) {
                topBar
                
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    permissionsPage.tag(1)
                    completionPage.tag(2)
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
            
            GlassCard {
                Image(systemName: "sparkles")
                    .font(.system(size: 58))
                    .foregroundStyle(LGradients.header)
                    .frame(width: 160, height: 160)
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

// MARK: - Permissions

extension OnboardingView {
    
    private var permissionsPage: some View {
        VStack(spacing: 28) {
            Spacer()
            
            GlassCard {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LGradients.header)
                    .frame(width: 160, height: 160)
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
                    currentPage = 2
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
                currentPage = 2
            }
        }
    }
}

// MARK: - Completion

extension OnboardingView {
    
    private var completionPage: some View {
        VStack(spacing: 28) {
            Spacer()
            
            GlassCard {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(LGradients.header)
                    .frame(width: 180, height: 180)
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
        userSettings.shouldReplayOnboarding = false
        userSettings.notificationsEnabled = notificationsGranted
        
        try? modelContext.save()
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
            .foregroundStyle(Color.white.adaptivePrimaryText)
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
                color: Color.white.opacity(0.85).opacity(0.25),
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
