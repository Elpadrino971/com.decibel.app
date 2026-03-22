import UIKit
import CoreLocation
import CryptoKit

@Observable
@MainActor
final class LitigeService: NSObject, CLLocationManagerDelegate {
    var currentLocation: CLLocation?
    var currentAddress: String?
    var isLocating: Bool = false
    var locationError: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        isLocating = true
        locationError = nil
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            locationError = "Accès à la localisation refusé"
            isLocating = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.isLocating = false
            self.reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = "Localisation indisponible"
            self.isLocating = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                if let placemark = placemarks?.first {
                    let parts = [placemark.thoroughfare, placemark.subThoroughfare, placemark.postalCode, placemark.locality].compactMap { $0 }
                    self?.currentAddress = parts.joined(separator: " ")
                }
            }
        }
    }

    static func computeSHA256(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func generateLitigePDF(for session: MeasurementSession, location: CLLocation?, address: String?) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 48
        let contentWidth = pageRect.width - margin * 2

        let bgColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
        let cardBg = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
        let accent = UIColor(red: 0, green: 1, blue: 0.53, alpha: 1)
        let textWhite = UIColor.white
        let textSecondary = UIColor(white: 0.55, alpha: 1)
        let redColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            var y: CGFloat = 40

            let stampFont = UIFont.systemFont(ofSize: 10, weight: .bold)
            let stampAttr: [NSAttributedString.Key: Any] = [.font: stampFont, .foregroundColor: redColor]
            let stamp = "DOCUMENT DE CONSTAT — MODE LITIGE"
            let stampSize = stamp.size(withAttributes: stampAttr)
            stamp.draw(at: CGPoint(x: (pageRect.width - stampSize.width) / 2, y: y), withAttributes: stampAttr)
            y += 24

            let logoFont = UIFont.systemFont(ofSize: 28, weight: .heavy)
            let logoAttr: [NSAttributedString.Key: Any] = [.font: logoFont, .foregroundColor: accent]
            let logo = "DecibelPro"
            let logoSize = logo.size(withAttributes: logoAttr)
            logo.draw(at: CGPoint(x: (pageRect.width - logoSize.width) / 2, y: y), withAttributes: logoAttr)
            y += logoSize.height + 4

            let subFont = UIFont.systemFont(ofSize: 10, weight: .medium)
            let subAttr: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: textSecondary]
            let sub = "Constat de nuisance sonore — Preuve horodatée"
            let subSize = sub.size(withAttributes: subAttr)
            sub.draw(at: CGPoint(x: (pageRect.width - subSize.width) / 2, y: y), withAttributes: subAttr)
            y += 30

            let sepRect = CGRect(x: margin + 40, y: y, width: contentWidth - 80, height: 1)
            accent.setFill()
            UIRectFill(sepRect)
            y += 20

            let titleFont = UIFont.systemFont(ofSize: 16, weight: .bold)
            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textWhite]
            "INFORMATIONS DE LA MESURE".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 28

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "fr_FR")
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .medium

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withFullDate, .withFullTime, .withTimeZone]

            var infoItems: [(String, String)] = [
                ("Date et heure", dateFormatter.string(from: session.startDate)),
                ("Horodatage ISO 8601", isoFormatter.string(from: session.startDate)),
                ("Durée d'enregistrement", session.formattedDuration),
                ("Échantillons collectés", "\(session.sampleCount)"),
                ("Preset de calibration", session.calibrationPreset)
            ]

            if let loc = location {
                infoItems.append(("Coordonnées GPS", String(format: "%.6f, %.6f (±%.0fm)", loc.coordinate.latitude, loc.coordinate.longitude, loc.horizontalAccuracy)))
                infoItems.append(("Altitude", String(format: "%.1f m", loc.altitude)))
            }

            if let addr = address, !addr.isEmpty {
                infoItems.append(("Adresse", addr))
            } else if let sessionLoc = session.location, !sessionLoc.isEmpty {
                infoItems.append(("Lieu déclaré", sessionLoc))
            }

            let infoBoxHeight = CGFloat(infoItems.count) * 28 + 20
            let infoBoxRect = CGRect(x: margin, y: y, width: contentWidth, height: infoBoxHeight)
            cardBg.setFill()
            UIBezierPath(roundedRect: infoBoxRect, cornerRadius: 10).fill()
            y += 12

            let labelFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let valueFont = UIFont.systemFont(ofSize: 11, weight: .medium)

            for item in infoItems {
                let lAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: accent]
                let vAttr: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: textWhite]
                item.0.uppercased().draw(at: CGPoint(x: margin + 14, y: y), withAttributes: lAttr)
                item.1.draw(at: CGPoint(x: margin + 180, y: y), withAttributes: vAttr)
                y += 28
            }

            y = infoBoxRect.maxY + 20

            "RÉSULTATS DE LA MESURE".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 28

            let zone = NoiseZone.zone(for: session.avgDecibels)
            let zoneColor = zoneUIColor(zone)
            let dbBoxRect = CGRect(x: margin + 40, y: y, width: contentWidth - 80, height: 70)
            zoneColor.withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: dbBoxRect, cornerRadius: 12).fill()

            let dbFont = UIFont.systemFont(ofSize: 36, weight: .heavy)
            let dbAttr: [NSAttributedString.Key: Any] = [.font: dbFont, .foregroundColor: zoneColor]
            let dbStr = String(format: "%.1f dB(A) Leq", session.leq)
            let dbSize = dbStr.size(withAttributes: dbAttr)
            dbStr.draw(at: CGPoint(x: (pageRect.width - dbSize.width) / 2, y: y + 6), withAttributes: dbAttr)

            let zLabelFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let zLabelAttr: [NSAttributedString.Key: Any] = [.font: zLabelFont, .foregroundColor: zoneColor]
            let zLabel = "Zone : \(zone.label)"
            let zLabelSize = zLabel.size(withAttributes: zLabelAttr)
            zLabel.draw(at: CGPoint(x: (pageRect.width - zLabelSize.width) / 2, y: y + 48), withAttributes: zLabelAttr)

            y = dbBoxRect.maxY + 16

            let metricsData: [(String, String)] = [
                ("Leq (niveau équivalent)", String(format: "%.1f dB(A)", session.leq)),
                ("Niveau maximal (Lmax)", String(format: "%.1f dB", session.maxDecibels)),
                ("Niveau minimal (Lmin)", String(format: "%.1f dB", session.minDecibels > 900 ? 0 : session.minDecibels)),
                ("Peak Hold", String(format: "%.1f dB", session.peakHold))
            ]

            for metric in metricsData {
                let rowRect = CGRect(x: margin, y: y, width: contentWidth, height: 26)
                cardBg.setFill()
                UIBezierPath(roundedRect: rowRect, cornerRadius: 4).fill()

                let mLabelAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: textSecondary]
                let mValAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: textWhite]
                metric.0.draw(at: CGPoint(x: margin + 12, y: y + 6), withAttributes: mLabelAttr)
                let valSize = metric.1.size(withAttributes: mValAttr)
                metric.1.draw(at: CGPoint(x: margin + contentWidth - valSize.width - 12, y: y + 6), withAttributes: mValAttr)
                y += 30
            }

            y += 16

            "CADRE JURIDIQUE".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 24

            let legalTexts: [(String, String)] = [
                ("Art. R.1334-31 Code Santé Publique", "Bruits de voisinage — émergence maximale 5 dB(A) jour / 3 dB(A) nuit"),
                ("Art. R.1336-5 Code Santé Publique", "Bruits portant atteinte à la tranquillité du voisinage"),
                ("Décret 2006-1099", "Lutte contre les bruits de voisinage"),
                ("Directive 2002/49/CE", "Évaluation et gestion du bruit dans l'environnement")
            ]

            for legal in legalTexts {
                let legalRect = CGRect(x: margin, y: y, width: contentWidth, height: 36)
                cardBg.setFill()
                UIBezierPath(roundedRect: legalRect, cornerRadius: 6).fill()

                let refAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: accent]
                let descAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .regular), .foregroundColor: textSecondary]
                legal.0.draw(at: CGPoint(x: margin + 10, y: y + 4), withAttributes: refAttr)
                legal.1.draw(at: CGPoint(x: margin + 10, y: y + 19), withAttributes: descAttr)
                y += 40
            }

            y += 12

            let warningRect = CGRect(x: margin, y: y, width: contentWidth, height: 52)
            UIColor(red: 1, green: 0.6, blue: 0, alpha: 0.08).setFill()
            UIBezierPath(roundedRect: warningRect, cornerRadius: 8).fill()
            let wBorderPath = UIBezierPath(roundedRect: warningRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 8)
            UIColor(red: 1, green: 0.6, blue: 0, alpha: 0.25).setStroke()
            wBorderPath.lineWidth = 1
            wBorderPath.stroke()

            let wTitleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: UIColor(red: 1, green: 0.6, blue: 0, alpha: 1)]
            "⚠  MESURE INDICATIVE".draw(at: CGPoint(x: margin + 12, y: y + 6), withAttributes: wTitleAttr)
            let wTextAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: textWhite]
            let wText = "Mesure réalisée avec microphone de smartphone. Pour une preuve légalement opposable, un sonomètre certifié COFRAC classe 1 ou 2 (IEC 61672) est requis."
            wText.draw(in: CGRect(x: margin + 12, y: y + 22, width: contentWidth - 24, height: 30), withAttributes: wTextAttr)

            y = warningRect.maxY + 16

            let sigRect = CGRect(x: margin, y: y, width: contentWidth, height: 60)
            cardBg.setFill()
            UIBezierPath(roundedRect: sigRect, cornerRadius: 8).fill()

            let sigLabelAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .regular), .foregroundColor: textSecondary]
            "Signature / Observations :".draw(at: CGPoint(x: margin + 12, y: y + 8), withAttributes: sigLabelAttr)
            let sigLine = UIBezierPath()
            sigLine.move(to: CGPoint(x: margin + 60, y: y + 40))
            sigLine.addLine(to: CGPoint(x: margin + contentWidth - 20, y: y + 40))
            UIColor.white.withAlphaComponent(0.1).setStroke()
            sigLine.lineWidth = 0.5
            sigLine.stroke()

            let footerFont = UIFont.systemFont(ofSize: 7, weight: .medium)
            let footerAttr: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: textSecondary]
            let refId = "Réf. litige : LIT-\(session.id.uuidString.prefix(8).uppercased())"
            let refSize = refId.size(withAttributes: footerAttr)
            refId.draw(at: CGPoint(x: (pageRect.width - refSize.width) / 2, y: pageRect.height - 48), withAttributes: footerAttr)

            let footerText = "Généré par DecibelPro — Document de constat horodaté"
            let footerSize = footerText.size(withAttributes: footerAttr)
            footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 36), withAttributes: footerAttr)
        }

        let hash = computeSHA256(of: pdfData)

        let finalRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return finalRenderer.pdfData { context in
            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            var y: CGFloat = 40

            let stampFont = UIFont.systemFont(ofSize: 10, weight: .bold)
            let stampAttr: [NSAttributedString.Key: Any] = [.font: stampFont, .foregroundColor: redColor]
            "DOCUMENT DE CONSTAT — MODE LITIGE".draw(at: CGPoint(x: margin, y: y), withAttributes: stampAttr)
            y += 20

            let logoFont = UIFont.systemFont(ofSize: 28, weight: .heavy)
            let logoAttr: [NSAttributedString.Key: Any] = [.font: logoFont, .foregroundColor: accent]
            "DecibelPro".draw(at: CGPoint(x: margin, y: y), withAttributes: logoAttr)
            y += 40

            let hashFont = UIFont.systemFont(ofSize: 8, weight: .medium)
            let hashAttr: [NSAttributedString.Key: Any] = [.font: hashFont, .foregroundColor: accent]
            let hashBoxRect = CGRect(x: margin, y: y, width: contentWidth, height: 30)
            cardBg.setFill()
            UIBezierPath(roundedRect: hashBoxRect, cornerRadius: 6).fill()

            let labelFont = UIFont.systemFont(ofSize: 8, weight: .bold)
            let lAttr: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: accent]
            "SHA-256 :".draw(at: CGPoint(x: margin + 10, y: y + 9), withAttributes: lAttr)
            hash.draw(at: CGPoint(x: margin + 64, y: y + 9), withAttributes: hashAttr)

            y = hashBoxRect.maxY + 16

            let titleFont = UIFont.systemFont(ofSize: 11, weight: .bold)
            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textWhite]
            "Ce hash SHA-256 garantit l'intégrité du document.".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 18

            let explainFont = UIFont.systemFont(ofSize: 9, weight: .regular)
            let explainAttr: [NSAttributedString.Key: Any] = [.font: explainFont, .foregroundColor: textSecondary]
            let explanation = "Toute modification du contenu du rapport change le hash. Conservez la page 1 et cette page ensemble pour prouver que le document n'a pas été altéré."
            explanation.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 40), withAttributes: explainAttr)

            let footerFont = UIFont.systemFont(ofSize: 7, weight: .medium)
            let footerAttr: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: textSecondary]
            let footer = "DecibelPro — Page d'intégrité"
            let footerSize = footer.size(withAttributes: footerAttr)
            footer.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 36), withAttributes: footerAttr)
        }
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
