//
//  LureliaComponents.swift
//  Lurelia
//

import SwiftUI

// MARK: - Lurelia Background

struct LureliaBackground: View {
    var body: some View {
        ZStack {
            // Base background
            LColors.bg
                .ignoresSafeArea()
            
            // Ambient glows
            LGradients.bgPurple
                .blendMode(.screen)
                .ignoresSafeArea()
            
            LGradients.bgCyan
                .blendMode(.screen)
                .ignoresSafeArea()
            
            LGradients.bgYellow
                .blendMode(.screen)
                .ignoresSafeArea()
            
            LGradients.bgPink
                .blendMode(.screen)
                .ignoresSafeArea()
            
            // Soft vignette
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Atmosphere overlay
            Rectangle()
                .fill(Color.white.opacity(0.015))
                .blendMode(.softLight)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Alternate Lurelia Background

struct LureliaBackgroundAlt: View {
    var body: some View {
        LColors.bgSoft
            .ignoresSafeArea()
    }
}

// MARK: - Gradient Time Drum Picker

struct LureliaGradientTimeDrumPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    
    @State private var displayHour: Int = 9
    @State private var meridiem: String = "AM"
    @State private var isSyncingFromStoredHour = false
    
    private let meridiems = ["AM", "PM"]
    
    private var formattedPreview: String {
        String(format: "%d:%02d %@", displayHour, minute, meridiem)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LGradients.header)
                
                Text(formattedPreview)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LColors.glassSurface2,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LColors.gradientBlue.opacity(0.45),
                                LColors.gradientPurple.opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.10),
                                        LColors.gradientPurple.opacity(0.14),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(LColors.glassBorder, lineWidth: 1)
                    )
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.20),
                                    LColors.gradientPurple.opacity(0.20)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            LColors.gradientBlue.opacity(0.55),
                                            LColors.gradientPurple.opacity(0.55)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                
                HStack(spacing: 6) {
                    Picker("Hour", selection: $displayHour) {
                        ForEach(1...12, id: \.self) { value in
                            Text("\(value)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    
                    Text(":")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)
                    
                    Picker("Minute", selection: $minute) {
                        ForEach(0..<60, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    
                    Picker("AM PM", selection: $meridiem) {
                        ForEach(meridiems, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 138)
        }
        .onAppear {
            syncDisplayValuesFromStoredHour()
        }
        .onChange(of: displayHour) {
            syncStoredHour()
        }
        .onChange(of: meridiem) {
            syncStoredHour()
        }
        .onChange(of: hour) {
            syncDisplayValuesFromStoredHour()
        }
    }
    
    private func syncDisplayValuesFromStoredHour() {
        isSyncingFromStoredHour = true
        
        let normalizedHour = max(0, min(23, hour))
        
        if normalizedHour == 0 {
            displayHour = 12
            meridiem = "AM"
        } else if normalizedHour < 12 {
            displayHour = normalizedHour
            meridiem = "AM"
        } else if normalizedHour == 12 {
            displayHour = 12
            meridiem = "PM"
        } else {
            displayHour = normalizedHour - 12
            meridiem = "PM"
        }
        
        isSyncingFromStoredHour = false
    }
    
    private func syncStoredHour() {
        guard !isSyncingFromStoredHour else { return }
        
        if meridiem == "AM" {
            hour = displayHour == 12 ? 0 : displayHour
        } else {
            hour = displayHour == 12 ? 12 : displayHour + 12
        }
    }
}

// MARK: - Completion Banner

struct LureliaCompletionBanner: View {
    let message: String
    var isShowing: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image("checkwavy")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(LGradients.header)
                .shadow(color: LColors.gradientPurple.opacity(0.4), radius: 16, y: 6)
        )
        .opacity(isShowing ? 1 : 0)
        .offset(y: isShowing ? 0 : -20)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isShowing)
    }
}

extension View {
    func completionBanner(isShowing: Bool, message: String = "Done!") -> some View {
        self.overlay(alignment: .top) {
            LureliaCompletionBanner(message: message, isShowing: isShowing)
                .padding(.top, 16)
                .zIndex(999)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LureliaBackground()
        
        Text("Lurelia")
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(LGradients.header)
    }
}
