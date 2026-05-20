//
//  KanbanCardPickerView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

// MARK: - KanbanCardPickerView

struct KanbanCardPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var column: KanbanColumn

    let allReminders: [LureliaReminder]

    var onCreateReminder: () -> Void

    // Already-pinned IDs
    private var pinnedReminderIDs: Set<String> {
        Set((column.cards ?? []).filter { $0.cardType == .reminder }.map { $0.itemID })
    }

    private var availableReminders: [LureliaReminder] {
        allReminders.filter { !pinnedReminderIDs.contains($0.id.uuidString) }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        ZStack {
            LureliaBackground()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Reminder")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Pick an existing reminder or create a new one.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Button {
                    dismiss()
                    onCreateReminder()
                } label: {
                    HStack(spacing: 10) {
                        Image("bellfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(LGradients.header)

                        Text("New Reminder")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Divider().overlay(LColors.glassBorder)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        if availableReminders.isEmpty {
                            emptyPicker(label: "No reminders available")
                        } else {
                            ForEach(availableReminders) { reminder in
                                existingReminderRow(reminder)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
            }
        }
    }

    // MARK: Existing rows

    private func existingReminderRow(_ reminder: LureliaReminder) -> some View {
        Button { addCard(type: .reminder, itemID: reminder.id.uuidString) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LColors.gradientPurple.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image("bellfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(LColors.gradientPurple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(1)
                    Text(reminder.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(LColors.gradientPurple)
            }
            .padding(12)
            .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func emptyPicker(label: String) -> some View {
        Text(label)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(LColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    // MARK: Pin existing item

    private func addCard(type: KanbanCardType, itemID: String) {
        let card = KanbanCard(cardType: .reminder, itemID: UUID(), sortOrder: (column.cards ?? []).count)
        card.itemID = itemID
        modelContext.insert(card)
        if column.cards == nil {
            column.cards = []
        }
        column.cards?.append(card)
        try? modelContext.save()
        dismiss()
    }
}
