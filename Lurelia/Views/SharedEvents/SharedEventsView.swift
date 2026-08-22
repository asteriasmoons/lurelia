//
//  SharedEventsView.swift
//  Lurelia
//
//  List of shared events the current user hosts or is attending. Reads
//  the caller's identity (`remoteUserID` / `remoteDisplayName`) from
//  `UserSettings` — writing back through the same rows when the user
//  sets up their handle for the first time via the identity card.
//

import SwiftData
import SwiftUI

struct SharedEventsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    @StateObject private var service = SharedEventsService.shared

    // Identity setup (empty until the user picks a handle).
    @State private var handleDraft: String = ""

    // Listing.
    @State private var buckets: SharedEventListBucketsDTO?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Sheets.
    @State private var selection: SharedEventDTO?
    @State private var showingCreator: Bool = false

    private var settingsObject: UserSettings {
        if let existing = settings.first { return existing }
        let created = UserSettings()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    private var currentUserID: String { settingsObject.remoteUserID }
    private var currentDisplayName: String { settingsObject.remoteDisplayName }
    private var currentAvatarURL: String? {
        settingsObject.remoteAvatarURL
    }
    private var hasIdentity: Bool {
        !currentUserID.isEmpty && !currentDisplayName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header

                        if !hasIdentity {
                            identityCard
                        } else if isLoading, buckets == nil {
                            loadingCard
                        } else if let err = errorMessage {
                            errorCard(err)
                        } else if let buckets {
                            if buckets.asHost.isEmpty && buckets.asAttendee.isEmpty {
                                emptyCard
                            } else {
                                if !buckets.asHost.isEmpty {
                                    section(title: "Hosting", events: buckets.asHost)
                                }
                                if !buckets.asAttendee.isEmpty {
                                    section(title: "Attending", events: buckets.asAttendee)
                                }
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
        .sheet(item: $selection) { event in
            SharedEventDetailView(
                eventID: event.id,
                initialEvent: event,
                currentUserID: currentUserID,
                currentDisplayName: currentDisplayName,
                currentAvatarURL: currentAvatarURL,
            )
        }
        .sheet(isPresented: $showingCreator) {
            SharedEventCreatorSheet(
                currentUserID: currentUserID,
                currentDisplayName: currentDisplayName,
                currentAvatarURL: currentAvatarURL,
                onCreated: { event in
                    Task { await reload() }
                    selection = event
                },
            )
        }
        .task { await reload() }
    }

    // MARK: - Header (title + create button)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Shared events")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Hosting, attending, and invited")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                if hasIdentity {
                    Button {
                        showingCreator = true
                    } label: {
                        Image("addwavy")
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
                    .accessibilityLabel("New shared event")
                }

                Button { dismiss() } label: {
                    Image("xmarkwavy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LGradients.header)
                        .frame(width: 24, height: 24)
                        .frame(width: 38, height: 38)
                        .background(LColors.glassSurface, in: Circle())
                        .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close shared events")
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Identity setup

    private var identityCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set up your handle")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Text("Pick a display name so friends can find you in shared events. This is stored on your device and sent with each request.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Display name", text: $handleDraft)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .padding(12)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    saveIdentity()
                } label: {
                    Text("Continue")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.adaptivePrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(LGradients.header))
                        .opacity(handleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .disabled(handleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    private func saveIdentity() {
        let trimmed = handleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settingsObject.remoteDisplayName = trimmed
        if settingsObject.remoteUserID.isEmpty {
            settingsObject.remoteUserID = "u-\(UUID().uuidString.lowercased())"
        }
        try? modelContext.save()
        Task { await reload() }
    }

    // MARK: - Sections

    private func section(title: String, events: [SharedEventDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .padding(.horizontal, LSpacing.pageHorizontal)

            VStack(spacing: 12) {
                ForEach(events) { event in
                    Button {
                        selection = event
                    } label: {
                        row(for: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
    }

    private func row(for event: SharedEventDTO) -> some View {
        GlassCard(cornerRadius: 20, padding: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(lureliaHex: event.colorHex))
                    .frame(width: 6, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle(for: event))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()

                if let counts = event.counts {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(counts.going ?? 0) going")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.accent)
                        Text("\(counts.attendees ?? 0) in")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                }
            }
        }
    }

    private var loadingCard: some View {
        GlassCard(cornerRadius: 20) {
            HStack {
                Spacer()
                ProgressView().tint(LColors.accent)
                Spacer()
            }
            .padding(.vertical, 24)
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    private var emptyCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("No shared events yet")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Text("Tap the plus button above to create your first one, or accept an invitation from a friend.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingCreator = true
                } label: {
                    Text("Create a shared event")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.adaptivePrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(LGradients.header))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    private func errorCard(_ err: String) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Couldn't load shared events")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Text(err)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
    }

    private func subtitle(for event: SharedEventDTO) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d · h:mm a"
        return formatter.string(from: event.startDate)
    }

    private func reload() async {
        guard hasIdentity else {
            buckets = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            buckets = try await service.listEvents(userID: currentUserID)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
