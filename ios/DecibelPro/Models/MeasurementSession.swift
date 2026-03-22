import Foundation
import SwiftData

@Model
final class MeasurementSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var minDecibels: Double
    var maxDecibels: Double
    var avgDecibels: Double
    var peakHold: Double
    var leq: Double
    var sampleCount: Int
    var totalDecibels: Double
    var samples: [Double]
    var location: String?
    var note: String?
    var calibrationPreset: String

    private var energySum: Double
    @Transient private var pendingSamples: [Double] = []

    init(calibrationPreset: String = "iPhone Standard") {
        self.id = UUID()
        self.startDate = Date()
        self.endDate = nil
        self.minDecibels = 999
        self.maxDecibels = 0
        self.avgDecibels = 0
        self.peakHold = 0
        self.leq = 0
        self.sampleCount = 0
        self.totalDecibels = 0
        self.samples = []
        self.location = nil
        self.note = nil
        self.calibrationPreset = calibrationPreset
        self.energySum = 0
    }

    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%dh %02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func addSample(_ decibels: Double) {
        sampleCount += 1
        totalDecibels += decibels
        if decibels < minDecibels { minDecibels = decibels }
        if decibels > maxDecibels { maxDecibels = decibels }
        if decibels > peakHold { peakHold = decibels }

        let energy = pow(10.0, decibels / 10.0)
        energySum += energy
        leq = 10.0 * log10(energySum / Double(sampleCount))
        avgDecibels = leq

        pendingSamples.append(decibels)
    }

    func flushSamples() {
        guard !pendingSamples.isEmpty else { return }
        samples.append(contentsOf: pendingSamples)
        pendingSamples.removeAll()
        if samples.count > 1800 {
            samples.removeFirst(samples.count - 1800)
        }
    }

    func finish() {
        endDate = Date()
    }
}
