import UIKit

@MainActor
struct NoiseScoreCardService {

    static func generateCard(for session: MeasurementSession) -> UIImage? {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let zone = NoiseZone.zone(for: session.avgDecibels)
            let zoneColor = zoneUIColor(zone)
            let accent = UIColor(red: 0, green: 1, blue: 0.53, alpha: 1)

            drawBackground(in: rect, ctx: ctx.cgContext, zoneColor: zoneColor)
            drawTopBar(in: rect, accent: accent)
            drawMainValue(in: rect, session: session, zoneColor: zoneColor)
            drawZoneBadge(in: rect, zone: zone, zoneColor: zoneColor)
            drawMetrics(in: rect, session: session, accent: accent)
            drawRiskBar(in: rect, session: session, zoneColor: zoneColor)
            drawSessionInfo(in: rect, session: session)
            drawBottomBranding(in: rect, accent: accent)
        }
    }

    private static func drawBackground(in rect: CGRect, ctx: CGContext, zoneColor: UIColor) {
        let bgColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        bgColor.setFill()
        UIRectFill(rect)

        ctx.saveGState()
        let center = CGPoint(x: rect.midX, y: rect.height * 0.38)
        let colors = [zoneColor.withAlphaComponent(0.12).cgColor, UIColor.clear.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 450, options: [])
        }
        ctx.restoreGState()
    }

    private static func drawTopBar(in rect: CGRect, accent: UIColor) {
        let logoFont = UIFont.systemFont(ofSize: 42, weight: .heavy)
        let logoAttr: [NSAttributedString.Key: Any] = [.font: logoFont, .foregroundColor: accent]
        let logo = "DECIBELPRO"
        let logoSize = logo.size(withAttributes: logoAttr)
        logo.draw(at: CGPoint(x: (rect.width - logoSize.width) / 2, y: 64), withAttributes: logoAttr)

        let tagFont = UIFont.systemFont(ofSize: 20, weight: .medium)
        let tagAttr: [NSAttributedString.Key: Any] = [.font: tagFont, .foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        let tag = "Sonomètre professionnel"
        let tagSize = tag.size(withAttributes: tagAttr)
        tag.draw(at: CGPoint(x: (rect.width - tagSize.width) / 2, y: 118), withAttributes: tagAttr)
    }

    private static func drawMainValue(in rect: CGRect, session: MeasurementSession, zoneColor: UIColor) {
        let valueStr = String(format: "%.1f", session.avgDecibels)
        let valueFont = UIFont.systemFont(ofSize: 180, weight: .heavy)
        let valueAttr: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: zoneColor]
        let valueSize = valueStr.size(withAttributes: valueAttr)
        valueStr.draw(at: CGPoint(x: (rect.width - valueSize.width) / 2, y: 220), withAttributes: valueAttr)

        let unitFont = UIFont.systemFont(ofSize: 60, weight: .bold)
        let unitAttr: [NSAttributedString.Key: Any] = [.font: unitFont, .foregroundColor: zoneColor.withAlphaComponent(0.6)]
        let unit = "dB"
        let unitSize = unit.size(withAttributes: unitAttr)
        unit.draw(at: CGPoint(x: (rect.width - unitSize.width) / 2, y: 410), withAttributes: unitAttr)
    }

    private static func drawZoneBadge(in rect: CGRect, zone: NoiseZone, zoneColor: UIColor) {
        let badgeWidth: CGFloat = 340
        let badgeHeight: CGFloat = 52
        let badgeRect = CGRect(x: (rect.width - badgeWidth) / 2, y: 500, width: badgeWidth, height: badgeHeight)
        zoneColor.withAlphaComponent(0.15).setFill()
        UIBezierPath(roundedRect: badgeRect, cornerRadius: 26).fill()

        let borderPath = UIBezierPath(roundedRect: badgeRect.insetBy(dx: 1, dy: 1), cornerRadius: 25)
        zoneColor.withAlphaComponent(0.3).setStroke()
        borderPath.lineWidth = 2
        borderPath.stroke()

        let font = UIFont.systemFont(ofSize: 24, weight: .bold)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: zoneColor]
        let label = zone.label.uppercased()
        let labelSize = label.size(withAttributes: attr)
        label.draw(at: CGPoint(x: badgeRect.midX - labelSize.width / 2, y: badgeRect.midY - labelSize.height / 2), withAttributes: attr)
    }

    private static func drawMetrics(in rect: CGRect, session: MeasurementSession, accent: UIColor) {
        let y: CGFloat = 590
        let cardWidth: CGFloat = 230
        let cardHeight: CGFloat = 100
        let spacing: CGFloat = 20
        let totalWidth = cardWidth * 4 + spacing * 3
        let startX = (rect.width - totalWidth) / 2

        let metrics: [(String, String, String)] = [
            ("Leq", String(format: "%.1f", session.leq), "dB(A)"),
            ("Peak", String(format: "%.1f", session.peakHold), "dB"),
            ("Min", String(format: "%.1f", session.minDecibels > 900 ? 0 : session.minDecibels), "dB"),
            ("Max", String(format: "%.1f", session.maxDecibels), "dB")
        ]

        for (i, metric) in metrics.enumerated() {
            let x = startX + CGFloat(i) * (cardWidth + spacing)
            let cardRect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)

            UIColor(white: 1, alpha: 0.06).setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: 16).fill()

            let labelFont = UIFont.systemFont(ofSize: 16, weight: .bold)
            let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: accent.withAlphaComponent(0.7)]
            metric.0.draw(at: CGPoint(x: x + 16, y: y + 14), withAttributes: labelAttr)

            let valFont = UIFont.systemFont(ofSize: 32, weight: .heavy)
            let valAttr: [NSAttributedString.Key: Any] = [.font: valFont, .foregroundColor: UIColor.white]
            metric.1.draw(at: CGPoint(x: x + 16, y: y + 42), withAttributes: valAttr)

            let unitFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let unitAttr: [NSAttributedString.Key: Any] = [.font: unitFont, .foregroundColor: UIColor.white.withAlphaComponent(0.3)]
            metric.2.draw(at: CGPoint(x: x + 16 + metric.1.size(withAttributes: valAttr).width + 4, y: y + 56), withAttributes: unitAttr)
        }
    }

    private static func drawRiskBar(in rect: CGRect, session: MeasurementSession, zoneColor: UIColor) {
        let y: CGFloat = 720
        let barMargin: CGFloat = 80
        let barWidth = rect.width - barMargin * 2
        let barHeight: CGFloat = 14

        let trackRect = CGRect(x: barMargin, y: y, width: barWidth, height: barHeight)
        UIColor(white: 1, alpha: 0.08).setFill()
        UIBezierPath(roundedRect: trackRect, cornerRadius: 7).fill()

        let progress = min(max(session.avgDecibels / 130.0, 0), 1.0)
        let fillRect = CGRect(x: barMargin, y: y, width: barWidth * progress, height: barHeight)
        let gradientColors = [
            UIColor(red: 0, green: 1, blue: 0.53, alpha: 1),
            UIColor(red: 1, green: 0.8, blue: 0, alpha: 1),
            UIColor(red: 1, green: 0.15, blue: 0.15, alpha: 1)
        ]
        let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: 7)
        UIGraphicsGetCurrentContext()?.saveGState()
        fillPath.addClip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: gradientColors.map(\.cgColor) as CFArray,
                                     locations: [0, 0.5, 1]) {
            UIGraphicsGetCurrentContext()?.drawLinearGradient(gradient,
                start: CGPoint(x: barMargin, y: y),
                end: CGPoint(x: barMargin + barWidth, y: y),
                options: [])
        }
        UIGraphicsGetCurrentContext()?.restoreGState()

        let riskFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let zone = NoiseZone.zone(for: session.avgDecibels)
        let riskText: String
        switch zone {
        case .silence, .quiet: riskText = "Aucun risque auditif"
        case .moderate: riskText = "Niveau modéré"
        case .loud: riskText = "Attention — exposition prolongée"
        case .veryLoud: riskText = "Risque auditif élevé"
        case .dangerous: riskText = "DANGER — Protection obligatoire"
        }
        let riskAttr: [NSAttributedString.Key: Any] = [.font: riskFont, .foregroundColor: zoneColor.withAlphaComponent(0.9)]
        let riskSize = riskText.size(withAttributes: riskAttr)
        riskText.draw(at: CGPoint(x: (rect.width - riskSize.width) / 2, y: y + 24), withAttributes: riskAttr)
    }

    private static func drawSessionInfo(in rect: CGRect, session: MeasurementSession) {
        let y: CGFloat = 800
        let secondaryColor = UIColor.white.withAlphaComponent(0.35)
        let font = UIFont.systemFont(ofSize: 20, weight: .medium)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: secondaryColor]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        dateFormatter.dateFormat = "d MMMM yyyy à HH:mm"

        var parts: [String] = [dateFormatter.string(from: session.startDate)]
        parts.append("Durée : \(session.formattedDuration)")
        if let location = session.location, !location.isEmpty {
            parts.append("📍 \(location)")
        }

        for (i, part) in parts.enumerated() {
            let partSize = part.size(withAttributes: attr)
            part.draw(at: CGPoint(x: (rect.width - partSize.width) / 2, y: y + CGFloat(i) * 34), withAttributes: attr)
        }
    }

    private static func drawBottomBranding(in rect: CGRect, accent: UIColor) {
        let lineY: CGFloat = 950
        let lineRect = CGRect(x: 200, y: lineY, width: rect.width - 400, height: 1)
        UIColor.white.withAlphaComponent(0.08).setFill()
        UIRectFill(lineRect)

        let font = UIFont.systemFont(ofSize: 22, weight: .bold)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent.withAlphaComponent(0.5)]
        let text = "Mesuré avec DecibelPro"
        let textSize = text.size(withAttributes: attr)
        text.draw(at: CGPoint(x: (rect.width - textSize.width) / 2, y: lineY + 20), withAttributes: attr)

        let hashFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        let hashAttr: [NSAttributedString.Key: Any] = [.font: hashFont, .foregroundColor: UIColor.white.withAlphaComponent(0.2)]
        let hash = "#DecibelPro"
        let hashSize = hash.size(withAttributes: hashAttr)
        hash.draw(at: CGPoint(x: (rect.width - hashSize.width) / 2, y: lineY + 50), withAttributes: hashAttr)
    }

    private static func zoneUIColor(_ zone: NoiseZone) -> UIColor {
        switch zone {
        case .silence: UIColor(red: 0, green: 0.8, blue: 0.4, alpha: 1)
        case .quiet: UIColor(red: 0, green: 1, blue: 0.53, alpha: 1)
        case .moderate: UIColor(red: 0.6, green: 0.9, blue: 0, alpha: 1)
        case .loud: UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        case .veryLoud: UIColor(red: 1, green: 0.4, blue: 0, alpha: 1)
        case .dangerous: UIColor(red: 1, green: 0.15, blue: 0.15, alpha: 1)
        }
    }
}
