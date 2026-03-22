import SwiftUI
import SwiftData
import ActivityKit
import WidgetKit

@Observable
@MainActor
final class MeterViewModel {
    var currentDecibels: Double = 0
    var leq: Double = 0
    var minDecibels: Double = Double.infinity
    var maxDecibels: Double = -Double.infinity
    var peakHold: Double = 0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var recentSamples: [Double] = []
    var thresholdExceeded: Bool = false
    var thresholdTrigger: Int = 0
    var errorMessage: String?
    var sessionStartDate: Date?

    var twaNiosh: Double = 0
    var twaOsha: Double = 0
    var dosePercentNiosh: Double = 0
    var dosePercentOsha: Double = 0
    var recommendedMaxTime: String = "—"

    private let audioService: AudioMeterService
    private var currentSession: MeasurementSession?
    private var modelContext: ModelContext?
    private var displayLink: CADisplayLink?
    private var liveActivity: Activity<DecibelActivityAttributes>?
    private var liveActivityUpdateCounter: Int = 0
    private let appGroupID = "group.app.rork.caj9ckfvqm986l4n74fe5"
    private var sampleAccumulator: Int = 0
    private var twaEnergySum: Double = 0
    private var twaSampleCount: Int = 0
    private var accumulatedActiveTime: TimeInterval = 0
    private var lastResumeDate: Date?
    var activeElapsed: TimeInterval { accumulatedActiveTime + (isPaused ? 0 : (lastResumeDate.map { Date().timeIntervalSince($0) } ?? 0)) }

    var activeCalibrationPresetName: String {
        let presetId = UserDefaults.standard.string(forKey: "activeCalibrationPreset") ?? "iphone_standard"
        switch presetId {
        case "chantier_btp": return "Chantier BTP"
        case "concert_event": return "Concert / Event"
        case "nuisance_voisinage": return "Nuisance Voisinage"
        case "custom": return "Personnalisé"
        default: return "iPhone Standard"
        }
    }

    var alertThreshold: Double {
        get { UserDefaults.standard.double(forKey: "alertThreshold").isZero ? 85 : UserDefaults.standard.double(forKey: "alertThreshold") }
        set { UserDefaults.standard.set(newValue, forKey: "alertThreshold") }
    }

