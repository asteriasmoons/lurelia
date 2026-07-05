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
    
    private var taskCount: Int {
        (routine.tasks ?? []).count
    }

    private var phaseCount: Int {
        routine.phasesEnabled ? routine.sortedPhases.count : 0
    }

    private var scheduleStatusText: String {
        routine.scheduleEnabled && !routine.scheduledDays.isEmpty ? "Scheduled" : "Unscheduled"
    }

    private var weekdayPillText: String {
        guard routine.scheduleEnabled && !routine.scheduledDays.isEmpty else {
            return "None"
        }

        let symbols = Calendar.current.shortWeekdaySymbols

        return routine.scheduledDays
            .sorted()
            .compactMap { weekday in
                guard weekday >= 1 && weekday <= 7 else { return nil }
                return String(symbols[weekday - 1].prefix(3))
            }
            .joined(separator: " ")
    }
    
    private var taskPhaseText: String {
        let taskWord = taskCount == 1 ? "Task" : "Tasks"
        let phaseWord = phaseCount == 1 ? "Phase" : "Phases"

        return "\(taskCount) \(taskWord) • \(phaseCount) \(phaseWord)"
    }

    private var weekdayDisplayText: String {
        let days: [Int]

        if routine.phasesEnabled {
            days = Array(
                Set(
                    routine.sortedPhases
                        .filter { $0.scheduleEnabled }
                        .flatMap { $0.scheduledDays }
                )
            )
            .sorted()
        } else {
            days = routine.scheduleEnabled ? routine.scheduledDays.sorted() : []
        }

        guard !days.isEmpty else {
            return "No Schedule"
        }
        if Set(days) == Set(1...7) {
            return "Daily"
        }

        let symbols = Calendar.current.shortWeekdaySymbols

        return days
            .compactMap { weekday in
                guard weekday >= 1 && weekday <= 7 else { return nil }
                return String(symbols[weekday - 1].prefix(3))
            }
            .joined(separator: " • ")
    }

    private var timeDisplayText: String {
        "\(routine.formattedStartTime) – \(routine.formattedEndTime)"
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
            
            VStack(alignment: .leading, spacing: 5) {
                Text(routine.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)

                Text(taskPhaseText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.9))
                    .lineLimit(1)

                Text(weekdayDisplayText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(routineTint)
                    .lineLimit(1)

                Text(timeDisplayText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary.opacity(0.85))
                    .lineLimit(1)

                if isActive {
                    Text(isPaused ? "Paused" : "In progress")
                        .font(.system(size: 10, weight: .black, design: .rounded))
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
                    Image("settings")
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
    private func routineInfoPill(title: String, subtitle: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle.uppercased())
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textSecondary.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            routineTint.opacity(0.18),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(routineTint.opacity(0.45), lineWidth: 1)
        }
    }
}
