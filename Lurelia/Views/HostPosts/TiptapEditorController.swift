//
//  TiptapEditorController.swift
//  Lurelia
//
//  Observable state + command surface for the Tiptap-in-WKWebView editor.
//

import Foundation
import Combine
import SwiftUI
import UIKit
import WebKit

@MainActor
final class TiptapEditorController: ObservableObject {
    // MARK: Toolbar state (published)
    @Published var isReady: Bool = false
    @Published var markdown: String = ""
    @Published var html: String = ""
    @Published var isEmpty: Bool = true
    @Published var toolbar: TiptapToolbarState = .init()

    // MARK: Requests published to the parent view
    @Published var pendingImageRequest: UUID?
    @Published var pendingFileRequest: UUID?
    @Published var pendingLinkRequest: PendingLinkRequest?
    @Published var pendingIconPickerRequest: PendingIconPickerRequest?

    // MARK: Webview handle
    weak var webView: WKWebView?

    // MARK: - Command dispatch

    func setInitialMarkdown(_ markdown: String) {
        registerCalloutIcons(from: markdown)
        run("setContent", args: ["markdown": markdown])
    }

    func toggleBold()          { run("toggleBold") }
    func toggleItalic()        { run("toggleItalic") }
    func toggleUnderline()     { run("toggleUnderline") }
    func toggleStrike()        { run("toggleStrike") }
    func toggleCode()          { run("toggleCode") }
    func toggleBlockquote()    { run("toggleBlockquote") }
    func toggleCodeBlock()     { run("toggleCodeBlock") }
    func toggleBulletList()    { run("toggleBulletList") }
    func toggleOrderedList()   { run("toggleOrderedList") }
    func clearFormatting()     { run("clearFormatting") }
    func undo()                { run("undo") }
    func redo()                { run("redo") }
    func focus()               { run("focus") }
    func blur()                { run("blur") }
    func setHeading(_ level: Int) {
        run("setHeading", args: ["level": level])
    }
    func insertCallout(icon: String, text: String = "") {
        registerIconAsset(icon)
        run("insertCallout", args: ["icon": icon, "text": text])
    }
    func updateCalloutIcon(calloutId: String, icon: String) {
        registerIconAsset(icon)
        run("updateCalloutIcon", args: ["calloutId": calloutId, "icon": icon])
    }
    func setLink(_ href: String) {
        run("setLink", args: ["href": href])
    }
    func unsetLink() { run("unsetLink") }

    /// Insert an already-uploaded image URL into the editor at the cursor.
    func insertImage(url: String, alt: String = "") {
        run("insertImage", args: ["url": url, "alt": alt])
    }

    /// Insert a file-chip link to an already-uploaded file URL.
    func insertFileLink(url: String, filename: String) {
        run("insertFileLink", args: ["url": url, "filename": filename])
    }

    func requestImagePicker() { pendingImageRequest = UUID() }
    func requestFilePicker()  { pendingFileRequest = UUID() }

    // MARK: - Internal (called by the coordinator)

    func handleMessage(kind: String, payload: [String: Any]) {
        switch kind {
        case "ready":
            isReady = true
            registerIconAsset("starcal")
            if let toolbar = payload["toolbar"] as? [String: Any] {
                self.toolbar = TiptapToolbarState(dict: toolbar)
            }
        case "update":
            markdown = (payload["markdown"] as? String) ?? ""
            html = (payload["html"] as? String) ?? ""
            isEmpty = (payload["isEmpty"] as? Bool) ?? true
        case "selectionChange":
            toolbar = TiptapToolbarState(dict: payload)
        case "imageRequest":
            pendingImageRequest = UUID()
        case "fileRequest":
            pendingFileRequest = UUID()
        case "linkRequest":
            let current = (payload["currentHref"] as? String) ?? ""
            pendingLinkRequest = PendingLinkRequest(currentHref: current)
        case "iconPickerRequest":
            let calloutId = (payload["calloutId"] as? String) ?? ""
            let currentIcon = (payload["currentIcon"] as? String) ?? ""
            pendingIconPickerRequest = PendingIconPickerRequest(
                calloutId: calloutId,
                currentIcon: currentIcon,
            )
        case "debugLog":
            #if DEBUG
            let label = (payload["label"] as? String) ?? "Debug"
            let value = payload["payload"] ?? payload
            print("[Tiptap][\(label)] \(value)")
            #endif
        case "focus", "blur":
            break
        default:
            break
        }
    }

