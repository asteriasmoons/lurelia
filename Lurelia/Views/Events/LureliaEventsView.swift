//
//  LureliaEventsView.swift
//  Lurelia
//

import SwiftData
import SwiftUI

enum LureliaEventsTab: String, CaseIterable, Identifiable {
    case agenda = "Agenda"
    case month = "Month"
    case week = "Week"

    var id: String { rawValue }
}

struct LureliaEventsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LureliaEvent.startDate) private var events: [LureliaEvent]
    @Query(sort: \LureliaEventTag.name) private var tags: [LureliaEventTag]
    @Query private var settings: [UserSettings]
    /// Observed so a change to any calendar's `isHidden` in the Event
    /// Settings sheet invalidates this view and re-runs `localOccurrences`.
    /// Without this query the events list would keep showing rows from a
    /// calendar the user just hid — the events themselves haven't changed,
    /// so the `events` @Query wouldn't fire on its own.
    @Query private var lureliaCalendars: [LureliaCalendar]

    @StateObject private var eventService = LureliaEventService.shared
    @State private var selectedTab: LureliaEventsTab = .agenda
    @State private var focusedDate = Date()
    @State private var showEditor = false
    @State private var editingEvent: LureliaEvent?
    @State private var selectedEvent: LureliaEvent?
    @State private var selectedAppleOccurrence: LureliaExternalCalendarOccurrence?
    @State private var selectedAppleShadowEvent: LureliaEvent?
    @State private var showCalendarSettings = false
    @State private var showAddCalendar = false
    @State private var externalOccurrences: [LureliaExternalCalendarOccurrence] = []
    @State private var showSharedEvents = false

    private var calendar: Calendar { .current }

    private var settingsObject: UserSettings {
        if let existing = settings.first {
            return existing
        }

        let created = UserSettings()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    private var selectedAppleCalendarIDs: Set<String> {
        Set(settings.first?.selectedAppleCalendarIDs ?? [])
    }

    private var displayInterval: DateInterval {
        switch selectedTab {
        case .agenda:
            return calendar.dateInterval(of: .weekOfYear, for: focusedDate) ?? DateInterval(start: focusedDate, duration: 7 * 86_400)
        case .month:
            return calendar.dateInterval(of: .month, for: focusedDate) ?? DateInterval(start: focusedDate, duration: 30 * 86_400)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: focusedDate) ?? DateInterval(start: focusedDate, duration: 7 * 86_400)
        }
    }

    private var localOccurrences: [LureliaEventOccurrence] {
        // Build a fresh hidden-calendar id set directly from the calendars
        // @Query instead of reading `event.calendar?.isHidden`. The inverse
        // relationship can hand back a stale snapshot after the settings
        // sheet toggles `isHidden`. Trusting only the primary-key id keeps
        // this stable.
        let hiddenCalendarIDs = Set(
            lureliaCalendars.filter(\.isHidden).map(\.id)
        )

        // Apple-imported events become local `LureliaEvent`s with
        // `event.calendar = nil` but `event.appleCalendarIdentifier` set to
        // the source Apple calendar's UUID string. Honor the user's Apple
        // Calendar visibility picks for those shadow records too —
        // otherwise hiding an Apple calendar from Event Settings hides
        // the live Apple overlay but leaves these imported copies
        // stranded on the timeline.
        let userSettings = settings.first
        let hasConfiguredApple = userSettings?.hasConfiguredAppleCalendarSelection ?? false
        let visibleAppleIDs = Set(userSettings?.selectedAppleCalendarIDs ?? [])

        return events
            .filter { event in
                // Rule 1: hidden Lurelia primary calendar.
                if let cal = event.calendar,
                   hiddenCalendarIDs.contains(cal.id) {
                    return false
                }

                // Rule 2: imported Apple-owned events with no Lurelia
                // primary — honor the user's Apple calendar visibility.
                if event.isAppleImportedShadow,
                   event.calendar == nil,
                   let appleID = event.appleCalendarIdentifier,
                   !appleID.isEmpty,
                   hasConfiguredApple,
                   !visibleAppleIDs.contains(appleID) {
                    return false
                }

                return true
            }
            .flatMap { $0.occurrences(in: displayInterval, calendar: calendar) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        tabPicker

                        Group {
                            switch selectedTab {
                            case .agenda:
                                LureliaAgendaView(
                                    focusedDate: $focusedDate,
                                    interval: displayInterval,
                                    localOccurrences: localOccurrences,
                                    externalOccurrences: visibleExternalOccurrences,
                                    events: events,
                                    onSelect: selectOccurrence
                                )
                            case .month:
                                LureliaMonthCalendarView(
                                    focusedDate: $focusedDate,
                                    localOccurrences: localOccurrences,
                                    externalOccurrences: visibleExternalOccurrences,
                                    events: events,
                                    onSelect: selectOccurrence
                                )
                            case .week:
                                LureliaWeekScheduleView(
                                    focusedDate: $focusedDate,
                                    localOccurrences: localOccurrences,
                                    externalOccurrences: visibleExternalOccurrences,
                                    events: events,
                                    onSelect: selectOccurrence
                                )
                            }
                        }

                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showEditor) {
            LureliaEventEditorView(event: nil, tags: tags, settings: settingsObject)
        }
        .sheet(item: $editingEvent) { event in
            LureliaEventEditorView(event: event, tags: tags, settings: settingsObject)
        }
        .sheet(item: $selectedEvent) { event in
            LureliaEventDetailView(event: event) {
                selectedEvent = nil
                editingEvent = event
            }
        }
        .sheet(item: $selectedAppleOccurrence) { occurrence in
            LureliaAppleEventDetailView(occurrence: occurrence)
        }
        .sheet(item: $selectedAppleShadowEvent) { event in
            LureliaAppleEventDetailView(event: event)
        }
        .sheet(isPresented: $showCalendarSettings) {
            LureliaEventCalendarSettingsView(settings: settingsObject)
        }
        .sheet(isPresented: $showAddCalendar) {
            LureliaAddCalendarSheet()
        }
        .sheet(isPresented: $showSharedEvents) {
            SharedEventsView()
        }
        .task {
            eventService.refreshAuthorizationStatus()
            migrateEventOriginsIfNeeded()
            loadExternalOccurrences()
            if let savedTab = LureliaEventsTab(rawValue: settingsObject.defaultEventsViewRaw) {
                selectedTab = savedTab
            }
        }
        .onChange(of: focusedDate) { _, _ in loadExternalOccurrences() }
        .onChange(of: selectedTab) { _, _ in loadExternalOccurrences() }
        .onChange(of: settings.first?.selectedAppleCalendarIDs ?? []) { _, _ in loadExternalOccurrences() }
        .onChange(of: settings.first?.showAppleCalendarEvents ?? true) { _, _ in loadExternalOccurrences() }
    }

    private var visibleExternalOccurrences: [LureliaExternalCalendarOccurrence] {
        guard settings.first?.showAppleCalendarEvents ?? true else { return [] }
        let importedAppleOccurrenceKeys = Set(events.compactMap(\.resolvedAppleOccurrenceKey))
        let mirroredRecurringAppleIDs = Set(
            events
                .filter { $0.recurrence != nil }
                .compactMap { $0.appleEventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return externalOccurrences.filter {
            !importedAppleOccurrenceKeys.contains($0.appleOccurrenceKey) &&
            !mirroredRecurringAppleIDs.contains($0.appleEventIdentifier)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Events")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            Button {
                showSharedEvents = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LColors.neutralGlassHighlight.opacity(0.045))
                        .overlay {
                            Circle()
                                .strokeBorder(LColors.neutralGlassHighlight.opacity(0.22), lineWidth: 1)
                        }

                    Image("chatsparkle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(LGradients.header)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shared events")

            Button {
                showAddCalendar = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LColors.neutralGlassHighlight.opacity(0.045))
                        .overlay {
                            Circle()
                                .strokeBorder(LColors.neutralGlassHighlight.opacity(0.22), lineWidth: 1)
                        }

                    Image("addwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(LGradients.header)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            Button {
                showCalendarSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LColors.neutralGlassHighlight.opacity(0.045))
                        .overlay {
                            Circle()
                                .strokeBorder(LColors.neutralGlassHighlight.opacity(0.22), lineWidth: 1)
                        }

                    Image("settings")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(LGradients.header)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            Button {
                showEditor = true
            } label: {
                Image("writingpencil")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(LGradients.header)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    private var tabPicker: some View {
        tabPickerContent
            .padding(.horizontal, 24)
    }

    private var tabPickerContent: some View {
        HStack(spacing: 10) {
            ForEach(LureliaEventsTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    ZStack {
                        LureliaNeutralGlassSurface(cornerRadius: 16, prominence: .surface)

                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LColors.neutralGlassHighlight.opacity(0.06))

                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(LColors.neutralPearl.opacity(0.55), lineWidth: 1)
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var headerSubtitle: String {
        switch selectedTab {
        case .agenda: return "Upcoming commitments"
        case .month: return focusedDate.formatted(.dateTime.month(.wide).year())
        case .week: return "Seven-day schedule"
        }
    }

    private func selectEvent(_ occurrence: LureliaEventOccurrence) {
        guard let event = events.first(where: { $0.id == occurrence.eventID }) else { return }

        if event.isAppleImportedShadow {
            selectedAppleShadowEvent = event
        } else {
            selectedEvent = event
        }
    }

    /// Routes a tap on any row to the correct detail sheet — local events
    /// without Apple identity open `LureliaEventDetailView`, live Apple
    /// occurrences and persisted Apple shadows open `LureliaAppleEventDetailView`.
    private func selectOccurrence(_ occurrence: LureliaEventUnifiedOccurrence) {
        switch occurrence {
        case .local(let local):
            selectEvent(local)
        case .apple(let apple):
            selectedAppleOccurrence = apple
        }
    }

    private func loadExternalOccurrences() {
        guard eventService.hasCalendarAccess,
              settings.first?.showAppleCalendarEvents ?? true
        else {
            externalOccurrences = []
            if LureliaWidgetShared.saveExternalEventSnapshots([]) {
                LureliaWidgetReloads.reloadAll()
            }
            return
        }

        // If the user has explicitly saved their Apple Calendar visibility
        // (via the calendar settings sheet) and chose to hide every
        // calendar, honor that literally — surface no Apple events. Without
        // this guard, `fetchAppleOccurrences` treats an empty set as "no
        // filter" and returns every calendar, which is the bug the user
        // reported: hidden calendars were still showing.
        let hasConfigured = settings.first?.hasConfiguredAppleCalendarSelection ?? false
        if hasConfigured && selectedAppleCalendarIDs.isEmpty {
            externalOccurrences = []
            if LureliaWidgetShared.saveExternalEventSnapshots([]) {
                LureliaWidgetReloads.reloadAll()
            }
            return
        }

        if settings.first?.twoWayAppleCalendarSyncEnabled == true {
            eventService.importAppleEvents(
                into: modelContext,
                from: displayInterval.start,
                to: displayInterval.end,
                calendarIdentifiers: selectedAppleCalendarIDs
            )
        }

        let fetchedExternalOccurrences = eventService.fetchAppleOccurrences(
            from: displayInterval.start,
            to: displayInterval.end,
            calendarIdentifiers: selectedAppleCalendarIDs
        )
        externalOccurrences = fetchedExternalOccurrences
        let widgetSnapshots = fetchedExternalOccurrences.map {
            LureliaWidgetExternalEventSnapshot(
                id: $0.id,
                appleEventIdentifier: $0.appleEventIdentifier,
                appleOccurrenceKey: $0.appleOccurrenceKey,
                calendarIdentifier: $0.calendarIdentifier,
                calendarTitle: $0.calendarTitle,
                title: $0.title,
                colorHex: $0.colorHex,
                start: $0.start,
                end: $0.end,
                isAllDay: $0.isAllDay
            )
        }
        if LureliaWidgetShared.saveExternalEventSnapshots(widgetSnapshots) {
            LureliaWidgetReloads.reloadAll()
        }
    }

    private func migrateEventOriginsIfNeeded() {
        var didChange = false
        for event in events where event.applyInferredEventOriginIfNeeded() {
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
    }
}
