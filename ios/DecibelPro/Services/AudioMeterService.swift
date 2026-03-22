import AVFoundation
import Accelerate

nonisolated enum MeterState: Sendable {
    case idle
    case recording
    case paused
    case error(String)
}

@Observable
@MainActor
final class AudioMeterService {
    var currentDecibels: Double = 0
    var leq: Double = 0
    var lMax: Double = -Double.infinity
    var lMin: Double = Double.infinity
    var peakHold: Double = 0
    var state: MeterState = .idle
    var hasPermission: Bool = false
    var permissionDenied: Bool = false

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    private var audioEngine: AVAudioEngine?
    private var calibrationOffset: Double = 0
    private var energySum: Double = 0
    private var sampleCount: Int = 0
    private var interruptionObserver: Any?

    var calibration: Double {
        get { calibrationOffset }
        set { calibrationOffset = newValue }
    }

    func requestPermission() async {
        if await AVAudioApplication.requestRecordPermission() {
            hasPermission = true
            permissionDenied = false
        } else {
            hasPermission = false
            permissionDenied = true
        }
    }

    func start() {
        guard hasPermission else {
            state = .error("Microphone non autorisé")
            return
        }

        stop()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setPreferredSampleRate(44100)
            try session.setActive(true)
        } catch {
            state = .error("Impossible de configurer la session audio")
            return
        }

        observeInterruptions()

        let engine = AVAudioEngine()
        let inputNode: AVAudioInputNode
        do {
            inputNode = engine.inputNode
        } catch {
            state = .error("Microphone utilisé par une autre app")
            return
        }
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            state = .error("Microphone indisponible")
            return
        }

        let bufferSize: AVAudioFrameCount = 2048
        let sampleRate = format.sampleRate

        resetStats()

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            let currentOffset = self?.calibrationOffset ?? 0
            let db = AudioMeterService.processBuffer(buffer, sampleRate: sampleRate, calibrationOffset: currentOffset)
            Task { @MainActor [weak self] in
                self?.handleDecibelReading(db)
            }
        }

        do {
            try engine.start()
            self.audioEngine = engine
            state = .recording
        } catch {
            state = .error("Impossible de démarrer le moteur audio")
        }
    }

    func pause() {
        guard case .recording = state else { return }
        audioEngine?.pause()
        state = .paused
    }

    func resume() {
        guard case .paused = state else { return }
        do {
            try audioEngine?.start()
            state = .recording
        } catch {
            state = .error("Impossible de reprendre l'enregistrement")
        }
    }

    func stop() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        if case .idle = state { return }
        state = .idle

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
    }

    func resetPeak() {
        peakHold = 0
    }

    func resetStats() {
        currentDecibels = 0
        leq = 0
        lMax = -Double.infinity
        lMin = Double.infinity
        peakHold = 0
        energySum = 0
        sampleCount = 0
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            if case .recording = state {
                audioEngine?.pause()
                state = .paused
            }
        case .ended:
            if case .paused = state {
                let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                    .flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
                if options?.contains(.shouldResume) == true {
                    do {
                        try audioEngine?.start()
                        state = .recording
                    } catch {
                        state = .error("Impossible de reprendre après interruption")
                    }
                }
            }
        @unknown default:
            break
        }
    }

    private func handleDecibelReading(_ rawDb: Double) {
        guard case .recording = state else { return }
        let db = max(0, min(130, rawDb))
        currentDecibels = db

        let energy = pow(10.0, db / 10.0)
        energySum += energy
        sampleCount += 1
        leq = 10.0 * log10(energySum / Double(sampleCount))

        if db > lMax { lMax = db }
        if db < lMin && db > 0 { lMin = db }
        if db > peakHold { peakHold = db }
    }

    private nonisolated static func processBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double, calibrationOffset: Double) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)

        var rms: Float = 0
        vDSP_rmsqv(samples.baseAddress!, 1, &rms, vDSP_Length(frameLength))

        guard rms > 1e-10 else { return 0 }

        let dbSPL = 20.0 * log10(Double(rms)) + 94.0

        let aWeightedDb = applyAWeighting(dbSPL: dbSPL, sampleRate: sampleRate, samples: samples)

        return max(0, aWeightedDb + calibrationOffset)
    }

    private nonisolated static func applyAWeighting(dbSPL: Double, sampleRate: Double, samples: UnsafeBufferPointer<Float>) -> Double {
        let n = samples.count
        guard n > 0 else { return dbSPL }

        let log2n = vDSP_Length(log2(Double(n)))
        let fftLength = 1 << Int(log2n)
        guard fftLength > 0, fftLength <= n else { return dbSPL }

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return dbSPL
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realPart = [Float](repeating: 0, count: fftLength)
        var imagPart = [Float](repeating: 0, count: fftLength)
        for i in 0..<fftLength {
            realPart[i] = samples[i]
        }

        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var sc = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zip(fftSetup, &sc, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        let freqResolution = sampleRate / Double(fftLength)
        var weightedEnergy: Double = 0
        let halfN = fftLength / 2

        for k in 1..<halfN {
            let freq = Double(k) * freqResolution
            let magnitude = sqrt(Double(realPart[k] * realPart[k] + imagPart[k] * imagPart[k]))
            let aWeight = aWeightingCurve(freq: freq)
            let weightedMag = magnitude * pow(10.0, aWeight / 20.0)
            weightedEnergy += weightedMag * weightedMag
        }

        let totalEnergy = weightedEnergy / Double(halfN)
        guard totalEnergy > 1e-20 else { return 0 }

        let weightedRms = sqrt(totalEnergy)
        let weightedDb = 20.0 * log10(weightedRms) + 94.0

        return max(0, weightedDb)
    }

    private nonisolated static func aWeightingCurve(freq: Double) -> Double {
        let f2 = freq * freq
        let numerator = 12194.0 * 12194.0 * f2 * f2
        let denominator = (f2 + 20.6 * 20.6)
            * sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9))
            * (f2 + 12194.0 * 12194.0)

        guard denominator > 0 else { return -100 }

        let ra = numerator / denominator
        let aWeight = 20.0 * log10(ra) + 2.0
        return aWeight
    }
}
