import SwiftUI
import WebKit

struct ABCMusicView: UIViewRepresentable {
    let abcNotation: String
    let highlightIndex: Int
    let isPlaying: Bool
    let bpm: Int
    var onNoteChange: ((Int) -> Void)?
    var onPlaybackEnd: (() -> Void)?
    var onBeat: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = config.userContentController
        userContent.add(context.coordinator, name: "noteChange")
        userContent.add(context.coordinator, name: "playbackEnd")
        userContent.add(context.coordinator, name: "beat")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "MusicNotation", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onNoteChange = onNoteChange
        coordinator.onPlaybackEnd = onPlaybackEnd
        coordinator.onBeat = onBeat
        coordinator.pendingABC = abcNotation
        coordinator.pendingHighlight = highlightIndex
        coordinator.pendingPlaying = isPlaying
        coordinator.pendingBPM = bpm
        coordinator.sendUpdate()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var isLoaded = false
        var pendingABC: String?
        var pendingHighlight: Int = -1
        var pendingPlaying = false
        var pendingBPM = 90
        var onNoteChange: ((Int) -> Void)?
        var onPlaybackEnd: (() -> Void)?
        var onBeat: (() -> Void)?
        private var lastABC: String?
        private var lastPlaying = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            sendUpdate()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "noteChange":
                if let body = message.body as? [String: Any], let index = body["index"] as? Int {
                    DispatchQueue.main.async { self.onNoteChange?(index) }
                }
            case "playbackEnd":
                DispatchQueue.main.async { self.onPlaybackEnd?() }
            case "beat":
                DispatchQueue.main.async { self.onBeat?() }
            default: break
            }
        }

        func sendUpdate() {
            guard isLoaded, let webView = webView else { return }

            if let abc = pendingABC, abc != lastABC {
                let escaped = abc.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                webView.evaluateJavaScript("renderMusic('\(escaped)')") { _, _ in
                    self.lastABC = abc
                    self.handlePlayState()
                }
            } else {
                handlePlayState()
            }
        }

        private func handlePlayState() {
            guard let webView = webView else { return }

            if pendingPlaying && !lastPlaying {
                webView.evaluateJavaScript("startPlayback(\(pendingBPM))", completionHandler: nil)
                lastPlaying = true
            } else if !pendingPlaying && lastPlaying {
                webView.evaluateJavaScript("stopPlayback()", completionHandler: nil)
                lastPlaying = false
            }

            if !pendingPlaying {
                webView.evaluateJavaScript("highlightNote(\(pendingHighlight))", completionHandler: nil)
            }
        }
    }
}
