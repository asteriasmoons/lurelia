//
//  PracticeCard.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct PracticeCard: View {
    let practice: LureliaPractice
    let routines: [LureliaRoutine]
    
    private var practiceTint: Color {
        Color(lureliaHex: practice.colorHex)
    }
    
    private var linkedRoutines: [LureliaRoutine] {
        let practiceIDString = practice.id.uuidString
        return routines.filter { $0.practiceID == practiceIDString }
    }
    
    private var routineCount: Int {
        linkedRoutines.count
    }
    
    private var progress: Double {
        let allRoutines = linkedRoutines
        guard !allRoutines.isEmpty else { return 0 }
        
        var totalTasks = 0
        var completedTasks = 0
        
        for routine in allRoutines {
            let tasks = routine.tasks ?? []
            totalTasks += tasks.count
            completedTasks += tasks.filter { $0.isCompleted || $0.isSkipped }.count
        }
        
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    // MARK: - Adaptive Colors
    
    private var adaptiveTextColor: Color {
        practiceTint.isLightColor ? .black.opacity(0.88) : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        practiceTint.isLightColor ? .black.opacity(0.62) : .white.opacity(0.72)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            
            // MARK: - Icon (LEFT)
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(practiceTint, lineWidth: 1.4)
                    )
                
                Circle()
                    .fill(practiceTint.opacity(0.22))
                    .frame(width: 38, height: 38)
                    .blur(radius: 12)
                
                LureliaIconView(iconId: practice.icon, size: 24)
                    .foregroundStyle(adaptiveTextColor)
            }
            .frame(width: 52, height: 52)
            
            // MARK: - Info (CENTER)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(practice.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(adaptiveTextColor)
                    .lineLimit(1)
                
                if !practice.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(practice.purpose)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(adaptiveSecondaryTextColor)
                        .lineLimit(1)
                }
                
                Text("\(routineCount) routine\(routineCount == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(adaptiveTextColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(adaptiveTextColor.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            // MARK: - Dotted Progress Ring (RIGHT)
            
            DottedProgressRing(
                progress: progress,
                size: 44,
                dotCount: 28,
                dotDiameter: 3.4,
                trackColor: adaptiveTextColor.opacity(0.16),
                fillColor: adaptiveTextColor.opacity(0.95)
            ) {
                Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(adaptiveTextColor)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(practiceTint.opacity(0.34))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.glassBorderStrong,
                                    practiceTint.opacity(0.28),
                                    LColors.gradientPurple.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: practiceTint.opacity(0.13), radius: 14, x: 0, y: 7)
    }
}
