import ActivityKit
import SwiftUI

nonisolated struct DecibelActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var currentDB: Double
        var zoneName: String
        var zoneColorR: Double
        var zoneColorG: Double
        var zoneColorB: Double
        var isRecording: Bool
    }

    var sessionStartDate: Date
}
