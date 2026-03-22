import Foundation
import AVFoundation

nonisolated struct CalibrationPreset: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let offset: Double
    let description: String
    let referenceNorm: String
}

@Observable
@MainActor
final class CalibrationService {
    var presets: [CalibrationPreset] = []
    var activePresetId: String {
        get { UserDefaults.standard.string(forKey: "activeCalibrationPreset") ?? "iphone_standard" }
        set { UserDefaults.standard.set(newValue, forKey: "activeCalibrationPreset") }
    }
    var currentOffset: Double {
        get { UserDefaults.standard.double(forKey: "calibrationOffset") }
        set { UserDefaults.standard.set(newValue, forKey: "calibrationOffset") }
    }
    var isPlayingTestTone: Bool = false
    var toneError: String?

    private var toneEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?

    func loadPresets() {
        presets = Self.professionalPresets
    }

    func applyPreset(_ preset: CalibrationPreset) {
        activePresetId = preset.id
        currentOffset = preset.offset
    }

    func setCustomOffset(_ offset: Double) {
        activePresetId = "custom"
        currentOffset = offset
    }

    func reset() {
        activePresetId = "iphone_standard"
        currentOffset = 0
    }

    func toggleTestTone() {
        if isPlayingTestTone {
            stopTestTone()
        } else {
            startTestTone()
        }
    }

    private func startTestTone() {
        stopTestTone()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let mixer = engine.mainMixerNode

        engine.attach(player)

        let sampleRate: Double = 44100
        let frequency: Double = 1000.0
        let duration: Double = 5.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount

        let amplitude: Float = 0.5
        guard let channelData = buffer.floatChannelData else { return }

        for i in 0..<Int(frameCount) {
            let sample = amplitude * sin(Float(2.0 * Double.pi * frequency * Double(i) / sampleRate))
            channelData[0][i] = sample
        }

        engine.connect(player, to: mixer, format: format)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true)
            try engine.start()
            player.scheduleBuffer(buffer, at: nil)
            player.play()
            toneEngine = engine
            tonePlayer = player
            isPlayingTestTone = true

            Task {
                try? await Task.sleep(for: .seconds(duration))
                stopTestTone()
            }
        } catch {
            isPlayingTestTone = false
            toneEngine = nil
            tonePlayer = nil
            toneError = "Impossible de lancer le signal de test : \(error.localizedDescription)"
        }
    }

    func stopTestTone() {
        tonePlayer?.stop()
        toneEngine?.stop()
        toneEngine = nil
        tonePlayer = nil
        isPlayingTestTone = false
    }

    static let professionalPresets: [CalibrationPreset] = [
        CalibrationPreset(
            id: "iphone_standard",
            name: "iPhone Standard",
            icon: "iphone",
            offset: 0.0,
            description: "Mesure de référence sans correction",
            referenceNorm: "ISO 1996"
        ),
        CalibrationPreset(
            id: "chantier_btp",
            name: "Chantier BTP",
            icon: "hammer.fill",
            offset: 3.5,
            description: "Compense la réverbération en milieu industriel",
            referenceNorm: "NF S31-010"
        ),
        CalibrationPreset(
            id: "concert_event",
            name: "Concert / Event",
            icon: "music.mic",
            offset: 2.0,
            description: "Calibré pour haute pression acoustique",
            referenceNorm: "ISO 9612"
        ),
        CalibrationPreset(
            id: "nuisance_voisinage",
            name: "Nuisance Voisinage",
            icon: "house.fill",
            offset: 1.5,
            description: "Optimisé basses fréquences",
            referenceNorm: "OMS"
        ),
        CalibrationPreset(
            id: "custom",
            name: "Personnalisé",
            icon: "slider.horizontal.3",
            offset: 0.0,
            description: "Réglage manuel de l'offset",
            referenceNorm: "—"
        ),
    ]
}
