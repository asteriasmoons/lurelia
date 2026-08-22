//
//  SharedEventCreatorSheet.swift
//  Lurelia
//
//  Sheet for creating a new SharedEvent from inside the app. Backed by
//  SharedEventsService.createEvent — the server bootstraps Host,
//  Permissions, and a host Attendee row on receipt.
//

import SwiftUI

struct SharedEventCreatorSheet: View {
    let currentUserID: String
    let currentDisplayName: String
    let currentAvatarURL: String?
    let onCreated: (SharedEventDTO) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var locationName: String = ""
    @State private var visibility: String = "private"
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = defaultStart()
    @State private var startHour: Int = 18
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 20
    @State private var endMinute: Int = 0

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header

                    titleCard
                    detailsCard
                    dateTimeCard
                    visibilityCard

                    if let err = errorMessage {
                        GlassCard(cornerRadius: 16) {
                            Text(err)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.top, 12)
                .padding(.horizontal, LSpacing.pageHorizontal)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
            }

            Spacer()

            Text("New shared event")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Spacer()

            Button {
                Task { await create() }
            } label: {
                Text(isSubmitting ? "…" : "Create")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.adaptivePrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LGradients.header))
                    .opacity(canSubmit ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)
        }
    }

    // MARK: - Cards

    private var titleCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Title")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                TextField("Give the event a name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(12)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var detailsCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Details")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(12)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("Location (optional)", text: $locationName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(12)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var dateTimeCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("When")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                    Spacer()
                    Toggle(isOn: $isAllDay) {
                        Text("All day")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .tint(LColors.accent)
                    .frame(maxWidth: 130)
                }

                LureliaGradientDateDrumPicker(date: $startDate)

                if !isAllDay {
                    LureliaGradientTimeDrumPicker(
                        hour: $startHour,
                        minute: $startMinute,
                    )
                }
            }
        }
    }

    private var visibilityCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Visibility")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                HStack(spacing: 8) {
                    visibilityButton("Private", value: "private")
                    visibilityButton("Link only", value: "link")
                    visibilityButton("Public", value: "public")
                }
            }
        }
    }

    private func visibilityButton(_ label: String, value: String) -> some View {
        let isActive = visibility == value
        return Button {
            visibility = value
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .fill(isActive ? LColors.gradientBlue.opacity(0.32) : LColors.glassSurface2),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(
                            isActive ? LColors.accent.opacity(0.72) : LColors.glassBorder,
                            lineWidth: 1,
                        ),
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Submit

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !currentUserID.isEmpty
            && !currentDisplayName.isEmpty
    }

    private var resolvedStartDate: Date {
        if isAllDay {
            return Calendar.current.startOfDay(for: startDate)
        }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
        comps.hour = startHour
        comps.minute = startMinute
        return Calendar.current.date(from: comps) ?? startDate
    }

    private func create() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let payload = SharedEventsService.CreateEventPayload(
            localID: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: nil,
            colorHex: "#03dbfc",
            timezoneIdentifier: TimeZone.current.identifier,
            startDate: resolvedStartDate,
            endDate: nil,
            isAllDay: isAllDay,
            locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            address: nil,
            visibility: visibility,
            hostUserID: currentUserID,
            hostDisplayName: currentDisplayName,
            hostAvatarURL: currentAvatarURL,
        )
        do {
            let event = try await SharedEventsService.shared.createEvent(payload)
            onCreated(event)
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - Defaults

    private static func defaultStart() -> Date {
        let cal = Calendar.current
        let now = Date()
        let day = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        return day
    }
}
