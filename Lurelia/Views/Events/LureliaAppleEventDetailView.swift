//
//  LureliaAppleEventDetailView.swift
//  Lurelia
//
//  Read-only detail sheet for events surfaced from Apple Calendar. We can't
//  edit or delete these because they're external — this view just shows
//  what we know and offers an "Open in Calendar" button so the user can
//  jump to the Apple Calendar app to make changes.
//
//  Layout matches the other event sheets: title top-left, xmarkwavy
//  top-right, GlassCard header, section labels outside GlassCards with
//  FrostyTiles inside.
//

import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct LureliaAppleEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let source: LureliaAppleEventDetailSource

    @Query(sort: \LureliaCalendar.name) private var lureliaCalendars: [LureliaCalendar]
    @Query(sort: \LureliaEvent.startDate) private var importedEvents: [LureliaEvent]
    @State private var isCalendarDropdownExpanded = false
    @State private var isIconPickerPresented = false

    init(occurrence: LureliaExternalCalendarOccurrence) {
        self.source = .liveOccurrence(occurrence)
    }

    init(event: LureliaEvent) {
        self.source = .shadowEvent(event)
    }

    private var eventTint: Color {
        Color(lureliaHex: sourceColorHex)
    }

    private var importedEvent: LureliaEvent? {
        if case .shadowEvent(let event) = source {
            return event
        }

        return LureliaEvent.preferredAppleShadow(
            in: importedEvents,
            appleEventIdentifier: appleEventIdentifier,
            appleOccurrenceKey: appleOccurrenceKey
        )
    }

    private var selectedLureliaCalendar: LureliaCalendar? {
        importedEvent?.calendar
    }

    private var tileColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                detailBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header

                        headerCard

                        scheduleSection
                        calendarSection
                        if hasLocation { locationSection }
                        if hasNotes { notesSection }

                        openInCalendarButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isIconPickerPresented) {
                if let importedEvent {
                    LureliaIconPickerView(selectedIcon: Binding(
                        get: { importedEvent.displayIcon },
                        set: { newIcon in
                            importedEvent.icon = newIcon
                            importedEvent.modifiedDate = Date()
                            try? modelContext.save()
                        }
                    ))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text(title.isEmpty ? "Apple Event" : title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 8)

            Button { dismiss() } label: {
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
        .padding(.bottom, 4)
    }

    // MARK: - Header card

    private var headerCard: some View {
        FrostyTile(cornerRadius: 24, padding: LSpacing.cardPadding) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 70, height: 70)

                    Button {
                        if importedEvent != nil {
                            isIconPickerPresented = true
                        }
                    } label: {
                        LureliaIconView(iconId: displayIcon, size: 36)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                Text(title.isEmpty ? "Untitled" : title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("APPLE CALENDAR")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var detailBackground: some View {
        ZStack {
            LureliaBackgroundAlt()

            eventTint
                .opacity(0.18)

            RadialGradient(
                colors: [
                    eventTint.opacity(0.34),
                    eventTint.opacity(0.12),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )

            LinearGradient(
                colors: [
                    eventTint.opacity(0.12),
                    Color.clear,
                    eventTint.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Sections

    private var scheduleSection: some View {
        section("Schedule", icon: "hourglassfill") {
            let displayEndDate = isAllDay
                ? Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
                : endDate

            LazyVGrid(columns: tileColumns, spacing: 10) {
                dataTile(
                    "Start Date",
                    value: startDate.formatted(date: .abbreviated, time: .omitted)
                )
                dataTile(
                    "Start Time",
                    value: isAllDay ? "All day" : startDate.formatted(date: .omitted, time: .shortened)
                )
                dataTile(
                    "End Date",
                    value: displayEndDate.formatted(date: .abbreviated, time: .omitted)
                )
                dataTile(
                    "End Time",
                    value: isAllDay ? "All day" : endDate.formatted(date: .omitted, time: .shortened)
                )
                dataTile(
                    "Duration",
                    value: isAllDay ? "All day" : durationText(endDate.timeIntervalSince(startDate))
                )
            }
        }
    }

    private var calendarSection: some View {
        section("Calendar", icon: "ringstarcal") {
            VStack(spacing: 10) {
                dataTile("Apple Calendar", value: appleCalendarTitle)
                lureliaCalendarDropdown
            }
        }
    }

    private var locationSection: some View {
        section("Location", icon: "lovelocation") {
            VStack(spacing: 10) {
                if let location, !location.isEmpty {
                    dataTile("Where", value: location)
                }
            }
        }
    }

    private var notesSection: some View {
        section("Description", icon: "writefeather") {
            FrostyTile {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DESCRIPTION")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))

                    Text(descriptionText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var lureliaCalendarDropdown: some View {
        FrostyTile {
            VStack(alignment: .leading, spacing: 10) {
                Text("LURELIA CALENDAR")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        isCalendarDropdownExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(lureliaHex: selectedLureliaCalendar?.color ?? sourceColorHex))
                            .frame(width: 14, height: 14)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedLureliaCalendar?.name.nonEmptyOrNil ?? "No Lurelia calendar")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("Optional organization")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(isCalendarDropdownExpanded ? "chevup" : "chevdown")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background {
                        LureliaNeutralGlassSurface(
                            cornerRadius: 14,
                            prominence: isCalendarDropdownExpanded ? .active : .lens
                        )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isCalendarDropdownExpanded {
                    VStack(spacing: 6) {
                        lureliaCalendarOptionRow(nil)

                        if lureliaCalendars.isEmpty {
                            Text("No Lurelia calendars yet.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(lureliaCalendars) { calendar in
                                lureliaCalendarOptionRow(calendar)
                            }
                        }
                    }
                    .padding(6)
                    .background {
                        LureliaNeutralGlassSurface(cornerRadius: 14)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lureliaCalendarOptionRow(_ calendar: LureliaCalendar?) -> some View {
        let selectedID = selectedLureliaCalendar?.id
        let isSelected = calendar?.id == selectedID || (calendar == nil && selectedID == nil)
        let title = calendar?.name.nonEmptyOrNil ?? "No Lurelia calendar"
        let colorHex = calendar?.color ?? sourceColorHex

        return Button {
            assignImportedEvent(to: calendar)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                isCalendarDropdownExpanded = false
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(lureliaHex: colorHex))
                    .frame(width: 12, height: 12)
                    .opacity(calendar == nil ? 0.45 : 1)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isSelected {
                    Image("checkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(LGradients.header)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    LureliaNeutralGlassSurface(cornerRadius: 10, prominence: .active)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var openInCalendarButton: some View {
        Button {
            openInAppleCalendar()
        } label: {
            Text("Open in Calendar")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background { LureliaNeutralGlassSurface(cornerRadius: 18) }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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

    private func dataTile(_ label: String, value: String) -> some View {
        FrostyTile {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    private var title: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.title
        case .shadowEvent(let event):
            return event.title
        }
    }

    private var displayIcon: String {
        switch source {
        case .liveOccurrence:
            return "starcal"
        case .shadowEvent(let event):
            return event.displayIcon
        }
    }

    private var appleEventIdentifier: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.appleEventIdentifier
        case .shadowEvent(let event):
            return event.appleEventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private var appleOccurrenceKey: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.appleOccurrenceKey
        case .shadowEvent(let event):
            return event.resolvedAppleOccurrenceKey ?? ""
        }
    }

    private var appleCalendarIdentifier: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.calendarIdentifier
        case .shadowEvent(let event):
            return event.appleCalendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private var appleCalendarTitle: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.calendarTitle
        case .shadowEvent(let event):
            return event.appleCalendarTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
                ?? "Apple Calendar"
        }
    }

    private var sourceColorHex: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.colorHex
        case .shadowEvent(let event):
            return event.appleCalendarColor?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
                ?? event.colorHex
        }
    }

    private var startDate: Date {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.start
        case .shadowEvent(let event):
            return event.occurrenceStart()
        }
    }

    private var endDate: Date {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.end
        case .shadowEvent(let event):
            return event.occurrenceEnd(for: event.occurrenceStart())
        }
    }

    private var isAllDay: Bool {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.isAllDay
        case .shadowEvent(let event):
            return event.isAllDay
        }
    }

    private var location: String? {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.location
        case .shadowEvent(let event):
            return event.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
                ?? event.address?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
        }
    }

    private var descriptionText: String {
        switch source {
        case .liveOccurrence(let occurrence):
            return occurrence.notes ?? ""
        case .shadowEvent(let event):
            return event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
                ?? event.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
                ?? ""
        }
    }

    private var hasLocation: Bool {
        location?.isEmpty == false
    }

    private var hasNotes: Bool {
        !descriptionText.isEmpty
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    private func assignImportedEvent(to calendar: LureliaCalendar?) {
        guard calendar != nil || importedEvent != nil else { return }
        guard !appleEventIdentifier.isEmpty, !appleOccurrenceKey.isEmpty else { return }

        let target = importedEvent ?? makeImportedEventShadow()
        target.markAppleImportedShadow()
        target.appleEventIdentifier = appleEventIdentifier
        target.appleOccurrenceKey = appleOccurrenceKey
        target.calendar = calendar
        target.color = target.appleCalendarColor ?? sourceColorHex
        target.modifiedDate = Date()
        consolidateImportedShadowDuplicates(into: target)

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func makeImportedEventShadow() -> LureliaEvent {
        let target = LureliaEvent()
        target.title = title.isEmpty ? "Untitled Event" : title
        target.eventDescription = descriptionText.nonEmptyOrNil
        target.icon = "starcal"
        target.color = sourceColorHex
        target.locationName = location
        target.startDate = startDate
        target.endDate = endDate
        target.startTime = isAllDay ? nil : startDate
        target.endTime = isAllDay ? nil : endDate
        target.duration = max(0, endDate.timeIntervalSince(startDate))
        target.isAllDay = isAllDay
        target.appleEventIdentifier = appleEventIdentifier
        target.appleOccurrenceKey = appleOccurrenceKey
        target.appleCalendarIdentifier = appleCalendarIdentifier
        target.appleCalendarTitle = appleCalendarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        target.appleCalendarColor = sourceColorHex
        target.markAppleImportedShadow()
        target.syncsWithAppleCalendar = true
        target.createdDate = Date()
        target.modifiedDate = Date()
        modelContext.insert(target)
        return target
    }

    private func consolidateImportedShadowDuplicates(into target: LureliaEvent) {
        let candidates = LureliaEvent.appleShadowCandidates(
            in: importedEvents,
            appleEventIdentifier: appleEventIdentifier,
            appleOccurrenceKey: appleOccurrenceKey
        )

        for duplicate in candidates where duplicate.id != target.id {
            mergeImportedShadow(duplicate, into: target)
            modelContext.delete(duplicate)
        }
    }

    private func mergeImportedShadow(_ duplicate: LureliaEvent, into target: LureliaEvent) {
        target.markAppleImportedShadow()

        if target.calendar == nil {
            target.calendar = duplicate.calendar
        }

        let targetIcon = target.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let duplicateIcon = duplicate.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if (targetIcon.isEmpty || targetIcon == "starcal"), !duplicateIcon.isEmpty {
            target.icon = duplicateIcon
        }

        let targetCategory = target.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let duplicateCategory = duplicate.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if targetCategory.isEmpty, !duplicateCategory.isEmpty {
            target.categoryName = duplicateCategory
        }

        if (target.notifications ?? []).isEmpty,
           let duplicateNotifications = duplicate.notifications,
           !duplicateNotifications.isEmpty {
            target.notifications = duplicateNotifications
            duplicateNotifications.forEach { $0.event = target }
        }

        if (target.attachments ?? []).isEmpty,
           let duplicateAttachments = duplicate.attachments,
           !duplicateAttachments.isEmpty {
            target.attachments = duplicateAttachments
            duplicateAttachments.forEach { $0.event = target }
        }

        if (target.tags ?? []).isEmpty,
           let duplicateTags = duplicate.tags,
           !duplicateTags.isEmpty {
            target.tags = duplicateTags
        }

        if duplicate.modifiedDate > target.modifiedDate {
            target.modifiedDate = duplicate.modifiedDate
        }
    }

    /// Best-effort deep link into Apple's Calendar app. We use `calshow:`
    /// with the event's start-date epoch — this reliably opens Calendar and
    /// jumps to the correct day. There's no public URL scheme that opens a
    /// specific event, so we get the user to the right day and let them
    /// tap the event themselves.
    private func openInAppleCalendar() {
        let epoch = Int(startDate.timeIntervalSinceReferenceDate)
        if let url = URL(string: "calshow:\(epoch)") {
            UIApplication.shared.open(url)
        }
    }
}

private enum LureliaAppleEventDetailSource {
    case liveOccurrence(LureliaExternalCalendarOccurrence)
    case shadowEvent(LureliaEvent)
}

private extension String {
    var nonEmptyOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
