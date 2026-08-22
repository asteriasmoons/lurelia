//
//  EditSharedEventSheet.swift
//  Lurelia
//
//  Edit sheet for an existing SharedEvent. Uses the same visual language
//  as SharedEventCreatorSheet (GlassCard sections, gradient date/time
//  drum pickers, LureliaBackgroundAlt) — deliberately not extracted into
//  a shared component because the two flows diverge on save action,
//  visibility, and validation. Reuse is done at the SERVICE layer
//  (`SharedEventsService.updateEvent`), not the view layer.
//

import SwiftUI

struct EditSharedEventSheet: View {
    let event: SharedEventDTO
    let currentUserID: String
    let onSaved: (SharedEventDTO) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var locationName: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var startHour: Int
    @State private var startMinute: Int

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    init(
        event: SharedEventDTO,
        currentUserID: String,
        onSaved: @escaping (SharedEventDTO) -> Void,
    ) {
        self.event = event
        self.currentUserID = currentUserID
        self.onSaved = onSaved
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description ?? "")
        _locationName = State(initialValue: event.locationName ?? "")
        _isAllDay = State(initialValue: event.isAllDay)
        let cal = Calendar.current
        _startDate = State(initialValue: event.startDate)
        _startHour = State(initialValue: cal.component(.hour, from: event.startDate))
        _startMinute = State(initialValue: cal.component(.minute, from: event.startDate))
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    titleCard
                    detailsCard
                    whenCard

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

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Edit event")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
            Spacer()
            Button {
                Task { await save() }
            } label: {
                Text(isSubmitting ? "…" : "Save")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.adaptivePrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LGradients.header))
                    .opacity(canSubmit ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(LGradients.header)
                    .frame(width: 38, height: 38)
                    .background(LColors.glassSurface, in: Circle())
                    .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var titleCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Title")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)

                TextField("Event name", text: $title)
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

                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(12)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField("Location", text: $locationName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(12)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var whenCard: some View {
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
                    LureliaGradientTimeDrumPicker(hour: $startHour, minute: $startMinute)
                }
            }
        }
    }

    // MARK: - Save

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let updated = try await SharedEventsService.shared.updateEvent(
                eventID: event.id,
                actorUserID: currentUserID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: resolvedStartDate,
                isAllDay: isAllDay,
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            )
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
