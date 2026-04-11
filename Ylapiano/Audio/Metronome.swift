import Foundation
import AVFoundation
import Combine

@Observable
final class Metronome {
    var bpm: Int {
        didSet {
            if isPlaying {
                stop()
                start()
            }
        }
    }
    var isPlaying = false
    var currentBeat = 0

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    init(bpm: Int = 100) {
        self.bpm = bpm
        prepareAudio()
    }

    private func prepareAudio() {
        // Configure audio session for playback + recording simultaneously
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        currentBeat = 0

        let interval = 60.0 / Double(bpm)
        tick() // Play first tick immediately

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
    }

    func toggle() {
        if isPlaying { stop() } else { start() }
    }

    private func tick() {
        currentBeat += 1
        playTickSound()
    }

    private func playTickSound() {
        // Generate a short click sound using AudioServices
        AudioServicesPlaySystemSound(1104) // Tock sound
    }
}
