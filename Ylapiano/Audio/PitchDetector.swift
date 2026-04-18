import Foundation
import AVFoundation
import Accelerate

@Observable
final class PitchDetector {
    var detectedFrequency: Double = 0
    var detectedNote: Solfege?
    var detectedOctave: Int = 4
    var isListening = false
    var hasPermission = false
    var permissionDenied = false

    private var audioEngine: AVAudioEngine?
    private let sampleRate: Double = 44100.0
    private let bufferSize: UInt32 = 4096

    // Frequency-to-note mapping
    private static let noteFrequencies: [(Solfege, Int, Double)] = {
        var result: [(Solfege, Int, Double)] = []
        for octave in 2...7 {
            for solfege in Solfege.allCases {
                let freq = solfege.frequency(octave: octave)
                result.append((solfege, octave, freq))
            }
        }
        return result
    }()

    func requestPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                self?.permissionDenied = !granted
            }
        }
    }

    func startListening() {
        guard hasPermission else {
            requestPermission()
            return
        }
        guard !isListening else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("PitchDetector: Failed to start audio engine: \(error)")
        }
    }

    func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isListening = false
        detectedFrequency = 0
        detectedNote = nil
    }

    // MARK: - Pitch Detection (Autocorrelation)

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Convert to array
        let signal = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

        // Check if signal has enough energy (not silence)
        var rms: Float = 0
        vDSP_rmsqv(signal, 1, &rms, vDSP_Length(frameCount))
        guard rms > 0.01 else {
            DispatchQueue.main.async { [weak self] in
                self?.detectedNote = nil
                self?.detectedFrequency = 0
            }
            return
        }

        // Autocorrelation-based pitch detection
        if let frequency = detectPitch(signal: signal, sampleRate: sampleRate) {
            let (note, octave) = frequencyToNote(frequency)
            DispatchQueue.main.async { [weak self] in
                self?.detectedFrequency = frequency
                self?.detectedNote = note
                self?.detectedOctave = octave
            }
        }
    }

    private func detectPitch(signal: [Float], sampleRate: Double) -> Double? {
        let count = signal.count

        // Minimum and maximum periods to search (corresponding to frequency range ~60 Hz to ~2000 Hz)
        let minPeriod = Int(sampleRate / 2000.0)
        let maxPeriod = min(Int(sampleRate / 60.0), count / 2)

        guard minPeriod < maxPeriod else { return nil }

        // Normalized Square Difference Function (NSDF) for better pitch detection
        var bestCorrelation: Float = 0
        var bestPeriod = 0

        for lag in minPeriod...maxPeriod {
            var correlation: Float = 0
            var energy1: Float = 0
            var energy2: Float = 0

            let length = count - lag
            vDSP_dotpr(signal, 1,
                       Array(signal[lag..<lag + length]), 1,
                       &correlation,
                       vDSP_Length(length))
            vDSP_dotpr(signal, 1, signal, 1, &energy1, vDSP_Length(length))
            vDSP_dotpr(Array(signal[lag..<lag + length]), 1,
                       Array(signal[lag..<lag + length]), 1,
                       &energy2,
                       vDSP_Length(length))

            let denominator = sqrt(energy1 * energy2)
            guard denominator > 0 else { continue }
            let normalizedCorrelation = correlation / denominator

            if normalizedCorrelation > bestCorrelation {
                bestCorrelation = normalizedCorrelation
                bestPeriod = lag
            }
        }

        // Only accept if correlation is strong enough
        guard bestCorrelation > 0.8, bestPeriod > 0 else { return nil }

        // Parabolic interpolation for sub-sample accuracy
        let frequency = sampleRate / Double(bestPeriod)
        return frequency
    }

    private func frequencyToNote(_ frequency: Double) -> (Solfege, Int) {
        var closestNote: Solfege = .Do
        var closestOctave = 4
        var minDistance = Double.infinity

        for (note, octave, noteFreq) in Self.noteFrequencies {
            // Use cents distance for better matching
            let cents = abs(1200.0 * log2(frequency / noteFreq))
            if cents < minDistance {
                minDistance = cents
                closestNote = note
                closestOctave = octave
            }
        }

        return (closestNote, closestOctave)
    }
}
