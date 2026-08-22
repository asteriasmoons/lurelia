//
//  SharedEventShareTools.swift
//  Lurelia
//
//  QR code + share sheet helpers used by SharedEventDetailView.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum SharedEventShareTools {
    private static let publicEventHost = "docs.voxiverse.ink"

    /// Public website link for the event. The web page handles previews,
    /// QR sharing, download fallback, and app handoff.
    static func deepLink(for eventID: String, inviteToken: String?) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = publicEventHost
        comps.path = "/events/\(eventID)"
        if let token = inviteToken, !token.isEmpty {
            comps.queryItems = [URLQueryItem(name: "invite", value: token)]
        }
        return comps.url ?? URL(string: "https://\(publicEventHost)")!
    }

    /// Renders a QR code UIImage for the given string. Nil if generation
    /// fails (extremely rare — the filter accepts any UTF-8).
    static func qrCode(from string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct SharedEventQRView: View {
    let eventID: String
    let inviteToken: String?
    let title: String

    var body: some View {
        let link = SharedEventShareTools.deepLink(for: eventID, inviteToken: inviteToken)
        VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .multilineTextAlignment(.center)

            if let qr = SharedEventShareTools.qrCode(from: link.absoluteString) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LColors.glassSurface)
                    .frame(width: 240, height: 240)
                    .overlay(
                        Text("QR unavailable")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary),
                    )
            }

            Text(link.absoluteString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LColors.textSecondary)
                .padding(.horizontal, 24)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }
}

/// UIActivityViewController-backed share sheet. Kept as a
/// UIViewControllerRepresentable so the caller can present it with the
/// same `.sheet` pattern used elsewhere.
struct SharedEventShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
