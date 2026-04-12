import SwiftUI
import WebKit

struct ABCMusicView: UIViewRepresentable {
    let abcNotation: String
    let isPlaying: Bool
    let bpm: Int
    let playNotes: Bool
    let playMetronome: Bool
    var onNoteChange: ((Int) -> Void)?
    var onPlaybackEnd: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = config.userContentController
        userContent.add(context.coordinator, name: "noteChange")
        userContent.add(context.coordinator, name: "playbackEnd")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = true
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
        coordinator.pendingABC = abcNotation
        coordinator.pendingPlaying = isPlaying
        coordinator.pendingBPM = bpm
        coordinator.pendingPlayNotes = playNotes
        coordinator.pendingPlayMetronome = playMetronome
        coordinator.sendUpdate()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var isLoaded = false
        var pendingABC: String?
        var pendingPlaying = false
        var pendingBPM = 90
        var pendingPlayNotes = true
        var pendingPlayMetronome = false
        var onNoteChange: ((Int) -> Void)?
        var onPlaybackEnd: (() -> Void)?
        private var lastABC: String?
        private var lastPlaying = false
        private var lastMetronome = false
        private var lastBPM = 90

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
                let notesArg = pendingPlayNotes ? "true" : "false"
                let metroArg = pendingPlayMetronome ? "true" : "false"
                webView.evaluateJavaScript("startPlayback(\(pendingBPM), \(notesArg), \(metroArg))", completionHandler: nil)
                lastPlaying = true
                lastMetronome = pendingPlayMetronome
                lastBPM = pendingBPM
            } else if !pendingPlaying && lastPlaying {
                webView.evaluateJavaScript("stopPlayback()", completionHandler: nil)
                lastPlaying = false
            }

            // Live toggle metronome during playback
            if lastPlaying && pendingPlayMetronome != lastMetronome {
                let arg = pendingPlayMetronome ? "true" : "false"
                webView.evaluateJavaScript("setMetronomeEnabled(\(arg))", completionHandler: nil)
                lastMetronome = pendingPlayMetronome
            }

            // Live BPM change during playback — warp tempo on the fly
            if lastPlaying && pendingBPM != lastBPM {
                webView.evaluateJavaScript("setBPM(\(pendingBPM))", completionHandler: nil)
                lastBPM = pendingBPM
            }
        }
    }
}
