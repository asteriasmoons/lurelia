//
//  MainTabView.swift
//  Lurelia

import SwiftUI
import SwiftData

struct RoutineWrapper: Identifiable {
    let id = UUID()
    let routine: LureliaRoutine
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var activeRoutineToOpen: RoutineWrapper?
    
    @Query private var routineRuns: [LureliaRoutineRun]
    
    private var activeRoutineRun: LureliaRoutineRun? {
        routineRuns.first { $0.endedAt == nil }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background behind everything
            LureliaBackgroundAlt()
            
            TabView(selection: $selectedTab) {
                RemindersView()
                    .tag(0)
                
                ScheduleView()
                    .tag(1)
                
                HabitsView()
                .tag(2)
                
                TasksView()
                    .tag(3)
                
                RoutinesView()
                    .tag(4)
                
                ProfileView()
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Push content up so it does not hide behind the floating tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 120)
            }
            
            VStack(spacing: 12) {
                if let activeRoutineRun {
                    ActiveRoutineBanner(run: activeRoutineRun) {
                        if let routine = activeRoutineRun.routine {
                            activeRoutineToOpen = RoutineWrapper(routine: routine)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                LureliaTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(item: $activeRoutineToOpen) { wrapper in
            RoutineRunView(routine: wrapper.routine)
        }
    }
}

// MARK: - Floating Tab Bar

struct LureliaTabBar: View {
    @Binding var selectedTab: Int
    
    struct TabItem {
        let assetName: String?
        let sfName: String?
    }
    
    let tabs: [TabItem] = [
        TabItem(assetName: "bellfill", sfName: nil),
        TabItem(assetName: "starcal", sfName: nil),
        TabItem(assetName: "clockfill", sfName: nil),
        TabItem(assetName: "checkwavy", sfName: nil),
        TabItem(assetName: nil, sfName: "wand.and.stars"),
        TabItem(assetName: "profilewavy", sfName: nil)
    ]
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            
            HStack(spacing: 18) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    let tab = tabs[index]
                    let isSelected = selectedTab == index
                    
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            selectedTab = index
                        }
                    } label: {
                        VStack(spacing: 0) {
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    LColors.gradientBlue.opacity(0.35),
                                                    LColors.gradientPurple.opacity(0.35)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 42, height: 32)
                                }
                                
                                Group {
                                    if let asset = tab.assetName {
                                        Image(asset)
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                    } else if let sf = tab.sfName {
                                        Image(systemName: sf)
                                            .font(.system(size: 21, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(
                                    isSelected
                                    ? LinearGradient(
                                        colors: [
                                            LColors.gradientBlue,
                                            LColors.gradientPurple
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.42),
                                            Color.white.opacity(0.42)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            }
                            .frame(width: 42, height: 34)
                        }
                        .frame(width: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(LColors.bg.opacity(0.72))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.05),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.98),
                                        LColors.gradientPurple.opacity(0.98),
                                        Color.white.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.35
                            )
                    )
                    .shadow(color: LColors.gradientBlue.opacity(0.22), radius: 18, y: 8)
                    .shadow(color: .black.opacity(0.32), radius: 18, y: 10)
            )
            .clipShape(Capsule(style: .continuous))
            .fixedSize(horizontal: true, vertical: false)
            
            Spacer(minLength: 0)
        }
        .padding(.bottom, 42)
    }
}

// MARK: - Placeholder Tab View

struct PlaceholderTabView: View {
    let icon: String
    let title: String
    var isSF: Bool = false
    
    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            
            VStack(spacing: 16) {
                if isSF {
                    Image(systemName: icon)
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue,
                                    LColors.gradientPurple
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue,
                                    LColors.gradientPurple
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Coming soon")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
