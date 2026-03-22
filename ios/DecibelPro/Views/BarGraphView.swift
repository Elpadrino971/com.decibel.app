import SwiftUI

struct BarGraphView: View {
    let level: Double
    let isActive: Bool

    private let segmentCount: Int = 30
    private let minDB: Double = 30
    private let maxDB: Double = 120

    private var filledSegments: Int {
        guard isActive else { return 0 }
        let normalized = min(max((level - minDB) / (maxDB - minDB), 0), 1)
        return Int(normalized * Double(segmentCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.53))
                Text("Niveau")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isActive ? String(format: "%.0f dB", level) : "— dB")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText())
            }

            HStack(spacing: 2) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segmentColor(for: index))
                        .opacity(index < filledSegments ? segmentOpacity(for: index) : 0.1)
                        .animation(
                            .spring(response: 0.15, dampingFraction: 0.8)
                                .delay(Double(index) * 0.008),
                            value: filledSegments
                        )
                }
            }
            .frame(height: 14)

            HStack {
                Text("30")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.25))
                Spacer()
                Text("70")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.25))
                Spacer()
                Text("85")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.25))
                Spacer()
                Text("120")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func segmentColor(for index: Int) -> Color {
        let fraction = Double(index) / Double(segmentCount - 1)
        let db = minDB + fraction * (maxDB - minDB)

        if db < 70 {
            return Color(red: 0.2, green: 0.78, blue: 0.35)
        } else if db < 85 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    private func segmentOpacity(for index: Int) -> Double {
        let fraction = Double(index) / Double(segmentCount - 1)
        return 0.6 + fraction * 0.4
    }
}
