//
//  ReleaseNotesCatalog.swift
//  Lurelia
//

import Foundation

struct LureliaReleaseNote: Identifiable, Hashable {
    let id: String
    let versionTitle: String
    let buildTitle: String
    let releaseDate: String
    let headline: String
    let bullets: [String]
}

enum ReleaseNotesCatalog {
    static let notes: [LureliaReleaseNote] = [
        LureliaReleaseNote(
            id: "v1_1_build_1",
            versionTitle: "Version 1.1",
            buildTitle: "Build #1",
            releaseDate: "August 2026",
            headline: "Release notes are now part of Lurelia, so updates have a real home inside Profile. Liquid Glass has also been added everywhere in the app that isn't a user defined color. Widgets have been fixed as well as events.",
            bullets: [
                "Release Notes now live on the Profile page.",
                "Updates are grouped by version with collapsible cards.",
                "The page uses Lurelia's glass styling, wavy assets, and accent colors.",
                "The newest update opens first so the latest changes are easy to scan.",
                "The Habits widget has been fixed as well as the Routines widget.",
                "The Events now have deduplication so events don't appear duplicated.",
                "Events imported from Apple can now also have a custom icon of your choice. Go to the detail page and tap the icon in the hero card to open the icon picker and select an icon. Updates in the widget too."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_16",
            versionTitle: "Version 1.0",
            buildTitle: "Build #16",
            releaseDate: "August 2026",
            headline: "Calendar and event surfaces became more connected across the app and widgets.",
            bullets: [
                "Apple calendar presentation was refined across agenda, week, month, detail, and widget views.",
                "Event cards gained clearer color continuity from the user's calendar choices.",
                "Shared event surfaces kept their existing behavior while becoming easier to read.",
                "Widget event cards were tuned to match the in-app event styling more closely."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_15",
            versionTitle: "Version 1.0",
            buildTitle: "Build #15",
            releaseDate: "July 2026",
            headline: "Reminders, routines, and the Kanban Timeline became steadier for everyday planning.",
            bullets: [
                "Kanban Timeline reminders were refined so one-time items land on the right day.",
                "Reminder detail and card presentation became more consistent across timeline surfaces.",
                "Routine task flow kept completion actions connected across app and widget entry points.",
                "Timeline rows were cleaned up so schedule context is easier to scan."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_14",
            versionTitle: "Version 1.0",
            buildTitle: "Build #14",
            releaseDate: "July 2026",
            headline: "Alarm support expanded the way habits and reminders can ask for attention.",
            bullets: [
                "AlarmKit support was added for reminders and habits where available.",
                "Habit alarm state became part of the persisted habit setup.",
                "Reminder and habit scheduling kept local notification support alongside alarm behavior.",
                "Alarm sounds and metadata were wired into the app and widget support paths."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_13",
            versionTitle: "Version 1.0",
            buildTitle: "Build #13",
            releaseDate: "June 2026",
            headline: "Profile, onboarding, and personal setup controls became more useful.",
            bullets: [
                "Profile photo support was expanded with camera and photo-library entry points.",
                "Profile avatar upload can sync a saved image to the remote media service.",
                "Timeline settings let the user choose the default board for Kanban Timeline.",
                "Onboarding replay controls were added for pre-release testing."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_12",
            versionTitle: "Version 1.0",
            buildTitle: "Build #12",
            releaseDate: "May 2026",
            headline: "Shared events became richer for group planning and hosted activity.",
            bullets: [
                "Shared event hosting gained stronger detail and management surfaces.",
                "Host posts, announcements, and comments were connected to shared event pages.",
                "Invite and QR flows made shared events easier to pass around.",
                "Offline support paths were added so shared-event actions can recover more gracefully."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_11",
            versionTitle: "Version 1.0",
            buildTitle: "Build #11",
            releaseDate: "April 2026",
            headline: "Journeys and milestones gave longer arcs more structure.",
            bullets: [
                "Journeys gained dedicated detail pages for notes, milestones, and steps.",
                "Milestone creation and editing became part of the guided journey flow.",
                "Journey timeline items helped connect progress into one readable path.",
                "Check-ins and notes made reflection feel more anchored to the journey itself."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_10",
            versionTitle: "Version 1.0",
            buildTitle: "Build #10",
            releaseDate: "March 2026",
            headline: "Challenges became more connected to progress, proof, and reflection.",
            bullets: [
                "Challenge actions and linked steps helped break larger work into visible moves.",
                "Challenge progress reports added space to review what happened.",
                "Challenge cards and detail pages were refined for cleaner scanability.",
                "Reports and response models gave challenge history a stronger data shape."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_9",
            versionTitle: "Version 1.0",
            buildTitle: "Build #9",
            releaseDate: "February 2026",
            headline: "Routines became more flexible with phases, contracts, and reusable task content.",
            bullets: [
                "Routine phases made larger routines easier to organize.",
                "Routine task templates helped reusable steps carry richer detail.",
                "Contracts gave recurring routines a stronger commitment layer.",
                "Routine stats helped progress feel more visible over time."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_8",
            versionTitle: "Version 1.0",
            buildTitle: "Build #8",
            releaseDate: "January 2026",
            headline: "Habits and reminders became more useful as daily care tools.",
            bullets: [
                "Habits gained logs, skip tracking, and stronger completion history.",
                "Reminders gained richer recovery and detail fields.",
                "Notification settings became more flexible across habit and reminder flows.",
                "Core cards were polished so repeated daily actions felt smoother."
            ]
        ),
        LureliaReleaseNote(
            id: "v1_0_build_7",
            versionTitle: "Version 1.0",
            buildTitle: "Build #7",
            releaseDate: "December 2025",
            headline: "Welcome to Lurelia: a focused space for routines, reminders, habits, events, and personal momentum.",
            bullets: [
                "Create routines and break them into actionable tasks.",
                "Track reminders, habits, and schedule items from one app.",
                "Use profile settings to personalize the way planning opens.",
                "Keep progress visible through Lurelia's dark glass interface."
            ]
        )
    ]
}
