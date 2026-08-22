//
//  HostPostPreviewCard.swift
//  Lurelia
//
//  Compact preview card for a single host post or announcement. Shows
//  the first heading, or the first meaningful line of the body, and a
//  pin badge when the post is pinned. Used inside SharedEventDetailView
//  and HostPostListView.
//

import SwiftUI

struct HostPostPreviewCard: View {
    let title: String
    let author: String
    let previewText: String
    let previewIsHeading: Bool
    let createdAt: Date
    let isPinned: Bool
    let isAnnouncement: Bool

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    if isPinned {
                        Text("PINNED")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.adaptivePrimaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LGradients.header))
                    }
                    if isAnnouncement {
                        Text("ANNOUNCEMENT")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LColors.warning.opacity(0.55)))
                    }
                    Spacer()
                    Text(createdAt, style: .relative)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }

                Text(previewText)
                    .font(
                        .system(
                            size: previewIsHeading ? 17 : 14,
                            weight: previewIsHeading ? .black : .semibold,
                            design: .rounded,
                        ),
                    )
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(previewIsHeading ? 2 : 3)
                    .multilineTextAlignment(.leading)

                Text(author)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }
}

// MARK: - Preview extraction

enum HostPostPreview {
    static func title(explicit: String?, markdown: String)
        -> (text: String, isHeading: Bool)
    {
        let clean = stripInlineMarkdown(explicit ?? "")
        if !clean.isEmpty { return (clean, false) }
        return extract(fromMarkdown: markdown)
    }

    /// Extract a short preview from Markdown body: the first `# / ## / ###`
    /// heading if present, otherwise the first non-empty paragraph.
    static func extract(fromMarkdown markdown: String)
        -> (text: String, isHeading: Bool)
    {
        let lines = markdown
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix(":::") }

        for line in lines {
            if line.hasPrefix("# ") { return (stripInlineMarkdown(String(line.dropFirst(2))), true) }
            if line.hasPrefix("## ") { return (stripInlineMarkdown(String(line.dropFirst(3))), true) }
            if line.hasPrefix("### ") { return (stripInlineMarkdown(String(line.dropFirst(4))), true) }
        }

        let firstText = lines.first(where: { !$0.hasPrefix(">") && !$0.hasPrefix("---") })
            ?? lines.first
            ?? ""
        let stripped = stripInlineMarkdown(firstText)
        return (stripped, false)
    }

    /// Cheap inline-markdown stripper for previews. Not a full parser —
    /// removes the marks that would otherwise leak into the preview text.
    private static func stripInlineMarkdown(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "**", with: "")
        out = out.replacingOccurrences(of: "__", with: "")
        out = out.replacingOccurrences(of: "`", with: "")
        // Turn [label](url) into label.
        let linkRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
        if let linkRegex {
            let range = NSRange(out.startIndex..<out.endIndex, in: out)
            out = linkRegex.stringByReplacingMatches(
                in: out,
                range: range,
                withTemplate: "$1",
            )
        }
        return out
    }
}
