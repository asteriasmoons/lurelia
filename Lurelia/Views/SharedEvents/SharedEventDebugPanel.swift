//
//  SharedEventDebugPanel.swift
//  Lurelia
//
//  DEBUG-only tester embedded in the shared event detail sheet. Provides
//  one-tap simulation of another participant (join / RSVP / comment /
//  host post / announcement) so a single device can verify live sync
//  and APNs delivery without a second Apple ID.
//
//  Compiled out of Release builds via `#if DEBUG`. The backend endpoint
//  it calls also 404s in production unless LURELIA_DEBUG_ENABLED=true,
//  so there's no way for these controls to reach real users.
//

#if DEBUG
import SwiftUI

struct SharedEventDebugPanel: View {
    let eventID: String
    let currentUserID: String
    let currentDisplayName: String
    let onSimulated: () -> Void

    @State private var isRunning = false
    @State private var lastResult: String?
    @State private var lastError: String?

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Debug — simulate activity")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Text("DEBUG")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LColors.warning.opacity(0.6)))
                }

                Text("These buttons never appear in Release builds. They ask vox-api to simulate a second participant on this event so live updates and push notifications can be verified from one device.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ],
                    spacing: 8,
                ) {
                    button("Sim join") {
                        await run(kind: "join")
                    }
                    button("Sim RSVP going") {
                        await run(kind: "rsvp", status: "going")
                    }
                    button("Sim comment") {
                        await run(kind: "comment")
                    }
                    button("Sim host post") {
                        await run(
                            kind: "hostPost",
                            hostUserID: currentUserID,
                            hostDisplayName: currentDisplayName,
                        )
                    }
                    button("Sim announcement") {
                        await run(
                            kind: "announcement",
                            hostUserID: currentUserID,
                            hostDisplayName: currentDisplayName,
                        )
                    }
                    button("Sim RSVP interested") {
                        await run(kind: "rsvp", status: "interested")
                    }
                }
                .disabled(isRunning)
                .opacity(isRunning ? 0.5 : 1)

                if let result = lastResult {
                    Text(result)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.success)
                }
                if let err = lastError {
                    Text(err)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.danger)
                        .lineLimit(3)
                }
            }
        }
    }

    @ViewBuilder
    private func button(_ label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .fill(LColors.glassSurface2),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.55),
                                    LColors.gradientPurple.opacity(0.55),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                            lineWidth: 1,
                        ),
                )
        }
        .buttonStyle(.plain)
    }

    private func run(
        kind: String,
        status: String? = nil,
        body: String? = nil,
        hostUserID: String? = nil,
        hostDisplayName: String? = nil,
    ) async {
        isRunning = true
        defer { isRunning = false }
        lastError = nil
        do {
            try await SharedEventsService.shared.simulateActivity(
                eventID: eventID,
                kind: kind,
                status: status,
                body: body,
                hostUserID: hostUserID,
                hostDisplayName: hostDisplayName,
            )
            let stamp = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .none,
                timeStyle: .medium,
            )
            lastResult = "✓ \(kind)\(status.map { " (\($0))" } ?? "") @ \(stamp)"
            onSimulated()
        } catch {
            lastError = String(describing: error)
        }
    }
}
#endif
