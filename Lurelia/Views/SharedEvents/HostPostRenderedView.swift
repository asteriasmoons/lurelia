//
//  HostPostRenderedView.swift
//  Lurelia
//
//  Native renderer for host posts and announcements. It renders the saved
//  markdown source directly, including Lurelia callout fences:
//
//      :::lurelia-callout icon="starcal" id="..."
//      Callout body
//      :::
//

import SwiftUI

struct HostPostRenderedView: View {
    let title: String
    let author: String
    let createdAt: Date
    let isPinned: Bool
    let isAnnouncement: Bool
    let bodyHTML: String
    let bodyMarkdown: String
    let onClose: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showingDeleteConfirm = false

    private var blocks: [HostPostMarkdownBlock] {
        HostPostNativeMarkdownParser.parse(bodyMarkdown)
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HostPostNativeBody(blocks: blocks)
                    Spacer().frame(height: 96)
                }
                .padding(.top, 12)
                .padding(.horizontal, LSpacing.pageHorizontal)
            }
        }
        .interactiveDismissDisabled(false)
        .alert("Delete this post?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes it from the shared event timeline.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if isPinned {
                    badge("PINNED", fill: AnyShapeStyle(LGradients.header))
                }
                if isAnnouncement {
                    badge("ANNOUNCEMENT", fill: AnyShapeStyle(LColors.warning.opacity(0.55)))
                }

                Spacer()

                if let onEdit {
                    actionIconButton(systemName: "pencil", accessibilityLabel: "Edit post") {
                        onEdit()
                    }
                }
                if onDelete != nil {
                    actionIconButton(assetName: "trash", accessibilityLabel: "Delete post") {
                        showingDeleteConfirm = true
                    }
                }
                actionIconButton(assetName: "xmarkwavy", accessibilityLabel: "Close") {
                    onClose()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(3)

                Text("\(author) · ")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    + Text(createdAt, style: .relative)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
    }

    private func badge(_ text: String, fill: AnyShapeStyle) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(LColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }

    @ViewBuilder
    private func actionIconButton(
        assetName: String? = nil,
        systemName: String? = nil,
        accessibilityLabel: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Group {
                if let assetName {
                    Image(assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 17, weight: .black))
                }
            }
            .frame(width: 20, height: 20)
            .foregroundStyle(LGradients.header)
            .frame(width: 38, height: 38)
            .background(LColors.glassSurface, in: Circle())
            .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct HostPostNativeBody: View {
    let blocks: [HostPostMarkdownBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: HostPostMarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            richText(text, size: level == 1 ? 26 : (level == 2 ? 22 : 19), weight: .black)
                .padding(.top, level == 1 ? 12 : 4)
        case .paragraph(let text):
            richText(text, size: 17, weight: .regular)
                .lineSpacing(4)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        richText(item, size: 17, weight: .regular)
                    }
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(offset + 1).")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(minWidth: 24, alignment: .trailing)
                        richText(item, size: 17, weight: .regular)
                    }
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LColors.accent)
                    .frame(width: 3)
                richText(text, size: 16, weight: .semibold)
                    .foregroundStyle(LColors.textSecondary)
            }
            .padding(.vertical, 4)
        case .image(let alt, let url):
            imageBlock(alt: alt, url: url)
        case .callout(let icon, let text):
            callout(icon: icon, text: text)
        }
    }

    private func imageBlock(alt: String, url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            case .failure:
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .black))
                    Text(alt.isEmpty ? "Image unavailable" : alt)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(LColors.textSecondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            case .empty:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LColors.glassSurface2)
                    .frame(height: 180)
                    .overlay(ProgressView().tint(LColors.accent))
            @unknown default:
                EmptyView()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LColors.glassBorder, lineWidth: 1),
        )
    }

    private func callout(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LColors.glassSurface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(LColors.glassBorder, lineWidth: 1),
                    )
                LureliaIconView(iconId: icon.isEmpty ? "starcal" : icon, size: 24)
                    .foregroundStyle(LColors.textPrimary)
            }
            .frame(width: 54, height: 54)

            richText(text, size: 16, weight: .semibold)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    LColors.gradientBlue.opacity(0.14),
                    LColors.gradientPurple.opacity(0.18),
                    LColors.glassSurface2,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LColors.accent.opacity(0.55), lineWidth: 1),
        )
    }

    private func richText(_ text: String, size: CGFloat, weight: Font.Weight) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
        }

        return Text(text)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(LColors.textPrimary)
    }
}

