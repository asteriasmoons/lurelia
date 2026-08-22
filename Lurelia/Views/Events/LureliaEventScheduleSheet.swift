//
//  LureliaEventScheduleSheet.swift
//  Lurelia
//
//  Tap the Schedule card in the event editor to open this. Handles the
//  all-day toggle, start/end dates (drum picker), and start/end times
//  (drum picker) so the main editor stays compact.
//

import SwiftUI
import UIKit

struct LureliaEventScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var isAllDay: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date

    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 10
    @State private var endMinute: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header

                        allDayCard
                        startsCard
                        endsCard

                        doneButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
            .onAppear { loadTimes() }
            .onChange(of: startHour) { _, _ in commitStartTime() }
            .onChange(of: startMinute) { _, _ in commitStartTime() }
            .onChange(of: endHour) { _, _ in commitEndTime() }
            .onChange(of: endMinute) { _, _ in commitEndTime() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Schedule")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

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
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private var allDayCard: some View {
        GlassCard {
            Toggle(isOn: $isAllDay) {
                Text("All Day")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .tint(Color.white.opacity(0.85))
        }
    }

    private var startsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("STARTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                LureliaGradientDateDrumPicker(date: $startDate)

                if !isAllDay {
                    LureliaGradientTimeDrumPicker(hour: $startHour, minute: $startMinute)
                }
            }
        }
    }

    private var endsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("ENDS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                LureliaGradientDateDrumPicker(date: $endDate)

                if !isAllDay {
                    LureliaGradientTimeDrumPicker(hour: $endHour, minute: $endMinute)
                }
            }
        }
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("Done")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background { LureliaNeutralGlassSurface(cornerRadius: 22) }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LColors.neutralPearl.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func loadTimes() {
        let s = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        startHour = s.hour ?? 9
        startMinute = s.minute ?? 0

        let e = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        endHour = e.hour ?? 10
        endMinute = e.minute ?? 0
    }

    private func commitStartTime() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: startTime)
        comps.hour = startHour
        comps.minute = startMinute
        comps.second = 0
        if let newDate = Calendar.current.date(from: comps), newDate != startTime {
            startTime = newDate
        }
    }

    private func commitEndTime() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: endTime)
        comps.hour = endHour
        comps.minute = endMinute
        comps.second = 0
        if let newDate = Calendar.current.date(from: comps), newDate != endTime {
            endTime = newDate
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
