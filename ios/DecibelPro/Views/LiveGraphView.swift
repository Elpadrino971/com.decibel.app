import SwiftUI

struct LiveGraphView: View {
    let samples: [Double]
    let maxValue: Double
    let isActive: Bool

    @State private var pulseOpacity: Double = 1.0
    private let graphHeight: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.path")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.53))
                Text("Niveau en temps réel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isActive {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(Color(red: 0, green: 1, blue: 0.53))
                        .symbolEffect(.pulse, isActive: isActive)
                }
            }

            Canvas { context, size in
                guard samples.count > 1 else { return }

                let maxVal = max(maxValue, 1)
                let step = size.width / CGFloat(max(samples.count - 1, 1))

                var path = Path()
                for (i, sample) in samples.enumerated() {
                    let x = CGFloat(i) * step
                    let normalized = CGFloat(min(sample / maxVal, 1))
                    let y = size.height - (normalized * (size.height - 4)) - 2

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0, green: 1, blue: 0.53).opacity(0.3),
                            Color(red: 0, green: 1, blue: 0.53)
                        ]),
                        startPoint: CGPoint(x: 0, y: size.height / 2),
                        endPoint: CGPoint(x: size.width, y: size.height / 2)
                    ),
                    lineWidth: 1.5
                )

                var fillPath = path
                if let lastPoint = samples.last {
                    let lastX = CGFloat(samples.count - 1) * step
                    let _ = lastPoint
                    fillPath.addLine(to: CGPoint(x: lastX, y: size.height))
                    fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                    fillPath.closeSubpath()
                }

                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0, green: 1, blue: 0.53).opacity(0.15),
                            Color(red: 0, green: 1, blue: 0.53).opacity(0.02)
                        ]),
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    )
                )
            }
            .frame(height: graphHeight)
            .clipShape(.rect(cornerRadius: 8))
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? "Graphique temps réel, niveau actuel \(String(format: "%.0f", samples.last ?? 0)) décibels" : "Graphique temps réel, inactif")
    }
}
