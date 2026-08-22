//
//  RoutineContractEditorView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct RoutineContractEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var routine: LureliaRoutine
    let renewingFrom: LureliaRoutineContract?

    @State private var dateCommitted: Date
    @State private var durationDays: Int
    @State private var contracteeName: String
    @State private var meaning: String
    @State private var decreeStatement: String
    @State private var consequences: String
    @State private var typedSignature: String
    @State private var validationMessage: String?

    private var routineTint: Color {
        Color(lureliaHex: routine.colorHex)
    }

    private var solidTextColor: Color {
        routineTint.wcagContrastingSolidTextColor
    }

    private var committedDatePreview: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter.string(from: dateCommitted)
    }

    private var canSign: Bool {
        [
            contracteeName,
            meaning,
            decreeStatement,
            consequences,
            typedSignature
        ].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    init(
        routine: LureliaRoutine,
        renewingFrom: LureliaRoutineContract? = nil
    ) {
        self.routine = routine
        self.renewingFrom = renewingFrom
        _dateCommitted = State(initialValue: Date())
        _durationDays = State(initialValue: renewingFrom?.durationDays ?? 30)
        _contracteeName = State(initialValue: renewingFrom?.contracteeName ?? "")
        _meaning = State(initialValue: "")
        _decreeStatement = State(initialValue: "")
        _consequences = State(initialValue: "")
        _typedSignature = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .routineDismissKeyboardOnTap()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        dateCard
                        statusCard
                        durationCard
                        identityCard
                        meaningCard
                        decreeCard
                        consequencesCard
                        signatureCard

                        if let validationMessage {
                            validationCard(validationMessage)
                        }

                        signButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 48)
                    .routinePageWidthLocked()
                }
                .routinePageScrollClipped(bottomClearance: 150)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                    .font(.system(size: 14, weight: .black, design: .rounded))
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(renewingFrom == nil ? "Create Contract" : "Renew Contract")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(routine.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
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
                    .foregroundStyle(solidTextColor)
                    .wcagContrastLift(on: routineTint)
                    .frame(width: 42, height: 42)
                    .background(routineTint, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var dateCard: some View {
        contractCard(title: "Date Committed", icon: "starcal") {
            routineDateSelector
        }
    }

    private var statusCard: some View {
        contractCard(title: "Status", icon: LureliaRoutineContractStatus.active.icon) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Active")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Current State")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(routineTint.opacity(0.38), lineWidth: 1)
            }
        }
    }

    private var durationCard: some View {
        contractCard(title: "Duration", icon: "hourglassfill") {
            LureliaGradientStepper(
                title: "",
                subtitle: "Days",
                value: $durationDays,
                range: 1...999,
                step: 1,
                tint: routineTint
            )
        }
    }

    private var routineDateSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                LureliaIconView(iconId: "starcal", size: 15)
                    .foregroundStyle(routineTint)

                Text(committedDatePreview)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(routineTint.opacity(0.52), lineWidth: 1)
            }

            HStack(spacing: 10) {
                dateStepButton(title: "Back", icon: "leftwavy", days: -1)
                dateStepButton(title: "Today", icon: "clockfill", days: nil)
                dateStepButton(title: "Forward", icon: "rightwavy", days: 1)
            }
        }
    }

    private var identityCard: some View {
        contractCard(title: "Name of Contractee", icon: "profileuser") {
            TextField("Your name", text: $contracteeName)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(routineTint.opacity(0.38), lineWidth: 1)
                }
        }
    }

    private var meaningCard: some View {
        contractCard(title: "Meaning", icon: "heartwavy") {
            documentField(
                prompt: "What does this commitment personally represent?",
                text: $meaning,
                minHeight: 132
            )
        }
    }

    private var decreeCard: some View {
        contractCard(title: "Decree Statement", icon: "writepencil") {
            documentField(
                prompt: "Write your formal declaration.",
                text: $decreeStatement,
                minHeight: 150
            )
        }
    }

    private var consequencesCard: some View {
        contractCard(title: "Consequences", icon: "warnwavy") {
            documentField(
                prompt: "Describe the consequences you chose for yourself.",
                text: $consequences,
                minHeight: 132
            )
        }
    }

    private var signatureCard: some View {
        contractCard(title: "Signature", icon: "circlefingerprint") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Type your name to sign this contract.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))

                TextField("Typed signature", text: $typedSignature)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(routineTint.opacity(0.52), lineWidth: 1.1)
                    }
            }
        }
    }

    private var signButton: some View {
        Button {
            signContract()
        } label: {
            HStack(spacing: 9) {
                Image("lockwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)

                Text("Sign Contract")
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundStyle(canSign ? solidTextColor : .white.opacity(0.38))
            .wcagContrastLift(on: routineTint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canSign ? routineTint : LColors.glassSurface2)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(canSign ? Color.white.opacity(0.18) : LColors.glassBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSign)
    }

    private func contractCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard(cornerRadius: 24, tint: routineTint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    LureliaIconView(iconId: icon, size: 16)
                        .foregroundStyle(routineTint)

                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }

                content()
            }
        }
    }

    private func documentField(
        prompt: String,
        text: Binding<String>,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(prompt, text: text, axis: .vertical)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(5...12)
                .padding(14)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LColors.glassSurface2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.02))
                        }
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LColors.glassBorder,
                            lineWidth: 1
                        )
                }
        }
    }

    private func dateStepButton(
        title: String,
        icon: String,
        days: Int?
    ) -> some View {
        Button {
            if let days {
                dateCommitted = Calendar.current.date(
                    byAdding: .day,
                    value: days,
                    to: dateCommitted
                ) ?? dateCommitted
            } else {
                dateCommitted = Date()
            }
        } label: {
            HStack(spacing: 6) {
                LureliaIconView(iconId: icon, size: 12)
                    .foregroundStyle(routineTint)

                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(routineTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(routineTint.opacity(0.42), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func validationCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            LureliaIconView(iconId: "xmarkwavy", size: 14)
                .foregroundStyle(routineTint)

            Text(message)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))

            Spacer()
        }
        .padding(14)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(routineTint.opacity(0.42), lineWidth: 1)
        }
    }

    private func signContract() {
        guard canSign else {
            validationMessage = "Complete every contract field before signing."
            return
        }

        for contract in routine.contracts ?? [] where contract.isCurrent {
            contract.isCurrent = false
            contract.updatedAt = Date()
        }

        if let renewingFrom {
            renewingFrom.status = .renewed
            renewingFrom.isCurrent = false
            renewingFrom.renewedAt = Date()
            renewingFrom.updatedAt = Date()
        }

        let contract = LureliaRoutineContract(
            routine: routine,
            dateCommitted: dateCommitted,
            durationDays: durationDays,
            contracteeName: contracteeName.trimmingCharacters(in: .whitespacesAndNewlines),
            meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
            decreeStatement: decreeStatement.trimmingCharacters(in: .whitespacesAndNewlines),
            consequences: consequences.trimmingCharacters(in: .whitespacesAndNewlines),
            typedSignature: typedSignature.trimmingCharacters(in: .whitespacesAndNewlines),
            renewedFromContractID: renewingFrom?.persistentID
        )

        modelContext.insert(contract)
        var routineContracts = routine.contracts ?? []
        routineContracts.append(contract)
        routine.contracts = routineContracts
        routine.updatedAt = Date()

        try? modelContext.save()
        dismiss()
    }
}
