//
//  ChallengeLinkPickerView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct ChallengeLinkPickerView: View {

    @Environment(\.dismiss) private var dismiss

    let linkedType: LureliaChallengeLinkedItemType
    @Binding var selectedID: UUID?

    @Query(sort: \LureliaReminder.scheduledDate)
    private var reminders: [LureliaReminder]

    @Query(sort: \LureliaHabit.createdAt)
    private var habits: [LureliaHabit]

    @Query(sort: \LureliaRoutine.sortOrder)
    private var routines: [LureliaRoutine]

    @State private var searchText = ""

    private var filteredReminders: [LureliaReminder] {
        reminders
            .filter { $0.kind == .standalone }
            .filter {
                searchText.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var filteredHabits: [LureliaHabit] {
        habits
            .filter { !$0.isArchived }
            .filter {
                searchText.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var filteredRoutines: [LureliaRoutine] {
        routines
            .filter {
                searchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    searchBar

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            content
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack {
            Text("Select \(linkedType.displayName)")
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
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image("searchwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .frame(width: 18, height: 18)

            TextField("Search \(linkedType.displayName.lowercased())s", text: $searchText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch linkedType {
        case .reminder:
            if filteredReminders.isEmpty {
                emptyState("No reminders found.")
            } else {
                ForEach(filteredReminders) { reminder in
                    pickerRow(
                        id: reminder.id,
                        icon: reminder.icon.isEmpty ? "bellfill" : reminder.icon,
                        title: reminder.title,
                        subtitle: reminderSubtitle(reminder)
                    )
                }
            }

        case .habit:
            if filteredHabits.isEmpty {
                emptyState("No habits found.")
            } else {
                ForEach(filteredHabits) { habit in
                    pickerRow(
                        id: habit.id,
                        icon: (habit.iconName ?? "repeatfill").isEmpty ? "repeatfill" : (habit.iconName ?? "repeatfill"),
                        title: habit.title,
                        subtitle: "\(habit.target)x target"
                    )
                }
            }

        case .routine:
            if filteredRoutines.isEmpty {
                emptyState("No routines found.")
            } else {
                ForEach(filteredRoutines, id: \.persistentID) { routine in
                    pickerRow(
                        id: UUID(uuidString: routine.persistentID) ?? UUID(),
                        icon: routine.icon.isEmpty ? "clockwavy" : routine.icon,
                        title: routine.name,
                        subtitle: routine.formattedTimeRange
                    )
                }
            }

        case .manual:
            emptyState("Manual actions do not need a linked item.")
        }
    }

    private func pickerRow(
        id: UUID,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            selectedID = id
            dismiss()
        } label: {
            GlassCard {
                HStack(spacing: 12) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(LGradients.header)
                        .frame(width: 20, height: 20)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(LGradients.header, lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(1)
                    }

                    Spacer()

                    if selectedID == id {
                        Image("checkwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(LGradients.header)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ text: String) -> some View {
        GlassCard {
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reminderSubtitle(_ reminder: LureliaReminder) -> String {
        let date = reminder.nextFireAt ?? reminder.scheduledDate
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
