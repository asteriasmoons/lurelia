//
//  SharedEventCalendarSyncCard.swift
//  Lurelia
//
//  Per-event card that lets the user mirror a shared event into their
//  Apple Calendar. Sits inside SharedEventDetailView; per-device state
//  lives in the local `SharedEventAppleMirror` @Model.
//

import SwiftUI
import SwiftData

struct SharedEventCalendarSyncCard: View {
    let event: SharedEventDTO

    @Environment(\.modelContext) private var modelContext
    @StateObject private var eventService = LureliaEventService.shared

    @State private var mirror: SharedEventAppleMirror?
    @State private var pickedCalendarID: String = ""
    @State private var pickedMode: SharedEventCalendarSyncMode = .off
    @State private var isBusy: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                header

                if !hasCalendarAccess {
                    Button {
                        Task { await requestAccess() }
                    } label: {
                        Text("Allow calendar access")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.adaptivePrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(LGradients.header))
                    }
                    .buttonStyle(.plain)
                } else {
                    calendarPicker
                    modePicker
                    actionButtons
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.danger)
                        .lineLimit(3)
                }

                if let lastSync = mirror?.lastSyncedAt {
                    Text("Last synced ").font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        + Text(lastSync, style: .relative)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Apple Calendar sync")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
            Spacer()
            if let mirror, mirror.isEnabled {
                Text(mirror.syncMode.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.adaptivePrimaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LGradients.header))
            }
        }
    }

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Write into calendar")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            let calendars = eventService.appleCalendars.filter { $0.allowsContentModifications }
            if calendars.isEmpty {
                Text("No writable calendars.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            } else {
                Menu {
                    ForEach(calendars) { cal in
                        Button(cal.title) { pickedCalendarID = cal.id }
                    }
                } label: {
                    HStack {
                        Text(currentCalendarLabel(from: calendars))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Spacer()
                        Text("▾")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(LColors.glassBorder, lineWidth: 1),
                    )
                }
            }
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sync mode")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8,
            ) {
                modeButton(.off, label: "Off")
                modeButton(.mirror, label: "Mirror once")
                modeButton(.exportOnly, label: "Export")
                modeButton(.importOnly, label: "Import")
                modeButton(.oneWay, label: "One-way")
                modeButton(.twoWay, label: "Two-way")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                Task { await runSync() }
            } label: {
                Text(isBusy ? "Syncing…" : "Apply")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.adaptivePrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LGradients.header))
            }
            .buttonStyle(.plain)
            .disabled(isBusy || pickedCalendarID.isEmpty || pickedMode == .off)
            .opacity((isBusy || pickedCalendarID.isEmpty || pickedMode == .off) ? 0.45 : 1)

            if mirror?.isEnabled == true {
                Button {
                    Task { await stopMirror() }
                } label: {
                    Text("Stop")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(LColors.danger.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        }
    }

    private func modeButton(_ mode: SharedEventCalendarSyncMode, label: String) -> some View {
        let isActive = pickedMode == mode
        return Button {
            pickedMode = mode
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .fill(isActive ? LColors.gradientBlue.opacity(0.32) : LColors.glassSurface2),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(
                            isActive ? LColors.accent.opacity(0.7) : LColors.glassBorder,
                            lineWidth: 1,
                        ),
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var hasCalendarAccess: Bool { eventService.hasCalendarAccess }

    private func currentCalendarLabel(from calendars: [LureliaAppleCalendarSource]) -> String {
        if let match = calendars.first(where: { $0.id == pickedCalendarID }) {
            return match.title
        }
        return "Choose a calendar"
    }

    // MARK: - Actions

    private func requestAccess() async {
        let ok = await SharedEventCalendarSync.shared.ensureAccess()
        if ok {
            eventService.refreshAuthorizationStatus()
        } else {
            errorMessage = "Access denied. Enable in Settings → Lurelia → Calendars."
        }
    }

    private func load() async {
        eventService.refreshAuthorizationStatus()
        let m = SharedEventCalendarSync.shared.mirror(
            for: event.id,
            context: modelContext,
        )
        mirror = m
        pickedCalendarID = m.appleCalendarIdentifier ?? ""
        pickedMode = m.syncMode == .off ? .exportOnly : m.syncMode
    }

    private func runSync() async {
        guard let mirror else { return }
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil

        mirror.syncMode = pickedMode
        mirror.appleCalendarIdentifier = pickedCalendarID
        try? modelContext.save()

        do {
            switch pickedMode {
            case .off:
                break
            case .mirror, .exportOnly, .oneWay:
                try await SharedEventCalendarSync.shared.mirrorOnce(
                    event,
                    direction: .toApple,
                    calendarID: pickedCalendarID,
                    mirror: mirror,
                    context: modelContext,
                )
            case .importOnly:
                _ = await SharedEventCalendarSync.shared.importFromAppleCalendar(mirror: mirror)
            case .twoWay:
                try await SharedEventCalendarSync.shared.mirrorOnce(
                    event,
                    direction: .toApple,
                    calendarID: pickedCalendarID,
                    mirror: mirror,
                    context: modelContext,
                )
                await SharedEventCalendarSync.shared.syncTwoWay(
                    event,
                    mirror: mirror,
                    context: modelContext,
                )
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func stopMirror() async {
        guard let mirror else { return }
        isBusy = true
        defer { isBusy = false }
        await SharedEventCalendarSync.shared.stopMirroring(
            mirror: mirror,
            context: modelContext,
        )
        self.mirror = nil
        pickedMode = .off
        pickedCalendarID = ""
    }
}