    // MARK: - Private

    private func run(_ command: String, args: [String: Any] = [:]) {
        guard let webView else { return }
        let jsonData = (try? JSONSerialization.data(withJSONObject: args))
            ?? Data("{}".utf8)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let js = "window.tiptapCommand(\(quote(command)), \(jsonString));"
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                #if DEBUG
                print("[Tiptap] command \(command) failed:", error)
                #endif
            }
        }
    }

    private func registerCalloutIcons(from markdown: String) {
        let pattern = #":::lurelia-callout[^\n]*\sicon="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            registerIconAsset("starcal")
            return
        }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        let matches = regex.matches(in: markdown, range: range)
        registerIconAsset("starcal")
        for match in matches {
            guard let iconRange = Range(match.range(at: 1), in: markdown) else { continue }
            registerIconAsset(String(markdown[iconRange]))
        }
    }

    private func registerIconAsset(_ icon: String) {
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIcon.isEmpty else { return }
        guard let dataURL = TiptapEditorIconRenderer.dataURL(for: cleanIcon) else { return }
        run("registerIconAsset", args: ["icon": cleanIcon, "src": dataURL])
    }

    private func quote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

enum TiptapEditorIconRenderer {
    static func dataURL(for icon: String) -> String? {
        guard let pngData = pngData(for: icon, tint: .white, side: 96) else { return nil }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    static func pngData(
        for icon: String,
        tint: UIColor = .white,
        side: CGFloat = 96,
    ) -> Data? {
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanIcon.isEmpty else { return nil }

        guard let image = UIImage(named: cleanIcon)?.withRenderingMode(.alwaysOriginal) else {
            return nil
        }

        let outputSide = min(max(side, 8), 160)
        let maskImage = croppedAlphaMask(from: image) ?? image

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format,
        )
        let rendered = renderer.image { _ in
            let maskSize = maskImage.size
            let scale = min(
                outputSide / max(maskSize.width, 1),
                outputSide / max(maskSize.height, 1),
            )
            let size = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
            let rect = CGRect(
                x: (outputSide - size.width) / 2,
                y: (outputSide - size.height) / 2,
                width: size.width,
                height: size.height,
            )

            tint.setFill()
            UIRectFill(rect)
            maskImage.draw(in: rect, blendMode: .destinationIn, alpha: 1)
        }

        return (removingHairlineArtifacts(from: rendered) ?? rendered).pngData()
    }

