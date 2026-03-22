import WidgetKit
import SwiftUI
import ActivityKit

private let appGroupID = "group.app.rork.caj9ckfvqm986l4n74fe5"

nonisolated struct DecibelEntry: TimelineEntry {
    let date: Date
    let lastLeq: Double
    let lastDate: Date?
    let recentSessions: [WidgetSession]
}

nonisolated struct WidgetSession: Identifiable, Sendable {
    let id: String
    let date: Date
    let avgDB: Double
    let duration: TimeInterval
}

nonisolated struct DecibelProvider: TimelineProvider {
    func placeholder(in context: Context) -> DecibelEntry {
        DecibelEntry(date: .now, lastLeq: 42, lastDate: .now, recentSessions: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (DecibelEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DecibelEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> DecibelEntry {
        let shared = UserDefaults(suiteName: appGroupID)
        let leq = shared?.double(forKey: "widget_lastLeq") ?? 0
        let lastDate: Date? = shared?.object(forKey: "widget_lastDate") as? Date

        var sessions: [WidgetSession] = []
        if let data = shared?.data(forKey: "widget_recentSessions"),
           let decoded = try? JSONDecoder().decode([WidgetSessionData].self, from: data) {
            sessions = decoded.map { WidgetSession(id: $0.id, date: $0.date, avgDB: $0.avgDB, duration: $0.duration) }
        }

        return DecibelEntry(date: .now, lastLeq: leq, lastDate: lastDate, recentSessions: sessions)
    }
}

nonisolated struct WidgetSessionData: Codable, Sendable {
    let id: String
    let date: Date
    let avgDB: Double
    let duration: TimeInterval
}

private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

struct DecibelSmallView: View {
    var entry: DecibelEntry

    private var zoneColor: Color {
        colorForDB(entry.lastLeq)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentGreen)
                Text("DecibelPro")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.lastLeq > 0 {
                Text(String(format: "%.0f", entry.lastLeq))
                    .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(zoneColor)

                Text("dB Leq")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let date = entry.lastDate {
                    Text(date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Aucune mesure")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.06, blue: 0.08)
        }
    }
}

struct DecibelMediumView: View {
    var entry: DecibelEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentGreen)
                    Text("DecibelPro")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.lastLeq > 0 {
                    Text(String(format: "%.0f", entry.lastLeq))
                        .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(colorForDB(entry.lastLeq))
                    Text("dB Leq")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Récent")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if entry.recentSessions.isEmpty {
                    Text("Pas encore\nde sessions")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    ForEach(entry.recentSessions.prefix(3)) { session in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorForDB(session.avgDB))
                                .frame(width: 6, height: 6)
                            Text(String(format: "%.0f dB", session.avgDB))
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                            Spacer()
                            Text(session.date, style: .time)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.06, blue: 0.08)
        }
    }
}

struct DecibelProWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: DecibelEntry

    var body: some View {
        switch family {
        case .systemSmall:
            DecibelSmallView(entry: entry)
        case .systemMedium:
            DecibelMediumView(entry: entry)
        default:
            DecibelSmallView(entry: entry)
        }
    }
}

struct DecibelProWidget: Widget {
    let kind: String = "DecibelProWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DecibelProvider()) { entry in
            DecibelProWidgetView(entry: entry)
        }
        .configurationDisplayName("DecibelPro")
        .description("Dernier niveau Leq et sessions récentes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DecibelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DecibelActivityAttributes.self) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentGreen)
                        Text("DecibelPro")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(context.state.zoneName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: context.state.zoneColorR, green: context.state.zoneColorG, blue: context.state.zoneColorB))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", context.state.currentDB))
                        .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(red: context.state.zoneColorR, green: context.state.zoneColorG, blue: context.state.zoneColorB))
                    Text("dB(A)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                miniGauge(db: context.state.currentDB, color: Color(red: context.state.zoneColorR, green: context.state.zoneColorG, blue: context.state.zoneColorB))
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.06, green: 0.06, blue: 0.08))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentGreen)
                        Text(context.state.zoneName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color(red: context.state.zoneColorR, green: context.state.zoneColorG, blue: context.state.zoneColorB))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(String(format: "%.0f", context.state.currentDB))
                            .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(red: context.state.zoneColorR, green: context.state.zoneColorG, blue: context.state.zoneColorB))
                        Text("dB(A)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.sessionStartDate, style: .timer)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("En cours")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accentGreen)
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentGreen)
            } compactTrailing: {
                Text(String(format: "%.0f", context.state.currentDB))
                    .font(.system(size: 14, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Color(red: context.state.zoneColorR, green: context.state.zoneColorG, blue: context.state.zoneColorB))
            } minimal: {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentGreen)
            }
        }
    }

    private func miniGauge(db: Double, color: Color) -> some View {
        let normalized = min(max((db - 30) / 90.0, 0), 1)
        return ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color.opacity(0.15), lineWidth: 4)
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * normalized)
                .stroke(color, lineWidth: 4)
                .rotationEffect(.degrees(135))
        }
        .frame(width: 36, height: 36)
    }
}

private func colorForDB(_ db: Double) -> Color {
    switch db {
    case ..<30: Color(red: 0, green: 0.8, blue: 0.4)
    case 30..<50: Color(red: 0, green: 1, blue: 0.53)
    case 50..<65: Color(red: 0.6, green: 0.9, blue: 0)
    case 65..<80: Color(red: 1, green: 0.8, blue: 0)
    case 80..<100: Color(red: 1, green: 0.4, blue: 0)
    default: Color(red: 1, green: 0.15, blue: 0.15)
    }
}
