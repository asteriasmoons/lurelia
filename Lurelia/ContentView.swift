//
//  ContentView.swift
//  Lurelia
//
//  Created by Asteria Moon on 5/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    var body: some View {
        ZStack {
            if let userSettings = settings.first {
                if userSettings.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                OnboardingView()
                    .onAppear {
                        createSettingsIfNeeded()
                    }
            }
        }
    }

    private func createSettingsIfNeeded() {
        guard settings.isEmpty else { return }

        let newSettings = UserSettings()
        modelContext.insert(newSettings)

        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}
