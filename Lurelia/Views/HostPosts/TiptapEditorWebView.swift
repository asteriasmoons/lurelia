//
//  TiptapEditorWebView.swift
//  Lurelia
//
//  UIViewRepresentable wrapper around a WKWebView that hosts the Tiptap
//  editor bundle.
//
//  Fixed height, no scroll bounce, no pull-to-refresh — the outer
//  HostPostEditorView layout stops the editor from being pulled around
//  by the parent scroll view.
//

import SwiftUI
import WebKit

private enum TiptapEditorAssetCache {
    static let cachedDocument: (html: String, baseURL: URL)? = {
        guard let htmlURL = Bundle.main.url(
            forResource: "tiptap",
            withExtension: "html",
            subdirectory: "TiptapEditor",
        ) ?? Bundle.main.url(forResource: "tiptap", withExtension: "html") else {
            return nil
        }

        let baseURL = htmlURL.deletingLastPathComponent()
        guard var html = try? String(contentsOf: htmlURL, encoding: .utf8) else {
            return nil
        }

        if let bundleURL = Bundle.main.url(
            forResource: "tiptap.bundle",
            withExtension: "js",
            subdirectory: "TiptapEditor",
        ) ?? Bundle.main.url(forResource: "tiptap.bundle", withExtension: "js"),
           let bundleJS = try? String(contentsOf: bundleURL, encoding: .utf8) {
            let safeJS = bundleJS.replacingOccurrences(of: "</script>", with: "<\\/script>")
            html = html.replacingOccurrences(
                of: #"<script src="./tiptap.bundle.js"></script>"#,
                with: "<script>\n\(safeJS)\n</script>",
            )
        }

        return (html, baseURL)
    }()
}

struct TiptapEditorWebView: UIViewRepresentable {
    let controller: TiptapEditorController
    var initialMarkdown: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, initialMarkdown: initialMarkdown)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "tiptap")
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.setURLSchemeHandler(TiptapIconSchemeHandler(), forURLScheme: "lurelia-icon")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // No bounce, no pull-to-refresh, no accidental drag-to-dismiss.
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.isDirectionalLockEnabled = true
        webView.scrollView.decelerationRate = .fast
        webView.navigationDelegate = context.coordinator

        controller.webView = webView

        loadEditor(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Editor is command-driven, not diff-driven.
    }

    private func loadEditor(into webView: WKWebView) {
        if let cachedDocument = TiptapEditorAssetCache.cachedDocument {
            webView.loadHTMLString(cachedDocument.html, baseURL: cachedDocument.baseURL)
            return
        }

        guard let htmlURL = Bundle.main.url(
            forResource: "tiptap",
            withExtension: "html",
            subdirectory: "TiptapEditor",
        ) ?? Bundle.main.url(forResource: "tiptap", withExtension: "html") else {
            #if DEBUG
            print("[Tiptap] tiptap.html not found in bundle")
            #endif
            return
        }
        let readAccess = htmlURL.deletingLastPathComponent()
        webView.loadFileURL(htmlURL, allowingReadAccessTo: readAccess)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let controller: TiptapEditorController
        let initialMarkdown: String

        init(controller: TiptapEditorController, initialMarkdown: String) {
            self.controller = controller
            self.initialMarkdown = initialMarkdown
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
        ) {
            guard message.name == "tiptap",
                  let body = message.body as? [String: Any],
                  let kind = body["kind"] as? String else { return }
            let payload = body["payload"] as? [String: Any] ?? [:]
            controller.handleMessage(kind: kind, payload: payload)

            if kind == "ready", !initialMarkdown.isEmpty {
                controller.setInitialMarkdown(initialMarkdown)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "http" || url.scheme == "https" {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}

private final class TiptapIconSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let iconName = iconName(from: url),
              let data = TiptapEditorIconRenderer.pngData(
                for: iconName,
                tint: tintColor(from: url),
                side: iconSide(from: url),
              ) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let response = URLResponse(
            url: url,
            mimeType: "image/png",
            expectedContentLength: data.count,
            textEncodingName: nil,
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func iconName(from url: URL) -> String? {
        let rawName: String
        if url.host == "asset" {
            rawName = url.pathComponents.dropFirst().joined(separator: "/")
        } else {
            rawName = url.host ?? ""
        }

        let cleanName = rawName
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return cleanName.isEmpty ? nil : cleanName
    }

    private func tintColor(from url: URL) -> UIColor {
        guard let rawColor = queryValue(named: "color", from: url) else {
            return .white
        }

        return UIColor(lureliaWebHex: rawColor) ?? .white
    }

    private func iconSide(from url: URL) -> CGFloat {
        guard let rawSize = queryValue(named: "size", from: url),
              let value = Double(rawSize) else {
            return 96
        }

        return CGFloat(min(max(value, 8), 160))
    }

    private func queryValue(named name: String, from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension UIColor {
    convenience init?(lureliaWebHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if cleaned.count == 8 {
            red = CGFloat((value >> 24) & 0xFF) / 255
            green = CGFloat((value >> 16) & 0xFF) / 255
            blue = CGFloat((value >> 8) & 0xFF) / 255
            alpha = CGFloat(value & 0xFF) / 255
        } else {
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
