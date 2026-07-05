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

// MARK: - Gradient Stepper

struct LureliaGradientStepper: View {
    let title: String
    let subtitle: String?
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...999
    var step: Int = 1

    private var canDecrease: Bool {
        value - step >= range.lowerBound
    }

    private var canIncrease: Bool {
        value + step <= range.upperBound
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            stepperButton(icon: "minuswavy", isEnabled: canDecrease) {
                value = max(range.lowerBound, value - step)
            }

            Text("\(value)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(minWidth: 38)

            stepperButton(icon: "addwavy", isEnabled: canIncrease) {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func stepperButton(
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LGradients.header)
                .opacity(isEnabled ? 1 : 0.28)
                .frame(width: 22, height: 22)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.07), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(LGradients.header.opacity(isEnabled ? 0.85 : 0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = LSpacing.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LColors.glassSurface2)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.18),
                                        LColors.gradientPurple.opacity(0.22),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.92),
                                        LColors.gradientPurple.opacity(0.92),
                                        Color.white.opacity(0.38)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.05
                            )
                    }
            }
            .shadow(color: LColors.gradientBlue.opacity(0.18), radius: 16, y: 8)
            .shadow(color: LColors.gradientPurple.opacity(0.14), radius: 18, y: 10)
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
    
    private let meridiems = ["AM", "PM"]
    
    private var formattedPreview: String {
        String(format: "%d:%02d %@", displayHour, minute, meridiem)
    }

    private var displayHourBinding: Binding<Int> {
        Binding(
            get: { displayHour },
            set: { newValue in
                let clamped = max(1, min(12, newValue))
                guard displayHour != clamped else { return }
                displayHour = clamped
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { max(0, min(59, minute)) },
            set: { newValue in
                let clamped = max(0, min(59, newValue))
                guard minute != clamped else { return }
                minute = clamped
            }
        )
    }

    private var meridiemBinding: Binding<String> {
        Binding(
            get: { meridiem },
            set: { newValue in
                guard meridiems.contains(newValue), meridiem != newValue else { return }
                meridiem = newValue
            }
        )
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
                    LureliaDrumPickerColumn(
                        values: Array(1...12),
                        labels: Array(1...12).map { "\($0)" },
                        selection: displayHourBinding
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()

                    Text(":")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(LGradients.header)

                    LureliaDrumPickerColumn(
                        values: Array(0..<60),
                        labels: Array(0..<60).map { String(format: "%02d", $0) },
                        selection: minuteBinding
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()

                    LureliaDrumPickerColumn(
                        values: meridiems,
                        labels: meridiems,
                        selection: meridiemBinding
                    )
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
        .onChange(of: displayHour) { _, _ in
            syncStoredHour()
        }
        .onChange(of: meridiem) { _, _ in
            syncStoredHour()
        }
        .onChange(of: hour) { _, _ in
            syncDisplayValuesFromStoredHour()
        }
    }
    
    private func syncDisplayValuesFromStoredHour() {
        let normalizedHour = max(0, min(23, hour))
        let newDisplayHour: Int
        let newMeridiem: String

        if normalizedHour == 0 {
            newDisplayHour = 12
            newMeridiem = "AM"
        } else if normalizedHour < 12 {
            newDisplayHour = normalizedHour
            newMeridiem = "AM"
        } else if normalizedHour == 12 {
            newDisplayHour = 12
            newMeridiem = "PM"
        } else {
            newDisplayHour = normalizedHour - 12
            newMeridiem = "PM"
        }

        guard displayHour != newDisplayHour || meridiem != newMeridiem else { return }

        displayHour = newDisplayHour
        meridiem = newMeridiem
    }

    private func syncStoredHour() {
        let newHour: Int
        if meridiem == "AM" {
            newHour = displayHour == 12 ? 0 : displayHour
        } else {
            newHour = displayHour == 12 ? 12 : displayHour + 12
        }

        guard hour != newHour else { return }
        hour = newHour
    }
}

// MARK: - Tinted Time Drum Picker (Routine Tint)

struct LureliaTintedTimeDrumPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let tint: Color

    @State private var displayHour: Int = 9
    @State private var meridiem: String = "AM"

    private let meridiems = ["AM", "PM"]

    private var formattedPreview: String {
        String(format: "%d:%02d %@", displayHour, minute, meridiem)
    }

    private var displayHourBinding: Binding<Int> {
        Binding(
            get: { displayHour },
            set: { newValue in
                let clamped = max(1, min(12, newValue))
                guard displayHour != clamped else { return }
                displayHour = clamped
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { max(0, min(59, minute)) },
            set: { newValue in
                let clamped = max(0, min(59, newValue))
                guard minute != clamped else { return }
                minute = clamped
            }
        )
    }

    private var meridiemBinding: Binding<String> {
        Binding(
            get: { meridiem },
            set: { newValue in
                guard meridiems.contains(newValue), meridiem != newValue else { return }
                meridiem = newValue
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)

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
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(tint.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(LColors.glassBorder, lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    Spacer()

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.20))
                        .frame(height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(tint.opacity(0.55), lineWidth: 1)
                        )

                    Spacer()
                }
                .padding(.horizontal, 12)

                HStack(spacing: 6) {
                    LureliaDrumPickerColumn(
                        values: Array(1...12),
                        labels: Array(1...12).map { "\($0)" },
                        selection: displayHourBinding
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()

                    Text(":")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(tint)

                    LureliaDrumPickerColumn(
                        values: Array(0..<60),
                        labels: Array(0..<60).map { String(format: "%02d", $0) },
                        selection: minuteBinding
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()

                    LureliaDrumPickerColumn(
                        values: meridiems,
                        labels: meridiems,
                        selection: meridiemBinding
                    )
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
        .onChange(of: displayHour) { _, _ in
            syncStoredHour()
        }
        .onChange(of: meridiem) { _, _ in
            syncStoredHour()
        }
        .onChange(of: hour) { _, _ in
            syncDisplayValuesFromStoredHour()
        }
    }

    private func syncDisplayValuesFromStoredHour() {
        let normalizedHour = max(0, min(23, hour))
        let newDisplayHour: Int
        let newMeridiem: String

        if normalizedHour == 0 {
            newDisplayHour = 12
            newMeridiem = "AM"
        } else if normalizedHour < 12 {
            newDisplayHour = normalizedHour
            newMeridiem = "AM"
        } else if normalizedHour == 12 {
            newDisplayHour = 12
            newMeridiem = "PM"
        } else {
            newDisplayHour = normalizedHour - 12
            newMeridiem = "PM"
        }

        guard displayHour != newDisplayHour || meridiem != newMeridiem else { return }

        displayHour = newDisplayHour
        meridiem = newMeridiem
    }

    private func syncStoredHour() {
        let newHour: Int
        if meridiem == "AM" {
            newHour = displayHour == 12 ? 0 : displayHour
        } else {
            newHour = displayHour == 12 ? 12 : displayHour + 12
        }

        guard hour != newHour else { return }
        hour = newHour
    }
}

// MARK: - Pure SwiftUI Drum Picker Column

private struct LureliaDrumPickerColumn<Value: Hashable>: View {
    let values: [Value]
    let labels: [String]
    @Binding var selection: Value

    private let itemHeight: CGFloat = 38

    @State private var dragOffset: CGFloat = 0
    @State private var baseOffset: CGFloat = 0
    @State private var isDragging = false

    private var selectedIndex: Int {
        values.firstIndex(of: selection) ?? 0
    }

    private var totalOffset: CGFloat {
        baseOffset + dragOffset
    }

    private var currentIndex: Int {
        let raw = -totalOffset / itemHeight
        return max(0, min(values.count - 1, Int(raw.rounded())))
    }

    var body: some View {
        GeometryReader { geo in
            let centerY = (geo.size.height - itemHeight) / 2

            ZStack {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let offsetY = centerY + CGFloat(index) * itemHeight + totalOffset
                    let distanceFromCenter = abs(offsetY - centerY)
                    let normalized = max(0, 1 - distanceFromCenter / (itemHeight * 1.5))

                    Text(labels.indices.contains(index) ? labels[index] : "")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3 + 0.65 * normalized))
                        .scaleEffect(0.85 + 0.2 * normalized)
                        .frame(height: itemHeight)
                        .frame(maxWidth: .infinity)
                        .offset(y: offsetY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        isDragging = false
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let projected = totalOffset + velocity * 0.3
                        let rawIndex = -projected / itemHeight
                        let snapped = max(0, min(values.count - 1, Int(rawIndex.rounded())))
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            baseOffset = -CGFloat(snapped) * itemHeight
                            dragOffset = 0
                        }
                        if values.indices.contains(snapped) {
                            selection = values[snapped]
                        }
                    }
            )
            .onAppear {
                baseOffset = -CGFloat(selectedIndex) * itemHeight
            }
            .onChange(of: selection) { _, _ in
                guard !isDragging else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    baseOffset = -CGFloat(selectedIndex) * itemHeight
                    dragOffset = 0
                }
            }
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
