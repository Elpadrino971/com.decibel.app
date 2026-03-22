import SwiftUI

struct ArcGaugeView: View {
    let decibels: Double
    let isActive: Bool

    private let minDB: Double = 30
    private let maxDB: Double = 120
    private let startAngle: Double = 135
    private let sweepAngle: Double = 270
    private let trackWidth: CGFloat = 20

    private var endAngle: Double { startAngle + sweepAngle }

    private var normalizedValue: Double {
        let clamped = isActive ? decibels : minDB
        return min(max((clamped - minDB) / (maxDB - minDB), 0), 1)
    }

    private var needleAngle: Double {
        startAngle + normalizedValue * sweepAngle
    }

    private var zoneColor: Color {
        isActive ? NoiseZone.zone(for: decibels).color : .white.opacity(0.2)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let outerRadius = (size / 2) - 8

            ZStack {
                arcZones(center: center, radius: outerRadius)
                arcActiveFill(center: center, radius: outerRadius)
                tickMarksCanvas(center: center, radius: outerRadius)
                scaleLabelsView(center: center, radius: outerRadius)
                needleShape(center: center, radius: outerRadius)
                centerHub(center: center)
                centerReadout(center: center, size: size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? "Niveau sonore \(String(format: "%.0f", decibels)) décibels, zone \(NoiseZone.zone(for: decibels).label)" : "Sonomètre prêt")
        .accessibilityValue(isActive ? String(format: "%.1f dB", decibels) : "Inactif")
    }

    private func arcZones(center: CGPoint, radius: CGFloat) -> some View {
        let r = radius - trackWidth / 2

        return ZStack {
            zoneArc(center: center, radius: r,
                     fromDB: 30, toDB: 70,
                     color: Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.12))
            zoneArc(center: center, radius: r,
                     fromDB: 70, toDB: 85,
                     color: Color.orange.opacity(0.12))
            zoneArc(center: center, radius: r,
                     fromDB: 85, toDB: 120,
                     color: Color.red.opacity(0.12))
        }
    }

