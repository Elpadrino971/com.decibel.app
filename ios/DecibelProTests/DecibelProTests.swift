import Testing
@testable import DecibelPro

struct DecibelProTests {

    // MARK: - NoiseZone Tests

    @Test func noiseZoneSilence() {
        let zone = NoiseZone.zone(for: 15)
        #expect(zone == .silence)
        #expect(zone.label == "Silence")
    }

    @Test func noiseZoneQuiet() {
        let zone = NoiseZone.zone(for: 40)
        #expect(zone == .quiet)
    }

    @Test func noiseZoneModerate() {
        let zone = NoiseZone.zone(for: 55)
        #expect(zone == .moderate)
    }

    @Test func noiseZoneLoud() {
        let zone = NoiseZone.zone(for: 75)
        #expect(zone == .loud)
    }

    @Test func noiseZoneVeryLoud() {
        let zone = NoiseZone.zone(for: 90)
        #expect(zone == .veryLoud)
    }

    @Test func noiseZoneDangerous() {
        let zone = NoiseZone.zone(for: 110)
        #expect(zone == .dangerous)
    }

    @Test func noiseZoneBoundary70() {
        let below = NoiseZone.zone(for: 49.9)
        let above = NoiseZone.zone(for: 50)
        #expect(below == .quiet)
        #expect(above == .moderate)
    }

    // MARK: - MeasurementSession Tests

    @Test func sessionAddSampleUpdatesStats() {
        let session = MeasurementSession(calibrationPreset: "iPhone Standard")
        session.addSample(60)
        session.addSample(80)
        session.addSample(40)

        #expect(session.sampleCount == 3)
        #expect(session.minDecibels == 40)
        #expect(session.maxDecibels == 80)
        #expect(session.peakHold == 80)
        #expect(session.avgDecibels > 0)
    }

    @Test func sessionSampleCap() {
        let session = MeasurementSession(calibrationPreset: "Test")
        for i in 0..<2000 {
            session.addSample(Double(i % 100))
        }
        #expect(session.samples.count <= 1800)
        #expect(session.sampleCount == 2000)
    }

    @Test func sessionFinishSetsEndDate() {
        let session = MeasurementSession(calibrationPreset: "Test")
        #expect(session.endDate == nil)
        session.finish()
        #expect(session.endDate != nil)
    }

    @Test func sessionFormattedDuration() {
        let session = MeasurementSession(calibrationPreset: "Test")
        session.finish()
        let formatted = session.formattedDuration
        #expect(formatted.contains(":"))
    }

    @Test func sessionLeqCalculation() {
        let session = MeasurementSession(calibrationPreset: "Test")
        session.addSample(70)
        session.addSample(70)
        session.addSample(70)
        #expect(abs(session.leq - 70) < 0.5)
    }

    // MARK: - DecibelReading Tests

    @Test func decibelReadingCreation() {
        let reading = DecibelReading(value: 65.5)
        #expect(reading.value == 65.5)
        #expect(reading.zone == NoiseZone.zone(for: 65.5).rawValue)
    }

    // MARK: - Edge Case Tests

    @Test func noiseZoneZeroDecibels() {
        let zone = NoiseZone.zone(for: 0)
        #expect(zone == .silence)
    }

    @Test func noiseZoneExtremeValue() {
        let zone = NoiseZone.zone(for: 200)
        #expect(zone == .dangerous)
    }

    @Test func sessionZeroSamples() {
        let session = MeasurementSession(calibrationPreset: "Test")
        #expect(session.sampleCount == 0)
        #expect(session.avgDecibels == 0)
        #expect(session.minDecibels == 999)
        #expect(session.maxDecibels == 0)
    }
}