    var alertEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "alertEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "alertEnabled") }
    }

    var currentZone: NoiseZone {
        NoiseZone.zone(for: currentDecibels)
    }

    init(audioService: AudioMeterService) {
        self.audioService = audioService
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func toggleRecording() {
        if isRunning {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func togglePause() {
        if isPaused {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }

    func startRecording() {
        guard audioService.hasPermission else { return }

        resetStats()
        audioService.start()

        if case .error(let msg) = audioService.state {
            errorMessage = msg
            return
        }

        isRunning = true
        isPaused = false
        errorMessage = nil
        sessionStartDate = Date()
        accumulatedActiveTime = 0
        lastResumeDate = Date()

        let session = MeasurementSession(calibrationPreset: activeCalibrationPresetName)
        currentSession = session
        modelContext?.insert(session)

        startLiveActivity()
        startDisplayLink()
    }

    func stopRecording() {
        stopDisplayLink()
        audioService.stop()
        isRunning = false
        isPaused = false

        currentSession?.flushSamples()
        currentSession?.finish()
        try? modelContext?.save()
        updateWidgetData()
        stopLiveActivity()
        currentSession = nil
    }

    func pauseRecording() {
        guard isRunning, !isPaused else { return }
        if let resume = lastResumeDate {
            accumulatedActiveTime += Date().timeIntervalSince(resume)
        }
        lastResumeDate = nil
        audioService.pause()
        isPaused = true
    }

    func resumeRecording() {
        guard isRunning, isPaused else { return }
        lastResumeDate = Date()
        audioService.resume()
        isPaused = false
    }

    func resetPeak() {
        peakHold = 0
        audioService.resetPeak()
    }

    func enterBackground() {
        stopDisplayLink()
    }

    func enterForeground() {
        guard isRunning else { return }
        startDisplayLink()
    }

    func applyCalibration(offset: Double) {
        audioService.calibration = offset
    }

    // MARK: - Display Link (60fps)

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: DisplayLinkProxy(handler: { [weak self] in
            self?.updateFromAudio()
        }), selector: #selector(DisplayLinkProxy.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateFromAudio() {
        guard !isPaused else { return }

        let db = audioService.currentDecibels
        guard db != currentDecibels || db == 0 else { return }

        currentDecibels = db
        leq = audioService.leq
        peakHold = audioService.peakHold

        if audioService.lMax > -Double.infinity { maxDecibels = audioService.lMax }
        if audioService.lMin < Double.infinity && audioService.lMin > 0 { minDecibels = audioService.lMin }

        recentSamples.append(db)
        if recentSamples.count > 200 {
            recentSamples.removeFirst()
        }

        sampleAccumulator += 1
        if sampleAccumulator % 4 == 0 {
            currentSession?.addSample(db)
        }

        if sampleAccumulator % 240 == 0 {
            currentSession?.flushSamples()
            try? modelContext?.save()
        }

        twaSampleCount += 1
        twaEnergySum += pow(10.0, db / 10.0)
        updateTWA()

        if alertEnabled && db > alertThreshold {
            if !thresholdExceeded {
                thresholdExceeded = true
                thresholdTrigger += 1
            }
        } else {
            thresholdExceeded = false
        }

        liveActivityUpdateCounter += 1
        if liveActivityUpdateCounter % 60 == 0 {
            updateLiveActivityContent()
        }
    }

    private func resetStats() {
        currentDecibels = 0
        leq = 0
        minDecibels = Double.infinity
        maxDecibels = -Double.infinity
        peakHold = 0
        recentSamples = []
        thresholdExceeded = false
        errorMessage = nil
        audioService.resetStats()
        liveActivityUpdateCounter = 0
        sampleAccumulator = 0
        twaEnergySum = 0
        twaSampleCount = 0
        accumulatedActiveTime = 0
        lastResumeDate = nil
        twaNiosh = 0
        twaOsha = 0
        dosePercentNiosh = 0
        dosePercentOsha = 0
        recommendedMaxTime = "—"
    }

    // MARK: - TWA Dose

    private func updateTWA() {
        guard twaSampleCount > 0, let start = sessionStartDate else { return }
        let avgEnergy = twaEnergySum / Double(twaSampleCount)
        let avgDb = 10.0 * log10(avgEnergy)
        let elapsed = activeElapsed
        guard elapsed > 1 else { return }

        let nioshLimit: Double = 85
        let nioshER: Double = 3
        let oshaLimit: Double = 90
        let oshaER: Double = 5

        let nioshAllowed = 8.0 * pow(2.0, (nioshLimit - avgDb) / nioshER)
        let oshaAllowed = 8.0 * pow(2.0, (oshaLimit - avgDb) / oshaER)

        let elapsedHours = elapsed / 3600.0

        twaNiosh = max(0, avgDb)
        twaOsha = max(0, avgDb)
        dosePercentNiosh = min(999, nioshAllowed > 0 ? (elapsedHours / nioshAllowed) * 100.0 : 0)
        dosePercentOsha = min(999, oshaAllowed > 0 ? (elapsedHours / oshaAllowed) * 100.0 : 0)

        let remainingNiosh = max(0, nioshAllowed - elapsedHours)
        let h = Int(remainingNiosh)
        let m = Int((remainingNiosh - Double(h)) * 60)
        if remainingNiosh > 24 {
            recommendedMaxTime = "> 24h"
        } else if h > 0 {
            recommendedMaxTime = "\(h)h\(String(format: "%02d", m))"
        } else if m > 0 {
            recommendedMaxTime = "\(m) min"
        } else {
            recommendedMaxTime = "Dépassé"
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DecibelActivityAttributes(sessionStartDate: Date())
        let zone = NoiseZone.zone(for: currentDecibels)
        let state = DecibelActivityAttributes.ContentState(
            currentDB: currentDecibels,
            zoneName: zone.label,
            zoneColorR: zoneColorComponents(zone).r,
            zoneColorG: zoneColorComponents(zone).g,
            zoneColorB: zoneColorComponents(zone).b,
            isRecording: true
        )

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {}
    }

    private func updateLiveActivityContent() {
        guard let liveActivity else { return }

        let zone = NoiseZone.zone(for: currentDecibels)
        let state = DecibelActivityAttributes.ContentState(
            currentDB: currentDecibels,
            zoneName: zone.label,
            zoneColorR: zoneColorComponents(zone).r,
            zoneColorG: zoneColorComponents(zone).g,
            zoneColorB: zoneColorComponents(zone).b,
            isRecording: true
        )

        Task {
            await liveActivity.update(.init(state: state, staleDate: nil))
        }
    }

    private func stopLiveActivity() {
        guard let liveActivity else { return }

        let zone = NoiseZone.zone(for: leq)
        let finalState = DecibelActivityAttributes.ContentState(
            currentDB: leq,
            zoneName: zone.label,
            zoneColorR: zoneColorComponents(zone).r,
            zoneColorG: zoneColorComponents(zone).g,
            zoneColorB: zoneColorComponents(zone).b,
            isRecording: false
        )

        Task {
            await liveActivity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .default)
        }
        self.liveActivity = nil
    }

    private func zoneColorComponents(_ zone: NoiseZone) -> (r: Double, g: Double, b: Double) {
        switch zone {
        case .silence: (0, 0.8, 0.4)
        case .quiet: (0, 1, 0.53)
        case .moderate: (0.6, 0.9, 0)
        case .loud: (1, 0.8, 0)
        case .veryLoud: (1, 0.4, 0)
        case .dangerous: (1, 0.15, 0.15)
        }
    }

    // MARK: - Widget Data

    private func updateWidgetData() {
        guard let shared = UserDefaults(suiteName: appGroupID) else { return }
        shared.set(leq, forKey: "widget_lastLeq")
        shared.set(Date(), forKey: "widget_lastDate")

        if let modelContext {
            let descriptor = FetchDescriptor<MeasurementSession>(
                sortBy: [SortDescriptor(\MeasurementSession.startDate, order: .reverse)]
            )
            if let sessions = try? modelContext.fetch(descriptor) {
                let recent = sessions.prefix(3).map { session in
                    WidgetSessionDTO(
                        id: session.id.uuidString,
                        date: session.startDate,
                        avgDB: session.avgDecibels,
                        duration: session.duration
                    )
                }
                if let data = try? JSONEncoder().encode(recent) {
                    shared.set(data, forKey: "widget_recentSessions")
                }
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

nonisolated struct WidgetSessionDTO: Codable, Sendable {
    let id: String
    let date: Date
    let avgDB: Double
    let duration: TimeInterval
}

nonisolated final class DisplayLinkProxy: @unchecked Sendable {
    let handler: @MainActor () -> Void

    init(handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @objc func tick() {
        Task { @MainActor in
            handler()
        }
    }
}
