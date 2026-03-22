import Foundation

nonisolated struct DecibelReading: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let zone: String

    init(value: Double, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.zone = NoiseZone.zone(for: value).rawValue
    }
}