private enum HostPostMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case quote(String)
    case image(alt: String, url: URL)
    case callout(icon: String, text: String)
}

private enum HostPostNativeMarkdownParser {
    static func parse(_ markdown: String) -> [HostPostMarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [HostPostMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let raw = lines[index]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                index += 1
                continue
            }

            if line.hasPrefix(":::lurelia-callout") {
                let icon = parseAttribute("icon", from: line) ?? "starcal"
                index += 1
                var bodyLines: [String] = []
                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespaces)
                    if next == ":::" { break }
                    bodyLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                let text = bodyLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.callout(icon: icon, text: text))
                continue
            }

            if isHTMLCalloutStart(line) {
                let icon = parseHTMLAttribute("data-icon", from: raw) ?? "starcal"
                var htmlLines = [raw]
                index += 1
                while index < lines.count,
                      !lines[index - 1].contains("</div>") {
                    htmlLines.append(lines[index])
                    index += 1
                }
                let text = htmlCalloutText(from: htmlLines.joined(separator: "\n"))
                blocks.append(.callout(icon: icon, text: text))
                continue
            }

            if line.hasPrefix("### ") {
                blocks.append(.heading(level: 3, text: String(line.dropFirst(4))))
                index += 1
                continue
            }
            if line.hasPrefix("## ") {
                blocks.append(.heading(level: 2, text: String(line.dropFirst(3))))
                index += 1
                continue
            }
            if line.hasPrefix("# ") {
                blocks.append(.heading(level: 1, text: String(line.dropFirst(2))))
                index += 1
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while index < lines.count {
                    let itemLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if itemLine.hasPrefix("- ") || itemLine.hasPrefix("* ") {
                        items.append(String(itemLine.dropFirst(2)))
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bullets(items))
                continue
            }

            if isNumberedListLine(line) {
                var items: [String] = []
                while index < lines.count {
                    let itemLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if let item = numberedListText(itemLine) {
                        items.append(item)
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numbered(items))
                continue
            }

            if line.hasPrefix("> ") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let quoteLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if quoteLine.hasPrefix("> ") {
                        quoteLines.append(String(quoteLine.dropFirst(2)))
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.quote(quoteLines.joined(separator: "\n")))
                continue
            }

            if let image = imageBlock(from: line) {
                blocks.append(image)
                index += 1
                continue
            }

            var paragraphLines = [line]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty
                    || next.hasPrefix("# ")
                    || next.hasPrefix("## ")
                    || next.hasPrefix("### ")
                    || next.hasPrefix("- ")
                    || next.hasPrefix("* ")
                    || isNumberedListLine(next)
                    || next.hasPrefix("> ")
                    || next.hasPrefix(":::lurelia-callout")
                    || isHTMLCalloutStart(next)
                {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
        }

        return blocks
    }

    private static func parseAttribute(_ name: String, from line: String) -> String? {
        let pattern = #"\#(name)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[valueRange])
    }

    private static func isHTMLCalloutStart(_ line: String) -> Bool {
        line.contains("<div")
            && (
                line.contains(#"data-type="lurelia-callout""#)
                    || line.contains(#"data-type='lurelia-callout'"#)
                    || line.contains(#"class="callout""#)
                    || line.contains(#"class='callout'"#)
            )
    }

    private static func parseHTMLAttribute(_ name: String, from line: String) -> String? {
        let pattern = #"\#(name)=["']([^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[valueRange])
    }

    private static func htmlCalloutText(from html: String) -> String {
        let withLineBreaks = html
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</p\s*>"#, with: "\n\n", options: .regularExpression)
        let withoutTags = withLineBreaks.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression,
        )
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: #"""#)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isNumberedListLine(_ line: String) -> Bool {
        numberedListText(line) != nil
    }

    private static func numberedListText(_ line: String) -> String? {
        let pattern = #"^\d+\.\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[valueRange])
    }

    private static func imageBlock(from line: String) -> HostPostMarkdownBlock? {
        let pattern = #"^!\[([^\]]*)\]\(([^)]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let altRange = Range(match.range(at: 1), in: line),
              let urlRange = Range(match.range(at: 2), in: line),
              let url = URL(string: String(line[urlRange])) else { return nil }
        return .image(alt: String(line[altRange]), url: url)
    }
}
