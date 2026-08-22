//
//  LureliaEventCalendarSettingsView.swift
//  Lurelia
//
//  Sheet layout matches every other add/edit sheet: title top-left,
//  xmarkwavy top-right, GlassCard sections with label headers outside,
//  Done capsule at the bottom.
//
//  Sections (top to bottom):
//    1. Default View — LureliaGradientDropdown (Agenda / Month / Week)
//    2. My Calendars — filter user-created LureliaCalendar rows with
//       hollow/filled gradient circles for visibility, tap row to edit
//    3. Apple Calendar — Show + Two-Way Sync toggles
//    4. Visible Calendars (Apple) — checkbox list of Apple calendars
//

import SwiftData
import SwiftUI
import UIKit

struct LureliaEventCalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var settings: UserSettings
    @Query(sort: \LureliaCalendar.name) private var lureliaCalendars: [LureliaCalendar]

    @StateObject private var eventService = LureliaEventService.shared
    @State private var selectedIDs: Set<String> = []
    @State private var defaultView: LureliaEventsTab? = .agenda
    @State private var editingCalendar: LureliaCalendar?

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header

                        defaultViewSection
                        myCalendarsSection
                        appleTogglesSection

                        if eventService.hasCalendarAccess {
                            syncDestinationSection
                            visibleAppleCalendarsSection
                        } else {
                            connectAppleSection
                        }

                        doneButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingCalendar) { calendar in
                LureliaAddCalendarSheet(editing: calendar)
            }
            .task {
                selectedIDs = Set(settings.selectedAppleCalendarIDs)
                eventService.refreshAuthorizationStatus()
                if selectedIDs.isEmpty {
                    selectedIDs = Set(eventService.appleCalendars.map(\.id))
                }
                defaultView = LureliaEventsTab(rawValue: settings.defaultEventsViewRaw) ?? .agenda
            }
            .onChange(of: defaultView) { _, newValue in
                if let raw = newValue?.rawValue {
                    settings.defaultEventsViewRaw = raw
                    try? modelContext.save()
                }
            }
            .onChange(of: settings.twoWayAppleCalendarSyncEnabled) { wasOn, isOn in
                // When the user flips Two-Way Sync on, push any
                // Lurelia-authored events that don't exist in Apple yet.
                // Events that came from Apple (or were already mirrored) are
                // skipped inside the service so we never duplicate.
                guard !wasOn, isOn else { return }
                eventService.syncAllLocalEventsToApple(
                    context: modelContext,
                    defaultCalendarID: resolvedSyncDestinationID
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("Calendar Settings")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Button { commitAndDismiss() } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LGradients.header)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Default View

    private var defaultViewSection: some View {
        section("Default View", icon: "starcal") {
            GlassCard {
                LureliaGradientDropdown(
                    placeholder: "Agenda",
                    options: LureliaEventsTab.allCases,
                    selection: $defaultView,
                    label: { $0.rawValue }
                )
            }
        }
    }

    // MARK: - My Calendars

    private var myCalendarsSection: some View {
        section("My Calendars", icon: "ringstarcal") {
            GlassCard {
                if lureliaCalendars.isEmpty {
                    Text("You haven't created any calendars yet. Tap the calendars icon in the Events header to add one.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 10) {
                        ForEach(lureliaCalendars) { calendar in
                            myCalendarRow(calendar)
                        }
                    }
                }
            }
        }
    }

    private func myCalendarRow(_ calendar: LureliaCalendar) -> some View {
        HStack(spacing: 12) {
            visibilityCircleButton(for: calendar)

            Button {
                editingCalendar = calendar
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(lureliaHex: calendar.color))
                        .frame(width: 14, height: 14)

                    Text(calendar.name.isEmpty ? "Untitled" : calendar.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Image("chevright")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(LGradients.header)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    /// Hollow gradient circle when the calendar is hidden; filled gradient
    /// circle with `checkwavy` when visible. Tap toggles.
    private func visibilityCircleButton(for calendar: LureliaCalendar) -> some View {
        Button {
            calendar.isHidden.toggle()
            try? modelContext.save()
        } label: {
            ZStack {
                if calendar.isHidden {
                    Circle()
                        .strokeBorder(LColors.neutralPearl.opacity(0.52), lineWidth: 2)
                        .frame(width: 26, height: 26)
                } else {
                    LureliaNeutralGlassCircle()
                        .frame(width: 26, height: 26)

                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(LColors.neutralPearl)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.isHidden ? "Show \(calendar.name)" : "Hide \(calendar.name)")
    }

    // MARK: - Sync destination

    /// The Apple Calendar identifier we'll write Lurelia-authored events
    /// into. Prefers the user's explicit pick; falls back to the first
    /// writable calendar available.
    private var resolvedSyncDestinationID: String? {
        if let explicit = settings.defaultAppleSyncCalendarID,
           writableAppleCalendars.contains(where: { $0.id == explicit }) {
            return explicit
        }
        return writableAppleCalendars.first?.id
    }

    private var writableAppleCalendars: [LureliaAppleCalendarSource] {
        eventService.appleCalendars.filter(\.allowsContentModifications)
    }

    private var syncDestinationSection: some View {
        section("Sync To Calendar", icon: "lovecalendar") {
            GlassCard {
                if writableAppleCalendars.isEmpty {
                    Text("No writable Apple calendars available. Add one in the Calendar app to enable sync.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LureliaGradientDropdown(
                        placeholder: "Choose a destination calendar",
                        options: writableAppleCalendars.map(\.id),
                        selection: syncDestinationBinding,
                        label: { id in
                            writableAppleCalendars.first(where: { $0.id == id })?.title ?? id
                        }
                    )
                }
            }
        }
    }

    /// Binds the dropdown to `settings.defaultAppleSyncCalendarID`. Writing
    /// nil clears the explicit choice and falls back to the first writable
    /// calendar automatically.
    private var syncDestinationBinding: Binding<String?> {
        Binding(
            get: { settings.defaultAppleSyncCalendarID ?? resolvedSyncDestinationID },
            set: { newValue in
                settings.defaultAppleSyncCalendarID = newValue
                try? modelContext.save()
            }
        )
    }

    // MARK: - Apple toggles

    private var appleTogglesSection: some View {
        section("Apple Calendar", icon: "dotscal") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $settings.showAppleCalendarEvents) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Show Apple Calendar Events")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Merge Apple Calendar into Lurelia's views")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .tint(Color.white.opacity(0.85))

                    Toggle(isOn: $settings.twoWayAppleCalendarSyncEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Two-Way Sync")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Import Apple events into Lurelia automatically")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .tint(Color.white.opacity(0.85))
                }
            }
        }
    }

    // MARK: - Visible Apple calendars

    private var visibleAppleCalendarsSection: some View {
        section("Visible Apple Calendars", icon: "starcal") {
            GlassCard {
                if eventService.appleCalendars.isEmpty {
                    Text("No Apple Calendars found.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    VStack(spacing: 8) {
                        ForEach(eventService.appleCalendars) { calendar in
                            appleCalendarRow(calendar)
                        }
                    }
                }
            }
        }
    }

    private func appleCalendarRow(_ calendar: LureliaAppleCalendarSource) -> some View {
        let isSelected = selectedIDs.contains(calendar.id)
        return Button {
            toggle(calendar.id)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(lureliaHex: calendar.colorHex))
                    .frame(width: 14, height: 14)

                Text(calendar.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Group {
                    if isSelected {
                        Image("checkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                    } else {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    }
                }
                .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connect Apple

    private var connectAppleSection: some View {
        section("Connect Apple", icon: "dotscal") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                        Text("Apple Calendar is not connected.")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)

                    Button {
                        Task {
                            _ = await eventService.requestCalendarAccess()
                            selectedIDs = Set(eventService.appleCalendars.map(\.id))
                            settings.selectedAppleCalendarIDs = Array(selectedIDs)
                            settings.hasConfiguredAppleCalendarSelection = true
                        }
                    } label: {
                        Text("Connect Apple Calendar")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background { LureliaNeutralGlassSurface(cornerRadius: 16) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Done

    private var doneButton: some View {
        Button { commitAndDismiss() } label: {
            Text("Done")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background { LureliaNeutralGlassSurface(cornerRadius: 22) }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LColors.neutralPearl.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)

            content()
        }
    }

    private func commitAndDismiss() {
        settings.selectedAppleCalendarIDs = Array(selectedIDs)
        // Mark configured so an empty visible-set is honored as "hide all"
        // instead of silently falling back to "show all".
        settings.hasConfiguredAppleCalendarSelection = true
        if let raw = defaultView?.rawValue {
            settings.defaultEventsViewRaw = raw
        }
        try? modelContext.save()
        dismiss()
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