    private func zoneArc(center: CGPoint, radius: CGFloat,
                          fromDB: Double, toDB: Double, color: Color) -> some View {
        let startFrac = max(0, (fromDB - minDB) / (maxDB - minDB))
        let endFrac = min(1, (toDB - minDB) / (maxDB - minDB))
        let sAngle = startAngle + startFrac * sweepAngle
        let eAngle = startAngle + endFrac * sweepAngle

        return Path { path in
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(sAngle), endAngle: .degrees(eAngle), clockwise: false)
        }
        .stroke(color, style: StrokeStyle(lineWidth: trackWidth, lineCap: .butt))
    }

    private func arcActiveFill(center: CGPoint, radius: CGFloat) -> some View {
        let r = radius - trackWidth / 2
        let fillEnd = startAngle + normalizedValue * sweepAngle

        return ZStack {
            Path { path in
                path.addArc(center: center, radius: r,
                            startAngle: .degrees(startAngle), endAngle: .degrees(fillEnd), clockwise: false)
            }
            .stroke(
                AngularGradient(
                    colors: [
                        Color(red: 0.2, green: 0.78, blue: 0.35),
                        Color(red: 0.2, green: 0.78, blue: 0.35),
                        Color(red: 0.4, green: 0.85, blue: 0.2),
                        Color.orange,
                        Color(red: 1, green: 0.35, blue: 0.15),
                        Color.red
                    ],
                    center: .center,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle)
                ),
                style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
            )
            .opacity(isActive ? 1.0 : 0.15)
            .shadow(color: zoneColor.opacity(isActive ? 0.6 : 0), radius: 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: decibels)

            if isActive {
                Path { path in
                    path.addArc(center: center, radius: r,
                                startAngle: .degrees(fillEnd - 2), endAngle: .degrees(fillEnd), clockwise: false)
                }
                .stroke(zoneColor, style: StrokeStyle(lineWidth: trackWidth + 4, lineCap: .round))
                .blur(radius: 8)
                .opacity(0.6)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: decibels)
            }
        }
    }

    private func tickMarksCanvas(center: CGPoint, radius: CGFloat) -> some View {
        let innerRadius = radius - trackWidth - 6

        return Canvas { context, _ in
            for i in 0..<19 {
                let db = minDB + Double(i) * 5.0
                let frac = (db - minDB) / (maxDB - minDB)
                let angle = startAngle + frac * sweepAngle
                let isMajor = i % 2 == 0
                let tickLen: CGFloat = isMajor ? 10 : 5
                let rad = CGFloat(angle) * .pi / 180.0

                let cosVal = CoreGraphics.cos(rad)
                let sinVal = CoreGraphics.sin(rad)

                let outerPt = CGPoint(x: center.x + innerRadius * cosVal,
                                      y: center.y + innerRadius * sinVal)
                let innerPt = CGPoint(x: center.x + (innerRadius - tickLen) * cosVal,
                                      y: center.y + (innerRadius - tickLen) * sinVal)

                var path = Path()
                path.move(to: outerPt)
                path.addLine(to: innerPt)

                context.stroke(path,
                               with: .color(.white.opacity(isMajor ? 0.45 : 0.15)),
                               lineWidth: isMajor ? 1.5 : 0.8)
            }
        }
    }

    private func scaleLabelsView(center: CGPoint, radius: CGFloat) -> some View {
        let labelRadius = radius - trackWidth - 24
        let labels: [Int] = [30, 50, 70, 85, 100, 120]

        return ForEach(labels, id: \.self) { db in
            let frac = (Double(db) - minDB) / (maxDB - minDB)
            let angle = startAngle + frac * sweepAngle
            let rad = CGFloat(angle) * .pi / 180.0
            let xPos = center.x + labelRadius * CoreGraphics.cos(rad)
            let yPos = center.y + labelRadius * CoreGraphics.sin(rad)

            Text("\(db)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.35))
                .position(x: xPos, y: yPos)
        }
    }

    private func needleShape(center: CGPoint, radius: CGFloat) -> some View {
        let needleLen = radius - trackWidth - 8
        let rad = CGFloat(needleAngle) * .pi / 180.0

        let cosR = CoreGraphics.cos(rad)
        let sinR = CoreGraphics.sin(rad)

        let tip = CGPoint(x: center.x + needleLen * cosR,
                          y: center.y + needleLen * sinR)
        let tail: CGFloat = 16
        let backPt = CGPoint(x: center.x - tail * cosR,
                             y: center.y - tail * sinR)

        let perpRad = rad + .pi / 2
        let cosP = CoreGraphics.cos(perpRad)
        let sinP = CoreGraphics.sin(perpRad)
        let halfBase: CGFloat = 3
        let base1 = CGPoint(x: center.x + halfBase * cosP,
                            y: center.y + halfBase * sinP)
        let base2 = CGPoint(x: center.x - halfBase * cosP,
                            y: center.y - halfBase * sinP)

        return Path { path in
            path.move(to: tip)
            path.addLine(to: base1)
            path.addLine(to: backPt)
            path.addLine(to: base2)
            path.closeSubpath()
        }
        .fill(isActive ? zoneColor : .white.opacity(0.25))
        .shadow(color: zoneColor.opacity(isActive ? 0.7 : 0), radius: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive ? decibels : minDB)
    }

    private func centerHub(center: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.25), .white.opacity(0.04)],
                                   center: .center, startRadius: 0, endRadius: 10)
                )
                .frame(width: 18, height: 18)
            Circle()
                .fill(isActive ? zoneColor : .white.opacity(0.15))
                .frame(width: 8, height: 8)
                .shadow(color: zoneColor.opacity(isActive ? 0.8 : 0), radius: 5)
        }
        .position(center)
    }

    private func centerReadout(center: CGPoint, size: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(isActive ? String(format: "%.1f", decibels) : "—")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? zoneColor : .white.opacity(0.15))
                .contentTransition(.numericText(value: decibels))
                .animation(.snappy(duration: 0.15), value: Int(decibels * 10))

            Text("dB(A)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, -6)

            Text(isActive ? NoiseZone.zone(for: decibels).label : "Prêt")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? zoneColor.opacity(0.8) : .white.opacity(0.2))
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.2), value: isActive ? NoiseZone.zone(for: decibels).rawValue : "idle")
        }
        .position(x: center.x, y: center.y + size * 0.08)
    }
}
