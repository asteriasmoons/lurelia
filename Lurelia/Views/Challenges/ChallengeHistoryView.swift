//
//  ChallengeHistoryView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct ChallengeHistoryView: View {

    @Bindable var challenge: LureliaChallenge

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var sortedEntries: [LureliaChallengeEntry] {
        (challenge.entries ?? []).sorted { $0.date > $1.date }
    }

    private var groupedEntries: [(date: Date, entries: [LureliaChallengeEntry])] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: sortedEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped
            .map { day, entries in
                (
                    date: day,
                    entries: entries.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if sortedEntries.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedEntries, id: \.date) { group in
                                daySection(
                                    date: group.date,
                                    entries: group.entries
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Challenge History")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

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
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No history yet")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Challenge activity will appear here as reports, actions, and progress entries are created.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func daySection(
        date: Date,
        entries: [LureliaChallengeEntry]
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(sectionTitle(for: date))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 4)

            VStack(spacing: 9) {
                ForEach(entries) { entry in
                    historyRow(entry)
                }
            }
        }
    }

    private func historyRow(_ entry: LureliaChallengeEntry) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                iconBubble(for: entry)

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(entry.sourceType.displayName)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))

                    if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.note)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                deleteEntry(entry)
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }

    private func iconBubble(for entry: LureliaChallengeEntry) -> some View {
        Image(iconName(for: entry.sourceType))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(LGradients.header)
            .frame(width: 18, height: 18)
            .frame(width: 38, height: 38)
            .background(.white.opacity(0.07), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(LGradients.header, lineWidth: 1)
            }
    }

    private func iconName(
        for sourceType: LureliaChallengeEntrySourceType
    ) -> String {
        switch sourceType {
        case .challengeStarted:
            return "starwavy"

        case .progressReportSubmitted:
            return "linedpages"

        case .reminderCompleted:
            return "bellfill"

        case .habitCompleted:
            return "repeatfill"

        case .routineCompleted:
            return "clockwavy"

        case .manualActionCompleted:
            return "checkwavy"

        case .actionCompleted:
            return "checkwavy"

        case .milestoneReached:
            return "starchart"

        case .challengeCompleted:
            return "startrophyfill"

        case .recoveryVote:
            return "heartwavy"
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func deleteEntry(_ entry: LureliaChallengeEntry) {
        modelContext.delete(entry)
        challenge.updatedAt = Date()
        try? modelContext.save()
    }
}
