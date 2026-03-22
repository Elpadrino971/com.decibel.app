import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeasurementSession.startDate, order: .reverse) private var sessions: [MeasurementSession]
    let storeManager: StoreManager

    @State private var searchText: String = ""
    @State private var sessionToDelete: MeasurementSession?
    @State private var showDeleteConfirmation: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var exportedPDFURL: URL?

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    private var filteredSessions: [MeasurementSession] {
        guard !searchText.isEmpty else { return Array(sessions) }
        let query = searchText.lowercased()
        return sessions.filter { session in
            if let loc = session.location, loc.localizedStandardContains(query) { return true }
            if let note = session.note, note.localizedStandardContains(query) { return true }
            if session.calibrationPreset.localizedStandardContains(query) { return true }
            let zone = NoiseZone.zone(for: session.avgDecibels)
            if zone.label.localizedStandardContains(query) { return true }
            return false
        }
    }

    private var groupedSessions: [(String, [MeasurementSession])] {
        let calendar = Calendar.current
        let now = Date()
        var groups: [String: [MeasurementSession]] = [:]
        let order = ["Aujourd'hui", "Hier", "Cette semaine", "Ce mois", "Plus ancien"]

        for session in filteredSessions {
            let key: String
            if calendar.isDateInToday(session.startDate) {
                key = "Aujourd'hui"
            } else if calendar.isDateInYesterday(session.startDate) {
                key = "Hier"
            } else if calendar.isDate(session.startDate, equalTo: now, toGranularity: .weekOfYear) {
                key = "Cette semaine"
            } else if calendar.isDate(session.startDate, equalTo: now, toGranularity: .month) {
                key = "Ce mois"
            } else {
                key = "Plus ancien"
            }
            groups[key, default: []].append(session)
        }

        return order.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    private var totalSessions: Int { sessions.count }

    private var globalLeq: Double {
        guard !sessions.isEmpty else { return 0 }
        let energySum = sessions.reduce(0.0) { $0 + pow(10.0, $1.avgDecibels / 10.0) }
        return 10.0 * log10(energySum / Double(sessions.count))
    }

    private var loudestSession: MeasurementSession? {
        sessions.max(by: { $0.maxDecibels < $1.maxDecibels })
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionContent
                }
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            .navigationTitle("Historique")
            .navigationDestination(for: MeasurementSession.self) { session in
                SessionDetailView(session: session, storeManager: storeManager)
            }
            .searchable(text: $searchText, prompt: "Rechercher par lieu, note, zone…")
            .sheet(isPresented: $showPaywall) {
                PaywallView(storeManager: storeManager)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedPDFURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Aucune mesure",
            systemImage: "waveform.path.ecg",
            description: Text("Démarrez une mesure pour enregistrer une session.")
        )
    }

    private var sessionContent: some View {
        List {
            statsHeader
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)

            ForEach(groupedSessions, id: \.0) { sectionTitle, sectionSessions in
                Section {
                    ForEach(sectionSessions) { session in
                        let sessionIndex = filteredSessions.firstIndex(where: { $0.id == session.id }) ?? 0
                        let isLocked = !storeManager.canAccessSession(at: sessionIndex)

                        if isLocked {
                            lockedSessionRow(session: session)
                                .listRowBackground(Color.white.opacity(0.02))
                        } else {
                            NavigationLink(value: session) {
                                SessionRowView(session: session)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSession(session)
                                } label: {
                                    Label("Supprimer", systemImage: "trash.fill")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    exportSessionPDF(session)
                                } label: {
                                    Label("PDF", systemImage: "doc.richtext")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    Text(sectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            if !storeManager.isProUnlocked && sessions.count > 5 {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accentGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(sessions.count - 5) sessions verrouillées")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Débloquez l'historique illimité")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accentGreen)
                        }
                    }
                    .listRowBackground(accentGreen.opacity(0.06))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var statsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatPill(
                    icon: "number",
                    label: "Sessions",
                    value: "\(totalSessions)",
                    color: accentGreen
                )
                StatPill(
                    icon: "equal.circle.fill",
                    label: "Leq moy",
                    value: String(format: "%.0f dB", globalLeq),
                    color: NoiseZone.zone(for: globalLeq).color
                )
            }

            if let loudest = loudestSession {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.4, blue: 0))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Session la plus bruyante")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.0f dB max", loudest.maxDecibels)) — \(loudest.startDate.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(String(format: "%.0f", loudest.maxDecibels))
                        .font(.system(size: 18, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Color(red: 1, green: 0.4, blue: 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 1, green: 0.4, blue: 0).opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteSession(_ session: MeasurementSession) {
        withAnimation {
            modelContext.delete(session)
            try? modelContext.save()
        }
    }

    private func lockedSessionRow(session: MeasurementSession) -> some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.2))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startDate.formatted(.dateTime.hour().minute()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(session.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.15))
                }

                Spacer()

                Text(String(format: "%.0f", session.avgDecibels))
                    .font(.system(size: 24, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.15))
            }
            .padding(.vertical, 4)
        }
    }

    private func exportSessionPDF(_ session: MeasurementSession) {
        let isPro = storeManager.isPDFExportUnlocked || storeManager.isProUnlocked
        let data = PDFExportService.generateReport(for: session, isPro: isPro)
        let url = URL.temporaryDirectory.appending(path: "DecibelPro_\(session.id.uuidString.prefix(8)).pdf")
        try? data.write(to: url)
        exportedPDFURL = url
        showShareSheet = true
    }
}

struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }
}

struct SessionRowView: View {
    let session: MeasurementSession

    private var timeString: String {
        session.startDate.formatted(.dateTime.hour().minute())
    }

    private var dateString: String {
        session.startDate.formatted(.dateTime.day().month(.abbreviated))
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

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(zone.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: zone.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(zone.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(timeString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(session.formattedDuration, systemImage: "clock")
                    Image(systemName: presetIcon)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let location = session.location, !location.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(location)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", session.avgDecibels))
                    .font(.system(size: 24, weight: .heavy).monospacedDigit())
                    .foregroundStyle(zone.color)
                Text("dB Leq")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
