//
//  RoutineContractsView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct RoutineContractsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LureliaRoutineContract.dateCommitted, order: .reverse)
    private var contracts: [LureliaRoutineContract]

    @State private var selectedContract: LureliaRoutineContract?

    private var currentContracts: [LureliaRoutineContract] {
        contracts.filter { $0.isCurrent }
    }

    private var pastContracts: [LureliaRoutineContract] {
        contracts.filter { !$0.isCurrent }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header

                        if contracts.isEmpty {
                            emptyState
                        } else {
                            contractSection("Current Contracts", contracts: currentContracts)
                            contractSection("Past Contracts", contracts: pastContracts)
                        }

                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .routinePageWidthLocked()
                }
                .routinePageScrollClipped(bottomClearance: 150)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedContract) { contract in
                RoutineContractDetailView(
                    contract: contract,
                    routine: contract.routine
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Contracts")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Current and past routine commitments.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        GlassCard(cornerRadius: 28) {
            VStack(spacing: 12) {
                LureliaIconView(iconId: "stardoc", size: 42)
                    .foregroundStyle(LColors.textPrimary)

                Text("No contracts yet")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Create one from a routine's detail page when you are ready to formally commit.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func contractSection(
        _ title: String,
        contracts: [LureliaRoutineContract]
    ) -> some View {
        if !contracts.isEmpty {
            GlassCard(cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(spacing: 10) {
                        ForEach(contracts) { contract in
                            contractTile(contract)
                        }
                    }
                }
            }
        }
    }

    private func contractTile(_ contract: LureliaRoutineContract) -> some View {
        let tint = Color(lureliaHex: contract.routineDisplayColorHex)
        let solidText = tint.wcagContrastingSolidTextColor

        return Button {
            selectedContract = contract
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 48, height: 48)

                    LureliaIconView(iconId: contract.routineDisplayIcon, size: 24)
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(contract.routineDisplayName)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(contract.contracteeName) · \(contract.committedDateText)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    LureliaIconView(iconId: contract.status.icon, size: 12)
                    Text(contract.status.rawValue)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundStyle(solidText)
                .wcagContrastLift(on: tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(tint, in: Capsule())
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [
                        tint.opacity(0.18),
                        LColors.glassSurface2
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tint.opacity(0.42), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
