//
//  RoutineCard.swift
//  Lurelia
//

import SwiftUI

struct RoutineCard: View {
    let routine: LureliaRoutine
    let onRun: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    
    private var isActive: Bool {
        routine.activeRun != nil
    }
    
    private var isPaused: Bool {
        routine.activeRun?.isPaused == true
    }
    
    private var routineTint: Color {
        Color(lureliaHex: routine.colorHex)
    }
    
    private var scheduleLabel: String {
        guard routine.scheduleEnabled && !routine.scheduledDays.isEmpty else {
            return "Unscheduled"
        }
        
        let symbols = Calendar.current.shortWeekdaySymbols
        
        let days = routine.scheduledDays
            .sorted()
            .compactMap { $0 >= 1 && $0 <= 7 ? symbols[$0 - 1] : nil }
            .joined(separator: ", ")
        
        return "\(days)  \(routine.formattedTimeRange)"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(routineTint.opacity(0.18))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .strokeBorder(LColors.glassBorderStrong, lineWidth: 1)
                    )
                
                Circle()
                    .fill(routineTint.opacity(0.22))
                    .frame(width: 44, height: 44)
                    .blur(radius: 12)
                
                LureliaIconView(iconId: routine.icon, size: 26)
                    .foregroundStyle(LColors.textPrimary)
            }
            .frame(width: 58, height: 58)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(routine.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\((routine.tasks ?? []).count) tasks")
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)
                    
                    Text("·")
                        .foregroundStyle(LColors.textSecondary.opacity(0.45))
                    
                    Text(scheduleLabel)
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)
                        .lineLimit(1)
                }
                
                if isActive {
                    Text(isPaused ? "Paused" : "In progress")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(routineTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(routineTint.opacity(0.14), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(routineTint.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image("slider")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(LColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(LColors.glassSurface, in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(LColors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                if isActive {
                    if isPaused {
                        Button {
                            onRun()
                        } label: {
                            Image("playwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(LColors.textPrimary)
                                .frame(width: 38, height: 38)
                                .background(routineTint.opacity(0.32), in: Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(routineTint.opacity(0.38), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            onPause()
                        } label: {
                            Image("pausewavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(LColors.textPrimary)
                                .frame(width: 38, height: 38)
                                .background(routineTint.opacity(0.28), in: Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(routineTint.opacity(0.36), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        onStop()
                    } label: {
                        Image("stopwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LColors.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(LColors.glassSurface2, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onRun()
                    } label: {
                        Image("playwavy")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(LColors.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(routineTint.opacity(0.32), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(routineTint.opacity(0.38), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(routineTint.opacity(0.34))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.glassBorderStrong,
                                    routineTint.opacity(0.28),
                                    LColors.gradientPurple.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: routineTint.opacity(0.13), radius: 14, x: 0, y: 7)
    }
}
