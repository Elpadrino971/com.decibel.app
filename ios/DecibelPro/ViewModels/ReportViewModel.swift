import SwiftUI
import SwiftData

@Observable
@MainActor
final class ReportViewModel {
    var sessions: [MeasurementSession] = []
    var selectedFormat: ExportFormat = .pdf
    var isExporting: Bool = false
    var exportedURL: URL?
    var showShareSheet: Bool = false
    var errorMessage: String?

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchSessions()
    }

    func fetchSessions() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<MeasurementSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        sessions = (try? modelContext.fetch(descriptor)) ?? []
    }

    var isPro: Bool = false

    func exportSession(_ session: MeasurementSession, format: ExportFormat) {
        isExporting = true
        defer { isExporting = false }

        let fileName = "DecibelPro_\(session.startDate.formatted(.dateTime.year().month().day()))_\(session.id.uuidString.prefix(6))"

        switch format {
        case .pdf:
            let data = PDFExportService.generateReport(for: session, isPro: isPro)
            let url = URL.temporaryDirectory.appending(path: "\(fileName).pdf")
            do {
                try data.write(to: url)
                exportedURL = url
                showShareSheet = true
            } catch {
                errorMessage = "Erreur lors de l'export PDF"
            }

        case .csv:
            let csv = generateCSV(for: session)
            let url = URL.temporaryDirectory.appending(path: "\(fileName).csv")
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                exportedURL = url
                showShareSheet = true
            } catch {
                errorMessage = "Erreur lors de l'export CSV"
            }
        }
    }

    func exportAllSessions() {
        guard !sessions.isEmpty else { return }
        isExporting = true
        defer { isExporting = false }

        var csv = "Date;Durée;Min (dB);Moy (dB);Max (dB);Échantillons;Zone\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "fr_FR")

        for session in sessions {
            let zone = NoiseZone.zone(for: session.avgDecibels)
            let minVal = session.minDecibels > 900 ? 0 : session.minDecibels
            csv += "\(dateFormatter.string(from: session.startDate));\(session.formattedDuration);\(String(format: "%.1f", minVal));\(String(format: "%.1f", session.avgDecibels));\(String(format: "%.1f", session.maxDecibels));\(session.sampleCount);\(zone.label)\n"
        }

        let url = URL.temporaryDirectory.appending(path: "DecibelPro_AllSessions.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportedURL = url
            showShareSheet = true
        } catch {
            errorMessage = "Erreur lors de l'export"
        }
    }

    private func generateCSV(for session: MeasurementSession) -> String {
        var csv = "Index;Temps (s);Valeur (dB);Zone\n"

        let interval = session.duration / Double(max(session.samples.count, 1))

        for (i, sample) in session.samples.enumerated() {
            let time = Double(i) * interval
            let zone = NoiseZone.zone(for: sample)
            csv += "\(i);\(String(format: "%.1f", time));\(String(format: "%.1f", sample));\(zone.label)\n"
        }

        return csv
    }
}