    private static func croppedAlphaMask(from image: UIImage) -> UIImage? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let renderScale = max(image.scale, UIScreen.main.scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false

        let rendered = UIGraphicsImageRenderer(size: sourceSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: sourceSize))
        }

        guard let cgImage = rendered.cgImage,
              let cropRect = alphaBounds(in: cgImage),
              let cropped = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: renderScale, orientation: .up)
    }

    private static func alphaBounds(in cgImage: CGImage) -> CGRect? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * bytesPerRow) + (x * bytesPerPixel) + 3]
                guard alpha > 4 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1,
        )
    }

    private static func removingHairlineArtifacts(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let alphaThreshold: UInt8 = 10
        let maxThickness = max(3, min(width, height) / 40)
        let minLength = max(8, min(width, height) / 18)
        var removeMask = [Bool](repeating: false, count: width * height)

        func pixelIndex(x: Int, y: Int) -> Int {
            y * width + x
        }

        func alpha(x: Int, y: Int) -> UInt8 {
            pixels[(pixelIndex(x: x, y: y) * bytesPerPixel) + 3]
        }

        func verticalThickness(atX x: Int, y: Int) -> Int {
            var thickness = 1
            var up = y - 1
            while up >= 0, alpha(x: x, y: up) > alphaThreshold {
                thickness += 1
                up -= 1
            }

            var down = y + 1
            while down < height, alpha(x: x, y: down) > alphaThreshold {
                thickness += 1
                down += 1
            }

            return thickness
        }

        func horizontalThickness(atX x: Int, y: Int) -> Int {
            var thickness = 1
            var left = x - 1
            while left >= 0, alpha(x: left, y: y) > alphaThreshold {
                thickness += 1
                left -= 1
            }

            var right = x + 1
            while right < width, alpha(x: right, y: y) > alphaThreshold {
                thickness += 1
                right += 1
            }

            return thickness
        }

        func markVerticalBand(x: Int, y: Int) {
            var up = y
            var steps = 0
            while up >= 0, alpha(x: x, y: up) > alphaThreshold, steps < maxThickness {
                removeMask[pixelIndex(x: x, y: up)] = true
                up -= 1
                steps += 1
            }

            var down = y + 1
            steps = 0
            while down < height, alpha(x: x, y: down) > alphaThreshold, steps < maxThickness {
                removeMask[pixelIndex(x: x, y: down)] = true
                down += 1
                steps += 1
            }
        }

        func markHorizontalBand(x: Int, y: Int) {
            var left = x
            var steps = 0
            while left >= 0, alpha(x: left, y: y) > alphaThreshold, steps < maxThickness {
                removeMask[pixelIndex(x: left, y: y)] = true
                left -= 1
                steps += 1
            }

            var right = x + 1
            steps = 0
            while right < width, alpha(x: right, y: y) > alphaThreshold, steps < maxThickness {
                removeMask[pixelIndex(x: right, y: y)] = true
                right += 1
                steps += 1
            }
        }

        for y in 0..<height {
            var x = 0
            while x < width {
                while x < width, alpha(x: x, y: y) <= alphaThreshold { x += 1 }
                let startX = x
                while x < width, alpha(x: x, y: y) > alphaThreshold { x += 1 }
                let endX = x - 1
                guard endX >= startX else { continue }

                let runLength = endX - startX + 1
                let thinXs = (startX...endX).filter { verticalThickness(atX: $0, y: y) <= maxThickness }
                guard runLength >= minLength, thinXs.count >= minLength else { continue }

                for thinX in thinXs {
                    markVerticalBand(x: thinX, y: y)
                }
            }
        }

        for x in 0..<width {
            var y = 0
            while y < height {
                while y < height, alpha(x: x, y: y) <= alphaThreshold { y += 1 }
                let startY = y
                while y < height, alpha(x: x, y: y) > alphaThreshold { y += 1 }
                let endY = y - 1
                guard endY >= startY else { continue }

                let runLength = endY - startY + 1
                let thinYs = (startY...endY).filter { horizontalThickness(atX: x, y: $0) <= maxThickness }
                guard runLength >= minLength, thinYs.count >= minLength else { continue }

                for thinY in thinYs {
                    markHorizontalBand(x: x, y: thinY)
                }
            }
        }

        for index in removeMask.indices where removeMask[index] {
            let offset = index * bytesPerPixel
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 0
        }

        guard let cleaned = context.makeImage() else { return nil }
        return UIImage(cgImage: cleaned, scale: image.scale, orientation: .up)
    }

}

// MARK: - Toolbar state

struct TiptapToolbarState: Equatable {
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var isStrike = false
    var isCode = false
    var isBlockquote = false
    var isCodeBlock = false
    var isBulletList = false
    var isOrderedList = false
    var isLink = false
    var isH1 = false
    var isH2 = false
    var isH3 = false
    var canUndo = false
    var canRedo = false

    init() {}

    init(dict: [String: Any]) {
        isBold = dict["isBold"] as? Bool ?? false
        isItalic = dict["isItalic"] as? Bool ?? false
        isUnderline = dict["isUnderline"] as? Bool ?? false
        isStrike = dict["isStrike"] as? Bool ?? false
        isCode = dict["isCode"] as? Bool ?? false
        isBlockquote = dict["isBlockquote"] as? Bool ?? false
        isCodeBlock = dict["isCodeBlock"] as? Bool ?? false
        isBulletList = dict["isBulletList"] as? Bool ?? false
        isOrderedList = dict["isOrderedList"] as? Bool ?? false
        isLink = dict["isLink"] as? Bool ?? false
        isH1 = dict["isH1"] as? Bool ?? false
        isH2 = dict["isH2"] as? Bool ?? false
        isH3 = dict["isH3"] as? Bool ?? false
        canUndo = dict["canUndo"] as? Bool ?? false
        canRedo = dict["canRedo"] as? Bool ?? false
    }
}

// MARK: - Request payloads

struct PendingLinkRequest: Equatable {
    let currentHref: String
}

struct PendingIconPickerRequest: Equatable {
    /// The JS-side node ID of the callout whose icon should be updated.
    /// Empty string means "we are inserting a fresh callout".
    let calloutId: String
    /// Icon name currently on the callout, for the picker's initial value.
    let currentIcon: String
}
