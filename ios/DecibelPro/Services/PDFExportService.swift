import UIKit
import PDFKit

@MainActor
struct PDFExportService {

    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
    private static let margin: CGFloat = 48
    private static let contentWidth: CGFloat = 595 - 48 * 2

    private static let bgColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
    private static let cardBg = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
    private static let accent = UIColor(red: 0, green: 1, blue: 0.53, alpha: 1)
    private static let textWhite = UIColor.white
    private static let textSecondary = UIColor(white: 0.55, alpha: 1)
    private static let greenZone = UIColor(red: 0, green: 0.8, blue: 0.4, alpha: 1)
    private static let orangeZone = UIColor(red: 1, green: 0.6, blue: 0, alpha: 1)
    private static let redZone = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)

    static func generateReport(for session: MeasurementSession, isPro: Bool = true) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            drawCoverPage(context: context, session: session, isPro: isPro)
            if isPro {
                drawResultsPage(context: context, session: session)
                if !session.samples.isEmpty {
                    drawGraphPage(context: context, session: session)
                }
                drawLegalPage(context: context, session: session)
            }
        }
    }

    // MARK: - Page 1 — Cover

    private static func drawCoverPage(context: UIGraphicsPDFRendererContext, session: MeasurementSession, isPro: Bool = true) {
        context.beginPage()
        fillBackground()

        var y: CGFloat = 100

        let logoFont = UIFont.systemFont(ofSize: 36, weight: .heavy)
        let logoAttr: [NSAttributedString.Key: Any] = [.font: logoFont, .foregroundColor: accent]
        let logoStr = "DecibelPro"
        let logoSize = logoStr.size(withAttributes: logoAttr)
        logoStr.draw(at: CGPoint(x: (pageRect.width - logoSize.width) / 2, y: y), withAttributes: logoAttr)
        y += logoSize.height + 6

        let taglineFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let taglineAttr: [NSAttributedString.Key: Any] = [.font: taglineFont, .foregroundColor: textSecondary]
        let tagline = "Sonomètre professionnel iOS"
        let taglineSize = tagline.size(withAttributes: taglineAttr)
        tagline.draw(at: CGPoint(x: (pageRect.width - taglineSize.width) / 2, y: y), withAttributes: taglineAttr)
        y += taglineSize.height + 40

        drawSeparator(y: y, color: accent)
        y += 24

        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textWhite]
        let title = "Rapport de Mesure Acoustique"
        let titleSize = title.size(withAttributes: titleAttr)
        title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: y), withAttributes: titleAttr)
        y += titleSize.height + 50

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        let infoItems: [(String, String)] = [
            ("Date", dateFormatter.string(from: session.startDate)),
            ("Durée", session.formattedDuration),
            ("Échantillons", "\(session.sampleCount)"),
            ("Calibration", session.calibrationPreset),
            ("Lieu", session.location ?? "Non renseigné")
        ]

        let infoBoxRect = CGRect(x: margin + 20, y: y, width: contentWidth - 40, height: CGFloat(infoItems.count) * 36 + 24)
        drawRoundedRect(rect: infoBoxRect, color: cardBg, radius: 12)
        y += 16

        let labelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 13, weight: .medium)

        for item in infoItems {
            let labelAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: accent]
            let valueAttr: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: textWhite]

            item.0.uppercased().draw(at: CGPoint(x: margin + 36, y: y), withAttributes: labelAttr)
            item.1.draw(at: CGPoint(x: margin + 180, y: y), withAttributes: valueAttr)
            y += 36
        }

        y = infoBoxRect.maxY + 40

        if let note = session.note, !note.isEmpty {
            let noteHeaderAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: accent]
            "NOTE".draw(at: CGPoint(x: margin + 20, y: y), withAttributes: noteHeaderAttr)
            y += 20
            let noteAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: textWhite]
            let noteRect = CGRect(x: margin + 20, y: y, width: contentWidth - 40, height: 60)
            note.draw(in: noteRect, withAttributes: noteAttr)
            y += 70
        }

        let zone = NoiseZone.zone(for: session.avgDecibels)
        let zoneBoxRect = CGRect(x: margin + 60, y: y + 20, width: contentWidth - 120, height: 80)
        drawRoundedRect(rect: zoneBoxRect, color: zoneUIColor(zone).withAlphaComponent(0.12), radius: 14)

        let dbFont = UIFont.systemFont(ofSize: 42, weight: .heavy)
        let dbAttr: [NSAttributedString.Key: Any] = [.font: dbFont, .foregroundColor: zoneUIColor(zone)]
        let dbStr = String(format: "%.1f dB", session.avgDecibels)
        let dbSize = dbStr.size(withAttributes: dbAttr)
        dbStr.draw(at: CGPoint(x: (pageRect.width - dbSize.width) / 2, y: zoneBoxRect.minY + 8), withAttributes: dbAttr)

        let zoneLabelFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let zoneLabelAttr: [NSAttributedString.Key: Any] = [.font: zoneLabelFont, .foregroundColor: zoneUIColor(zone)]
        let zoneLabel = zone.label
        let zoneLabelSize = zoneLabel.size(withAttributes: zoneLabelAttr)
        zoneLabel.draw(at: CGPoint(x: (pageRect.width - zoneLabelSize.width) / 2, y: zoneBoxRect.minY + 56), withAttributes: zoneLabelAttr)

        if !isPro {
            drawWatermark()
        }

        drawFooter(text: "Généré par DecibelPro — Conforme NF S31-010")
    }

    // MARK: - Page 2 — Results

    private static func drawResultsPage(context: UIGraphicsPDFRendererContext, session: MeasurementSession) {
        context.beginPage()
        fillBackground()

        var y: CGFloat = 40

        y = drawPageHeader(title: "Résultats principaux", y: y)
        y += 12

        let metrics: [(String, String, UIColor)] = [
            ("Leq (niveau équivalent)", String(format: "%.1f dB(A)", session.leq), accent),
            ("Lmax (maximum)", String(format: "%.1f dB", session.maxDecibels), orangeZone),
            ("Lmin (minimum)", String(format: "%.1f dB", session.minDecibels > 900 ? 0 : session.minDecibels), greenZone),
            ("Peak Hold", String(format: "%.1f dB", session.peakHold), redZone)
        ]

        let cardWidth = (contentWidth - 12) / 2
        let cardHeight: CGFloat = 72

        for (index, metric) in metrics.enumerated() {
            let col = index % 2
            let row = index / 2
            let x = margin + CGFloat(col) * (cardWidth + 12)
            let cardY = y + CGFloat(row) * (cardHeight + 10)
            let rect = CGRect(x: x, y: cardY, width: cardWidth, height: cardHeight)

            drawRoundedRect(rect: rect, color: cardBg, radius: 10)

            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: metric.2
            ]
            metric.0.uppercased().draw(at: CGPoint(x: x + 14, y: cardY + 12), withAttributes: labelAttr)

            let valAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .heavy),
                .foregroundColor: textWhite
            ]
            metric.1.draw(at: CGPoint(x: x + 14, y: cardY + 32), withAttributes: valAttr)
        }

        y += 2 * (cardHeight + 10) + 24

        y = drawSectionHeader(title: "Interprétation OMS", y: y)
        y += 8

        let interpretations: [(String, String, UIColor)] = [
            ("< 53 dB", "Niveau acceptable — pas de perturbation", greenZone),
            ("53–70 dB", "Gêne modérée — surveillance recommandée", UIColor(red: 0.6, green: 0.9, blue: 0, alpha: 1)),
            ("70–85 dB", "Risque auditif à terme — limitation d'exposition", orangeZone),
            ("> 85 dB", "Danger immédiat — protection obligatoire", redZone)
        ]

        for interp in interpretations {
            let isActive = isInRange(session.avgDecibels, label: interp.0)

            let boxRect = CGRect(x: margin, y: y, width: contentWidth, height: 36)
            if isActive {
                drawRoundedRect(rect: boxRect, color: interp.2.withAlphaComponent(0.1), radius: 6)
            }

            let dotRect = CGRect(x: margin + 12, y: y + 13, width: 10, height: 10)
            let dotPath = UIBezierPath(ovalIn: dotRect)
            interp.2.setFill()
            dotPath.fill()

            let rangeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: isActive ? textWhite : textSecondary
            ]
            interp.0.draw(at: CGPoint(x: margin + 30, y: y + 10), withAttributes: rangeAttr)

            let descAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: isActive ? .semibold : .regular),
                .foregroundColor: isActive ? textWhite : textSecondary
            ]
            interp.1.draw(at: CGPoint(x: margin + 110, y: y + 11), withAttributes: descAttr)

            if isActive {
                let checkAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: interp.2
                ]
                "●".draw(at: CGPoint(x: margin + contentWidth - 24, y: y + 10), withAttributes: checkAttr)
            }

            y += 40
        }

        y += 16
        y = drawSectionHeader(title: "Seuils légaux français", y: y)
        y += 8

        let legalItems: [(String, String, String)] = [
            ("Voisinage", "Art. R. 1334-31 Code Santé Publique", "5 dB(A) d'émergence jour / 3 dB nuit"),
            ("Chantier BTP", "Décret 2006-1273", "85 dB(A) max exposition quotidienne"),
            ("Concert / Événement", "Décret 2017-1244", "102 dB(A) niveau moyen / 118 dB crête")
        ]

        for item in legalItems {
            let boxRect = CGRect(x: margin, y: y, width: contentWidth, height: 56)
            drawRoundedRect(rect: boxRect, color: cardBg, radius: 8)

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: accent
            ]
            item.0.draw(at: CGPoint(x: margin + 14, y: y + 8), withAttributes: titleAttr)

            let refAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: textSecondary
            ]
            item.1.draw(at: CGPoint(x: margin + 14, y: y + 24), withAttributes: refAttr)

            let valAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: textWhite
            ]
            item.2.draw(at: CGPoint(x: margin + 14, y: y + 38), withAttributes: valAttr)

            y += 62
        }

        drawFooter(text: "DecibelPro — Rapport de mesure acoustique — Page 2")
    }

    // MARK: - Page 3 — Graph

    private static func drawGraphPage(context: UIGraphicsPDFRendererContext, session: MeasurementSession) {
        context.beginPage()
        fillBackground()

        var y: CGFloat = 40

        y = drawPageHeader(title: "Courbe temporelle", y: y)
        y += 16

        let graphRect = CGRect(x: margin, y: y, width: contentWidth, height: 340)
        drawRoundedRect(rect: graphRect, color: cardBg, radius: 12)

        let innerMargin: CGFloat = 12
        let plotRect = CGRect(
            x: graphRect.minX + 40,
            y: graphRect.minY + innerMargin,
            width: graphRect.width - 52,
            height: graphRect.height - innerMargin * 2 - 20
        )

        let samples = session.samples
        guard !samples.isEmpty else { return }

        let minVal = max(0, (session.minDecibels > 900 ? 0 : session.minDecibels) - 10)
        let maxVal = min(140, session.maxDecibels + 10)
        let range = maxVal - minVal

        let thresholds: [(Double, UIColor, String)] = [
            (85, redZone, "85 dB — Danger"),
            (70, orangeZone, "70 dB — Attention"),
            (53, UIColor(red: 0.6, green: 0.9, blue: 0, alpha: 1), "53 dB — OMS")
        ]

        for threshold in thresholds {
            guard threshold.0 >= minVal && threshold.0 <= maxVal else { continue }
            let thresholdY = plotRect.maxY - CGFloat((threshold.0 - minVal) / range) * plotRect.height

            let dashPath = UIBezierPath()
            dashPath.move(to: CGPoint(x: plotRect.minX, y: thresholdY))
            dashPath.addLine(to: CGPoint(x: plotRect.maxX, y: thresholdY))
            dashPath.setLineDash([4, 4], count: 2, phase: 0)
            threshold.1.withAlphaComponent(0.4).setStroke()
            dashPath.lineWidth = 0.8
            dashPath.stroke()

            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7, weight: .medium),
                .foregroundColor: threshold.1.withAlphaComponent(0.7)
            ]
            threshold.2.draw(at: CGPoint(x: plotRect.maxX - 80, y: thresholdY - 10), withAttributes: labelAttr)
        }

        let yAxisValues = stride(from: ceil(minVal / 10) * 10, through: maxVal, by: 20)
        let axisAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: textSecondary
        ]
        for val in yAxisValues {
            let axisY = plotRect.maxY - CGFloat((val - minVal) / range) * plotRect.height
            let gridPath = UIBezierPath()
            gridPath.move(to: CGPoint(x: plotRect.minX, y: axisY))
            gridPath.addLine(to: CGPoint(x: plotRect.maxX, y: axisY))
            UIColor.white.withAlphaComponent(0.06).setStroke()
            gridPath.lineWidth = 0.5
            gridPath.stroke()

            let label = String(format: "%.0f", val)
            let labelSize = label.size(withAttributes: axisAttr)
            label.draw(at: CGPoint(x: plotRect.minX - labelSize.width - 6, y: axisY - labelSize.height / 2), withAttributes: axisAttr)
        }

        let fillPath = UIBezierPath()
        let linePath = UIBezierPath()
        let step = plotRect.width / CGFloat(max(samples.count - 1, 1))

        for (i, sample) in samples.enumerated() {
            let x = plotRect.minX + CGFloat(i) * step
            let normalized = CGFloat((sample - minVal) / range)
            let sampleY = plotRect.maxY - normalized * plotRect.height

            if i == 0 {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: sampleY))
                linePath.move(to: CGPoint(x: x, y: sampleY))
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: sampleY))
                linePath.addLine(to: CGPoint(x: x, y: sampleY))
            }
        }

        fillPath.addLine(to: CGPoint(x: plotRect.minX + CGFloat(samples.count - 1) * step, y: plotRect.maxY))
        fillPath.close()

        UIGraphicsGetCurrentContext()?.saveGState()
        let gradientColors = [accent.withAlphaComponent(0.25).cgColor, accent.withAlphaComponent(0.01).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: [0, 1]) {
            fillPath.addClip()
            UIGraphicsGetCurrentContext()?.drawLinearGradient(
                gradient,
                start: CGPoint(x: plotRect.midX, y: plotRect.minY),
                end: CGPoint(x: plotRect.midX, y: plotRect.maxY),
                options: []
            )
        }
        UIGraphicsGetCurrentContext()?.restoreGState()

        accent.setStroke()
        linePath.lineWidth = 1.5
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.stroke()

        let duration = session.duration
        let xAxisCount = 6
        for i in 0...xAxisCount {
            let frac = CGFloat(i) / CGFloat(xAxisCount)
            let x = plotRect.minX + frac * plotRect.width
            let seconds = duration * Double(frac)
            let timeStr = formatTimeShort(seconds)
            let timeSize = timeStr.size(withAttributes: axisAttr)
            timeStr.draw(at: CGPoint(x: x - timeSize.width / 2, y: plotRect.maxY + 4), withAttributes: axisAttr)
        }

        y = graphRect.maxY + 24

        y = drawSectionHeader(title: "Légende", y: y)
        y += 10

        let legendItems: [(String, UIColor)] = [
            ("Niveau mesuré (dB)", accent),
            ("Seuil OMS (53 dB)", UIColor(red: 0.6, green: 0.9, blue: 0, alpha: 1)),
            ("Seuil attention (70 dB)", orangeZone),
            ("Seuil danger (85 dB)", redZone)
        ]

        let legendStartX = margin + 20
        var legendX = legendStartX

        for item in legendItems {
            let dotRect = CGRect(x: legendX, y: y + 4, width: 8, height: 8)
            item.1.setFill()
            UIBezierPath(ovalIn: dotRect).fill()

            let attr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: textSecondary
            ]
            let textX = legendX + 14
            item.0.draw(at: CGPoint(x: textX, y: y), withAttributes: attr)
            let textWidth = item.0.size(withAttributes: attr).width
            legendX = textX + textWidth + 20

            if legendX > margin + contentWidth - 80 {
                legendX = legendStartX
                y += 20
            }
        }

        y += 36

        y = drawSectionHeader(title: "Statistiques de la courbe", y: y)
        y += 10

        let statsBoxRect = CGRect(x: margin, y: y, width: contentWidth, height: 80)
        drawRoundedRect(rect: statsBoxRect, color: cardBg, radius: 10)

        let statItems: [(String, String)] = [
            ("Min", String(format: "%.1f dB", session.minDecibels > 900 ? 0 : session.minDecibels)),
            ("Moy", String(format: "%.1f dB", session.avgDecibels)),
            ("Max", String(format: "%.1f dB", session.maxDecibels)),
            ("Leq", String(format: "%.1f dB(A)", session.leq))
        ]

        let statWidth = contentWidth / CGFloat(statItems.count)
        for (i, stat) in statItems.enumerated() {
            let sx = margin + CGFloat(i) * statWidth

            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: accent
            ]
            let labelSize = stat.0.size(withAttributes: labelAttr)
            stat.0.draw(at: CGPoint(x: sx + (statWidth - labelSize.width) / 2, y: y + 14), withAttributes: labelAttr)

            let valAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: textWhite
            ]
            let valSize = stat.1.size(withAttributes: valAttr)
            stat.1.draw(at: CGPoint(x: sx + (statWidth - valSize.width) / 2, y: y + 36), withAttributes: valAttr)
        }

        drawFooter(text: "DecibelPro — Rapport de mesure acoustique — Page 3")
    }

    // MARK: - Page 4 — Legal

    private static func drawLegalPage(context: UIGraphicsPDFRendererContext, session: MeasurementSession) {
        context.beginPage()
        fillBackground()

        var y: CGFloat = 40

        y = drawPageHeader(title: "Informations légales", y: y)
        y += 16

        y = drawSectionHeader(title: "Avertissement", y: y)
        y += 8

        let warningRect = CGRect(x: margin, y: y, width: contentWidth, height: 88)
        drawRoundedRect(rect: warningRect, color: orangeZone.withAlphaComponent(0.08), radius: 10)

        let warningBorderPath = UIBezierPath(roundedRect: warningRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 10)
        orangeZone.withAlphaComponent(0.25).setStroke()
        warningBorderPath.lineWidth = 1
        warningBorderPath.stroke()

        let warningTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: orangeZone
        ]
        "⚠  MESURE INDICATIVE".draw(at: CGPoint(x: margin + 16, y: y + 12), withAttributes: warningTitleAttr)

        let warningText = "Cette mesure est réalisée avec un microphone de smartphone et ne constitue pas une mesure certifiée. Pour une mesure légalement opposable, utilisez un sonomètre certifié COFRAC de classe 1 ou 2 (norme IEC 61672)."
        let warningAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textWhite
        ]
        let warningTextRect = CGRect(x: margin + 16, y: y + 32, width: contentWidth - 32, height: 50)
        warningText.draw(in: warningTextRect, withAttributes: warningAttr)

        y = warningRect.maxY + 28

        y = drawSectionHeader(title: "Normes de référence", y: y)
        y += 8

        let norms: [(String, String)] = [
            ("NF S31-010", "Caractérisation et mesurage des bruits de l'environnement"),
            ("ISO 1996-1/2", "Description, mesurage et évaluation du bruit de l'environnement"),
            ("ISO 9612", "Détermination de l'exposition au bruit en milieu de travail"),
            ("IEC 61672", "Électroacoustique — Sonomètres"),
            ("Directive 2003/10/CE", "Exposition des travailleurs au bruit"),
            ("Décret 2017-1244", "Prévention des risques liés aux bruits amplifiés"),
            ("Art. R. 1334-31", "Code de la santé publique — Bruits de voisinage")
        ]

        for norm in norms {
            let rowRect = CGRect(x: margin, y: y, width: contentWidth, height: 32)
            drawRoundedRect(rect: rowRect, color: cardBg, radius: 6)

            let codeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: accent
            ]
            norm.0.draw(at: CGPoint(x: margin + 12, y: y + 9), withAttributes: codeAttr)

            let descAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: textSecondary
            ]
            norm.1.draw(at: CGPoint(x: margin + 130, y: y + 10), withAttributes: descAttr)

            y += 36
        }

        y += 20

        y = drawSectionHeader(title: "Signature / Observations", y: y)
        y += 8

        let sigBoxRect = CGRect(x: margin, y: y, width: contentWidth, height: 120)
        drawRoundedRect(rect: sigBoxRect, color: cardBg, radius: 10)

        let sigBorderPath = UIBezierPath(roundedRect: sigBoxRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 10)
        UIColor.white.withAlphaComponent(0.08).setStroke()
        sigBorderPath.lineWidth = 0.5
        sigBorderPath.stroke()

        let sigAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: textSecondary
        ]
        "Signature :".draw(at: CGPoint(x: margin + 16, y: y + 14), withAttributes: sigAttr)
        "Date :".draw(at: CGPoint(x: margin + 16, y: y + 80), withAttributes: sigAttr)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        dateFormatter.dateStyle = .long
        let dateStr = dateFormatter.string(from: Date())
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: textWhite
        ]
        dateStr.draw(at: CGPoint(x: margin + 56, y: y + 80), withAttributes: dateAttr)

        let sigLine = UIBezierPath()
        sigLine.move(to: CGPoint(x: margin + 80, y: y + 60))
        sigLine.addLine(to: CGPoint(x: margin + contentWidth - 40, y: y + 60))
        UIColor.white.withAlphaComponent(0.12).setStroke()
        sigLine.lineWidth = 0.5
        sigLine.stroke()

        y = sigBoxRect.maxY + 28

        let idFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let idAttr: [NSAttributedString.Key: Any] = [.font: idFont, .foregroundColor: textSecondary]
        let idStr = "Réf. rapport : DP-\(session.id.uuidString.prefix(8).uppercased())"
        let idSize = idStr.size(withAttributes: idAttr)
        idStr.draw(at: CGPoint(x: (pageRect.width - idSize.width) / 2, y: y), withAttributes: idAttr)

        let pageNum = session.samples.isEmpty ? 3 : 4
        drawFooter(text: "DecibelPro — Rapport de mesure acoustique — Page \(pageNum)")
    }

    // MARK: - Drawing Helpers

    private static func fillBackground() {
        bgColor.setFill()
        UIRectFill(pageRect)
    }

    private static func drawRoundedRect(rect: CGRect, color: UIColor, radius: CGFloat) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
    }

    private static func drawSeparator(y: CGFloat, color: UIColor) {
        let rect = CGRect(x: margin + 40, y: y, width: contentWidth - 80, height: 1)
        color.setFill()
        UIRectFill(rect)
    }

    private static func drawPageHeader(title: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 18, weight: .bold)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textWhite]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attr)

        let subtitleY = y + 24
        drawSeparator(y: subtitleY, color: accent.withAlphaComponent(0.3))

        return subtitleY + 10
    }

    private static func drawSectionHeader(title: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .bold)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent]
        title.uppercased().draw(at: CGPoint(x: margin, y: y), withAttributes: attr)
        return y + 20
    }

    private static func drawFooter(text: String) {
        let font = UIFont.systemFont(ofSize: 8, weight: .medium)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textSecondary]
        let size = text.size(withAttributes: attr)
        text.draw(at: CGPoint(x: (pageRect.width - size.width) / 2, y: pageRect.height - 36), withAttributes: attr)
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

    private static func isInRange(_ db: Double, label: String) -> Bool {
        switch label {
        case "< 53 dB": return db < 53
        case "53–70 dB": return db >= 53 && db < 70
        case "70–85 dB": return db >= 70 && db < 85
        case "> 85 dB": return db >= 85
        default: return false
        }
    }

    private static func formatTimeShort(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m > 0 {
            return "\(m)m\(String(format: "%02d", s))s"
        }
        return "\(s)s"
    }

    private static func drawWatermark() {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()

        let watermarkFont = UIFont.systemFont(ofSize: 48, weight: .heavy)
        let watermarkAttr: [NSAttributedString.Key: Any] = [
            .font: watermarkFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.06)
        ]
        let text = "DecibelPro Free"
        let textSize = text.size(withAttributes: watermarkAttr)

        ctx.translateBy(x: pageRect.midX, y: pageRect.midY)
        ctx.rotate(by: -.pi / 4)

        text.draw(
            at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2),
            withAttributes: watermarkAttr
        )

        ctx.restoreGState()
    }
}
