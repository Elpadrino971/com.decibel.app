import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeasurementSession.startDate, order: .reverse) private var sessions: [MeasurementSession]
    let storeManager: StoreManager
    @Bindable var reportViewModel: ReportViewModel

    @State private var selectedSession: MeasurementSession?
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var showPaywall: Bool = false

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    reportContent
                }
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            .navigationTitle("Rapports")
            .sheet(isPresented: $showPaywall) {
                PaywallView(storeManager: storeManager)
            }
            .sheet(isPresented: $reportViewModel.showShareSheet) {
                if let url = reportViewModel.exportedURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Aucun rapport",
            systemImage: "doc.text.fill",
            description: Text("Enregistrez des sessions pour générer des rapports d'analyse.")
        )
    }

    private var reportContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                formatPicker
                sessionExportList
                exportAllButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accentGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Synthèse globale")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(sessions.count) session\(sessions.count > 1 ? "s" : "") enregistrée\(sessions.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                SummaryStatCard(
                    label: "Min global",
                    value: String(format: "%.0f", globalMin),
                    unit: "dB",
                    color: Color(red: 0, green: 0.8, blue: 0.4)
                )
                SummaryStatCard(
                    label: "Moy globale",
                    value: String(format: "%.0f", globalAvg),
                    unit: "dB",
                    color: accentGreen
                )
                SummaryStatCard(
                    label: "Max global",
                    value: String(format: "%.0f", globalMax),
                    unit: "dB",
                    color: Color(red: 1, green: 0.4, blue: 0)
                )
            }

            HStack(spacing: 8) {
                Image(systemName: NoiseZone.zone(for: globalAvg).icon)
                    .foregroundStyle(NoiseZone.zone(for: globalAvg).color)
                Text("Zone moyenne : \(NoiseZone.zone(for: globalAvg).label)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                Text(totalDurationFormatted)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var formatPicker: some View {
        HStack(spacing: 0) {
            ForEach(ExportFormat.allCases) { format in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedFormat = format
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: format.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(format.label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(selectedFormat == format ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedFormat == format ? accentGreen : Color.clear)
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var sessionExportList: some View {
        VStack(spacing: 2) {
            HStack {
                Text("Sessions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Exporter individuellement")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)

            ForEach(sessions) { session in
                ReportSessionRow(
                    session: session,
                    format: selectedFormat,
                    accentGreen: accentGreen,
                    isLocked: !hasExportAccess
                ) {
                    if hasExportAccess {
                        reportViewModel.exportSession(session, format: selectedFormat)
                    } else {
                        showPaywall = true
                    }
                }
            }
        }
    }

    private var exportAllButton: some View {
        Button {
            if hasExportAccess {
                reportViewModel.exportAllSessions()
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.on.square.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Exporter tout en CSV")
                    .font(.headline)
                if !hasExportAccess {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(accentGreen)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var hasExportAccess: Bool {
        storeManager.isProUnlocked || storeManager.isPDFExportUnlocked
    }

    private var globalMin: Double {
        let mins = sessions.map { $0.minDecibels }.filter { $0 < 900 }
        return mins.min() ?? 0
    }

    private var globalMax: Double {
        sessions.map(\.maxDecibels).max() ?? 0
    }

    private var globalAvg: Double {
        guard !sessions.isEmpty else { return 0 }
        let energySum = sessions.reduce(0.0) { $0 + pow(10.0, $1.avgDecibels / 10.0) }
        return 10.0 * log10(energySum / Double(sessions.count))
    }

    private var totalDurationFormatted: String {
        let total = sessions.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        }
        return "\(minutes) min"
    }
}

struct ReportSessionRow: View {
    let session: MeasurementSession
    let format: ExportFormat
    let accentGreen: Color
    let isLocked: Bool
    let onExport: () -> Void

    private var dateString: String {
        session.startDate.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(NoiseZone.zone(for: session.avgDecibels).color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoiseZone.zone(for: session.avgDecibels).color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dateString)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(session.formattedDuration)
                    Text("•")
                    Text(String(format: "%.0f dB moy", session.avgDecibels))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onExport) {
                HStack(spacing: 4) {
                    Image(systemName: format.icon)
                        .font(.system(size: 12, weight: .semibold))
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(isLocked ? .secondary : accentGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isLocked ? Color.white.opacity(0.04) : accentGreen.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.vertical, 1)
    }
}

struct SummaryStatCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 8))
    }
}
