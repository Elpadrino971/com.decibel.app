import SwiftUI
import Charts
import CoreLocation

struct SessionDetailView: View {
    @Bindable var session: MeasurementSession
    let storeManager: StoreManager
    @State private var showShareSheet: Bool = false
    @State private var pdfURL: URL?
    @State private var showPaywall: Bool = false
    @State private var isEditingNote: Bool = false
    @State private var isEditingLocation: Bool = false
    @State private var showNoiseScoreShare: Bool = false
    @State private var noiseScoreImage: UIImage?
    @State private var showLitigeSheet: Bool = false
    @State private var litigeService = LitigeService()
    @State private var isGeneratingLitige: Bool = false
    @State private var litigePDFURL: URL?
    @State private var showLitigeShareSheet: Bool = false

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    private var dateString: String {
        session.startDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
    }

    private var zone: NoiseZone {
        NoiseZone.zone(for: session.avgDecibels)
    }

    private var presetIcon: String {
        switch session.calibrationPreset {
        case "Chantier BTP": "hammer.fill"
        case "Concert / Event": "music.mic"
        case "Nuisance Voisinage": "house.fill"
        case "Personnalisé": "slider.horizontal.3"
        default: "iphone"
        }
    }

    private var chartData: [ChartSample] {
        let interval = session.duration / Double(max(session.samples.count, 1))
        return session.samples.enumerated().map { index, value in
            ChartSample(time: Double(index) * interval, value: value)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                metricsSection
                if !session.samples.isEmpty {
                    chartSection
                }
                zoneCard
                calibrationCard
                notesSection
                actionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .navigationTitle("Détails")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(storeManager: storeManager)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showNoiseScoreShare) {
            if let image = noiseScoreImage {
                ShareSheet(activityItems: [image])
            }
        }
        .sheet(isPresented: $showLitigeSheet) {
            litigeSheetContent
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLitigeShareSheet) {
            if let url = litigePDFURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(zone.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: zone.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(zone.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(dateString)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Label(session.formattedDuration, systemImage: "clock")
                        Text("·")
                        Text("\(session.sampleCount) pts")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                Text(String(format: "%.1f", session.avgDecibels))
                    .font(.system(size: 48, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(zone.color)
                Text(" dB")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(zone.color.opacity(0.6))
                    .offset(y: 8)
            }
            .frame(maxWidth: .infinity)

            Text(zone.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(zone.color.opacity(0.8))
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var metricsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                DetailMetricCard(
                    label: "Leq",
                    value: String(format: "%.1f", session.leq),
                    unit: "dB(A)",
                    icon: "equal.circle.fill",
                    color: accentGreen
                )
                DetailMetricCard(
                    label: "Peak",
                    value: String(format: "%.1f", session.peakHold),
                    unit: "dB",
                    icon: "waveform.badge.exclamationmark",
                    color: Color(red: 1, green: 0.25, blue: 0.25)
                )
            }
            HStack(spacing: 8) {
                DetailMetricCard(
                    label: "Minimum",
                    value: String(format: "%.1f", session.minDecibels > 900 ? 0 : session.minDecibels),
                    unit: "dB",
                    icon: "arrow.down.circle.fill",
                    color: Color(red: 0, green: 0.8, blue: 0.4)
                )
                DetailMetricCard(
                    label: "Maximum",
                    value: String(format: "%.1f", session.maxDecibels),
                    unit: "dB",
                    icon: "arrow.up.circle.fill",
                    color: Color(red: 1, green: 0.4, blue: 0)
                )
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(accentGreen)
                Text("Courbe de mesure")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(session.samples.count) échantillons")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart(chartData) { sample in
                AreaMark(
                    x: .value("Temps", sample.time),
                    y: .value("dB", sample.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentGreen.opacity(0.3), accentGreen.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Temps", sample.time),
                    y: .value("dB", sample.value)
                )
                .foregroundStyle(accentGreen)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(formatTime(seconds))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel {
                        if let db = value.as(Double.self) {
                            Text(String(format: "%.0f", db))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: max(0, (session.minDecibels > 900 ? 0 : session.minDecibels) - 5)...min(130, session.maxDecibels + 5))
            .frame(height: 200)

            if session.samples.count > 10 {
                HStack(spacing: 16) {
                    chartLegendItem(color: Color(red: 0, green: 0.8, blue: 0.4), label: "Min \(String(format: "%.0f", session.minDecibels > 900 ? 0 : session.minDecibels))")
                    chartLegendItem(color: accentGreen, label: "Moy \(String(format: "%.0f", session.avgDecibels))")
                    chartLegendItem(color: Color(red: 1, green: 0.4, blue: 0), label: "Max \(String(format: "%.0f", session.maxDecibels))")
                }
                .frame(maxWidth: .infinity)
                .font(.caption2)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func chartLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private var zoneCard: some View {
        HStack(spacing: 12) {
            Image(systemName: zone.icon)
                .font(.title2)
                .foregroundStyle(zone.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Zone moyenne : \(zone.label)")
                    .font(.subheadline.weight(.semibold))
                Text(zone.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var calibrationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: presetIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentGreen)
                .frame(width: 32, height: 32)
                .background(accentGreen.opacity(0.12))
                .clipShape(.circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Calibration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(session.calibrationPreset)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var notesSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(accentGreen)
                    .frame(width: 20)
                if isEditingLocation {
                    TextField("Lieu de mesure", text: Binding(
                        get: { session.location ?? "" },
                        set: { session.location = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit { isEditingLocation = false }
                } else {
                    Button {
                        isEditingLocation = true
                    } label: {
                        Text(session.location?.isEmpty == false ? session.location! : "Ajouter un lieu…")
                            .font(.subheadline)
                            .foregroundStyle(session.location?.isEmpty == false ? .white : .secondary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(.rect(cornerRadius: 10))

            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .foregroundStyle(accentGreen)
                    .frame(width: 20)
                if isEditingNote {
                    TextField("Annotation", text: Binding(
                        get: { session.note ?? "" },
                        set: { session.note = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit { isEditingNote = false }
                } else {
                    Button {
                        isEditingNote = true
                    } label: {
                        Text(session.note?.isEmpty == false ? session.note! : "Ajouter une note…")
                            .font(.subheadline)
                            .foregroundStyle(session.note?.isEmpty == false ? .white : .secondary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                shareNoiseScore()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Partager Noise Score")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(accentGreen)
                .clipShape(.rect(cornerRadius: 12))
            }

            Button {
                showLitigeSheet = true
                litigeService.requestLocation()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Mode Litige")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(red: 1, green: 0.25, blue: 0.25).opacity(0.15))
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 1, green: 0.25, blue: 0.25).opacity(0.3), lineWidth: 1)
                }
            }

            Button {
                if storeManager.isPDFExportUnlocked || storeManager.isProUnlocked {
                    exportPDF()
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 16, weight: .semibold))
                    Text(storeManager.isPDFExportUnlocked || storeManager.isProUnlocked ? "Rapport PDF" : "Rapport PDF (Pro)")
                        .font(.headline)
                    if !(storeManager.isPDFExportUnlocked || storeManager.isProUnlocked) {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var litigeSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(red: 1, green: 0.25, blue: 0.25))
                        Text("Mode Litige")
                            .font(.title2.weight(.bold))
                        Text("Générez un constat horodaté avec coordonnées GPS et hash SHA-256 pour preuve d'intégrité.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        litigeInfoRow(icon: "location.fill", title: "Position GPS", value: litigeService.isLocating ? "Localisation…" : (litigeService.currentAddress ?? litigeService.currentLocation.map { String(format: "%.4f, %.4f", $0.coordinate.latitude, $0.coordinate.longitude) } ?? "En attente"), color: .blue)
                        litigeInfoRow(icon: "clock.fill", title: "Horodatage", value: session.startDate.formatted(.dateTime.day().month().year().hour().minute().second()), color: accentGreen)
                        litigeInfoRow(icon: "waveform", title: "Leq mesuré", value: String(format: "%.1f dB(A)", session.leq), color: NoiseZone.zone(for: session.leq).color)
                        litigeInfoRow(icon: "lock.shield.fill", title: "Intégrité", value: "Hash SHA-256 inclus", color: .orange)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Cadre juridique")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        Text("Art. R.1334-31 Code Santé Publique\nDécret 2006-1099 — Bruits de voisinage")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.orange.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 10))

                    Button {
                        generateLitigePDF()
                    } label: {
                        HStack(spacing: 10) {
                            if isGeneratingLitige {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "doc.badge.gearshape")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text("Générer le constat PDF")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accentGreen)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .disabled(isGeneratingLitige)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showLitigeSheet = false }
                }
            }
        }
    }

    private func litigeInfoRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
    }

    private func shareNoiseScore() {
        if let image = NoiseScoreCardService.generateCard(for: session) {
            noiseScoreImage = image
            showNoiseScoreShare = true
        }
    }

    private func generateLitigePDF() {
        isGeneratingLitige = true
        let data = LitigeService.generateLitigePDF(
            for: session,
            location: litigeService.currentLocation,
            address: litigeService.currentAddress
        )
        let url = URL.temporaryDirectory.appending(path: "DecibelPro_Litige_\(session.id.uuidString.prefix(8)).pdf")
        try? data.write(to: url)
        litigePDFURL = url
        isGeneratingLitige = false
        showLitigeSheet = false
        showLitigeShareSheet = true
    }

    private func exportPDF() {
        let isPro = storeManager.isPDFExportUnlocked || storeManager.isProUnlocked
        let data = PDFExportService.generateReport(for: session, isPro: isPro)
        let url = URL.temporaryDirectory.appending(path: "DecibelPro_Report_\(session.id.uuidString.prefix(8)).pdf")
        try? data.write(to: url)
        pdfURL = url
        showShareSheet = true
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m > 0 {
            return "\(m)m\(String(format: "%02d", s))s"
        }
        return "\(s)s"
    }
}

nonisolated struct ChartSample: Identifiable, Sendable {
    let id = UUID()
    let time: Double
    let value: Double
}

struct DetailMetricCard: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color.opacity(0.8))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color.opacity(0.7))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
