//
//  LureliaEventOccurrenceRow.swift
//  Lurelia
//
//  A single event row used by all three event list views. Its container
//  style is switchable so the same row can appear as a `GlassCard`
//  (Agenda + Month) or a `FrostyTile` (Week) without duplicating layout.
//

import SwiftUI

enum LureliaEventRowStyle {
    case glass
    case frosty
}

struct LureliaEventOccurrenceRow: View {
    let row: LureliaEventUnifiedOccurrence
    let onSelect: (LureliaEventUnifiedOccurrence) -> Void
    var style: LureliaEventRowStyle = .glass

    var body: some View {
        Button {
            onSelect(row)
        } label: {
            rowContainer {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 42, height: 42)

                        LureliaIconView(iconId: row.icon, size: 20)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(row.title)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            if row.calendarName != nil {
                                Circle()
                                    .fill(row.color)
                                    .frame(width: 7, height: 7)
                            }

                            Text(row.subtitle)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    if row.isApple {
                        Text("APPLE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 1))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func rowContainer<Inner: View>(@ViewBuilder content: () -> Inner) -> some View {
        switch style {
        case .glass:
            GlassCard(cornerRadius: 20, padding: 12, tint: row.color) {
                content()
            }
        case .frosty:
            FrostyTile(cornerRadius: 16, padding: 12) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(row.color.opacity(0.16))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(row.color.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: row.color.opacity(0.12), radius: 12, y: 6)
        }
    }
}
