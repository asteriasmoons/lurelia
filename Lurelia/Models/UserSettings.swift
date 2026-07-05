//
//  UserSettings.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool = false
    
    // MARK: - Categories
    
    var selectedCategoriesStorage: Data?
    
    // MARK: - Starter Routines
    
    var selectedStarterRoutinesStorage: Data?
    
    // MARK: - Preferences
    
    var autoClearTasks: Bool = false
    var notificationsEnabled: Bool = false
    var hideCompletedReminders: Bool = false
    
    // MARK: - Coins
    
    var coinBalance: Int = 0
    
    // MARK: - Profile
    
    @Attribute(.externalStorage)
    var profileImageData: Data?
    
    // MARK: - Dates
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Init
    
    init(
        hasCompletedOnboarding: Bool = false,
        selectedCategories: [String] = [],
        selectedStarterRoutines: [String] = [],
        autoClearTasks: Bool = false,
        notificationsEnabled: Bool = false,
        hideCompletedReminders: Bool = false,
        coinBalance: Int = 0,
        profileImageData: Data? = nil
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedCategories = selectedCategories
        self.selectedStarterRoutines = selectedStarterRoutines
        self.autoClearTasks = autoClearTasks
        self.notificationsEnabled = notificationsEnabled
        self.hideCompletedReminders = hideCompletedReminders
        self.coinBalance = coinBalance
        self.createdAt = Date()
        self.updatedAt = Date()
        self.profileImageData = profileImageData
    }
}

// MARK: - Codable Helpers

extension UserSettings {
    
    var selectedCategories: [String] {
        get {
            guard
                let data = selectedCategoriesStorage,
                let decoded = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            
            return decoded
        }
        set {
            selectedCategoriesStorage = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
    
    var selectedStarterRoutines: [String] {
        get {
            guard
                let data = selectedStarterRoutinesStorage,
                let decoded = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            
            return decoded
        }
        set {
            selectedStarterRoutinesStorage = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}
