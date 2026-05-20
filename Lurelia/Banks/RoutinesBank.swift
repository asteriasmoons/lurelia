//
//  RoutinesBank.swift
//  Lurelia
//

import Foundation

struct LureliaStarterRoutine {
    let id: String
    let icon: String
    let title: String
    let colorHex: String
    let tasks: [LureliaStarterRoutineTask]
}

struct LureliaStarterRoutineTask {
    let title: String
    let notes: String?
    let estimatedMinutes: Int
}

enum RoutinesBank {
    
    static let all: [LureliaStarterRoutine] = [
        
        // MARK: - Morning Routine
        
        LureliaStarterRoutine(
            id: "morning-routine",
            icon: "sun",
            title: "Morning Routine",
            colorHex: "#F6B73C",
            tasks: [
                .init(
                    title: "Open the Blinds",
                    notes: "Let natural light into your space.",
                    estimatedMinutes: 1
                ),
                .init(
                    title: "Drink Water",
                    notes: "Hydrate before starting the day.",
                    estimatedMinutes: 2
                ),
                .init(
                    title: "Wash Face",
                    notes: "Quick refresh before getting ready.",
                    estimatedMinutes: 5
                ),
                .init(
                    title: "Brush Teeth",
                    notes: nil,
                    estimatedMinutes: 3
                ),
                .init(
                    title: "Make the Bed",
                    notes: "Small reset for the room and mind.",
                    estimatedMinutes: 4
                ),
                .init(
                    title: "Review Today’s Tasks",
                    notes: "Look over reminders and priorities.",
                    estimatedMinutes: 5
                )
            ]
        ),
        
        // MARK: - Evening Routine
        
        LureliaStarterRoutine(
            id: "evening-routine",
            icon: "moonzs",
            title: "Evening Routine",
            colorHex: "#6E5BFF",
            tasks: [
                .init(
                    title: "Tidy Main Space",
                    notes: "Quick reset before bed.",
                    estimatedMinutes: 10
                ),
                .init(
                    title: "Wash Face",
                    notes: "Night skincare and acne routine.",
                    estimatedMinutes: 8
                ),
                .init(
                    title: "Brush Teeth",
                    notes: nil,
                    estimatedMinutes: 3
                ),
                .init(
                    title: "Prepare Tomorrow’s Clothes",
                    notes: nil,
                    estimatedMinutes: 5
                ),
                .init(
                    title: "Plug In Devices",
                    notes: "Charge essentials overnight.",
                    estimatedMinutes: 2
                ),
                .init(
                    title: "Wind Down",
                    notes: "Relax before sleep.",
                    estimatedMinutes: 20
                )
            ]
        ),
        
        // MARK: - Medication Routine
        
        LureliaStarterRoutine(
            id: "medication-routine",
            icon: "medication",
            title: "Medication Routine",
            colorHex: "#45C1FF",
            tasks: [
                .init(
                    title: "Take Morning Medication",
                    notes: nil,
                    estimatedMinutes: 2
                ),
                .init(
                    title: "Log Medication",
                    notes: "Track doses and symptoms if needed.",
                    estimatedMinutes: 2
                ),
                .init(
                    title: "Refill Water Bottle",
                    notes: nil,
                    estimatedMinutes: 1
                ),
                .init(
                    title: "Take Evening Medication",
                    notes: nil,
                    estimatedMinutes: 2
                ),
                .init(
                    title: "Check Medication Supply",
                    notes: "Monitor refill timing.",
                    estimatedMinutes: 3
                )
            ]
        ),
        
        // MARK: - Self-Care Reset
        
        LureliaStarterRoutine(
            id: "self-care-reset",
            icon: "sparkle",
            title: "Self-Care Reset",
            colorHex: "#FF78C8",
            tasks: [
                .init(
                    title: "Light Stretching",
                    notes: "Gentle body movement.",
                    estimatedMinutes: 10
                ),
                .init(
                    title: "Drink Water",
                    notes: nil,
                    estimatedMinutes: 2
                ),
                .init(
                    title: "Take a Shower",
                    notes: nil,
                    estimatedMinutes: 20
                ),
                .init(
                    title: "Brush Hair",
                    notes: nil,
                    estimatedMinutes: 5
                ),
                .init(
                    title: "Journal Check-In",
                    notes: "Write down how you’re feeling.",
                    estimatedMinutes: 10
                ),
                .init(
                    title: "Do One Comfort Activity",
                    notes: "Something calming or emotionally supportive.",
                    estimatedMinutes: 20
                )
            ]
        ),
        
        // MARK: - Study Session
        
        LureliaStarterRoutine(
            id: "study-session",
            icon: "bookstand",
            title: "Study Session",
            colorHex: "#57D98C",
            tasks: [
                .init(
                    title: "Prepare Study Space",
                    notes: "Clear distractions and set up materials.",
                    estimatedMinutes: 5
                ),
                .init(
                    title: "Review Goals",
                    notes: "Decide what to focus on.",
                    estimatedMinutes: 3
                ),
                .init(
                    title: "Focused Study Block",
                    notes: "Main work session.",
                    estimatedMinutes: 45
                ),
                .init(
                    title: "Take a Break",
                    notes: "Step away and reset briefly.",
                    estimatedMinutes: 10
                ),
                .init(
                    title: "Review Notes",
                    notes: nil,
                    estimatedMinutes: 10
                )
            ]
        ),
        
        // MARK: - Cleaning Reset
        
        LureliaStarterRoutine(
            id: "cleaning-reset",
            icon: "houseoutline",
            title: "Cleaning Reset",
            colorHex: "#7AE3D6",
            tasks: [
                .init(
                    title: "Throw Away Trash",
                    notes: nil,
                    estimatedMinutes: 5
                ),
                .init(
                    title: "Put Away Loose Items",
                    notes: "Quick room reset.",
                    estimatedMinutes: 10
                ),
                .init(
                    title: "Wipe Surfaces",
                    notes: nil,
                    estimatedMinutes: 10
                ),
                .init(
                    title: "Sweep or Vacuum",
                    notes: nil,
                    estimatedMinutes: 15
                ),
                .init(
                    title: "Reset Bedding or Pillows",
                    notes: nil,
                    estimatedMinutes: 5
                )
            ]
        )
    ]
}
