// IMPORTANT: This struct MUST stay identical to DecibelPro/Models/DecibelLiveActivity.swift
// Both targets need their own copy because they are separate build targets.
// If you change one, change the other.
import Foundation
import ActivityKit

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
