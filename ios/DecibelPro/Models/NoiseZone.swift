import SwiftUI

nonisolated enum NoiseZone: String, CaseIterable, Sendable {
    case silence
    case quiet
    case moderate
    case loud
    case veryLoud
    case dangerous

    var label: String {
        switch self {
        case .silence: "Silence"
        case .quiet: "Calme"
        case .moderate: "Modéré"
        case .loud: "Bruyant"
        case .veryLoud: "Très bruyant"
        case .dangerous: "Dangereux"
        }
    }

    var icon: String {
        switch self {
        case .silence: "moon.fill"
        case .quiet: "leaf.fill"
        case .moderate: "speaker.wave.1.fill"
        case .loud: "speaker.wave.2.fill"
        case .veryLoud: "speaker.wave.3.fill"
        case .dangerous: "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .silence: "Environnement très calme"
        case .quiet: "Bureau, bibliothèque"
        case .moderate: "Conversation normale"
        case .loud: "Rue animée, restaurant"
        case .veryLoud: "Chantier, concert"
        case .dangerous: "Risque pour l'audition !"
        }
    }

    var color: Color {
        switch self {
        case .silence: Color(red: 0, green: 0.8, blue: 0.4)
        case .quiet: Color(red: 0, green: 1, blue: 0.53)
        case .moderate: Color(red: 0.6, green: 0.9, blue: 0)
        case .loud: Color(red: 1, green: 0.8, blue: 0)
        case .veryLoud: Color(red: 1, green: 0.4, blue: 0)
        case .dangerous: Color(red: 1, green: 0.15, blue: 0.15)
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .silence: 0...30
        case .quiet: 30...50
        case .moderate: 50...65
        case .loud: 65...80
        case .veryLoud: 80...100
        case .dangerous: 100...130
        }
    }

    static func zone(for decibels: Double) -> NoiseZone {
        switch decibels {
        case ..<30: .silence
        case 30..<50: .quiet
        case 50..<65: .moderate
        case 65..<80: .loud
        case 80..<100: .veryLoud
        default: .dangerous
        }
    }
}
