import SwiftUI

struct MeterView: View {
    let viewModel: MeterViewModel
    let audioService: AudioMeterService
    let calibrationService: CalibrationService
    let storeManager: StoreManager

    @State private var showSettings: Bool = false
    @State private var recordPulse: Bool = false

    var body: some View {
        GeometryReader { geo in
            let gaugeHeight = geo.size.height * 0.52

            ScrollView {
                VStack(spacing: 12) {
                    header

                    ArcGaugeView(
                        decibels: viewModel.currentDecibels,
                        isActive: viewModel.isRunning
                    )
                    .frame(height: gaugeHeight)
                    .padding(.horizontal, -8)

                    recordButton
                        .padding(.top, -4)

                    metricsGrid

                    if viewModel.isRunning {
                        doseCard
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    BarGraphView(level: viewModel.currentDecibels, isActive: viewModel.isRunning)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.isRunning ? "Barre de niveau \(String(format: "%.0f", viewModel.currentDecibels)) décibels" : "Barre de niveau, inactif")

                    NoiseZoneBadge(zone: viewModel.currentZone, isActive: viewModel.isRunning)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.isRunning ? "Zone \(viewModel.currentZone.label)" : "Zone inactif")

                    LiveGraphView(
                        samples: viewModel.recentSamples,
                        maxValue: 130,
                        isActive: viewModel.isRunning
                    )

                    if viewModel.isRunning {
                        secondaryControls
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .sensoryFeedback(.warning, trigger: viewModel.thresholdTrigger)
        .task {
            await audioService.requestPermission()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isRunning)
        .overlay {
            if audioService.permissionDenied {
                permissionDeniedOverlay
            }
        }
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(audioService: audioService, storeManager: storeManager, calibrationService: calibrationService)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("DecibelPro")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 3) {
                        Text("CAL")
                            .font(.system(size: 9, weight: .bold))
                        if audioService.calibration != 0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .heavy))
                        }
                    }
                    .foregroundStyle(audioService.calibration != 0 ? .black : .white.opacity(0.4))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(audioService.calibration != 0 ? Color(red: 0.2, green: 0.78, blue: 0.35) : .white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 4))
                }

                if viewModel.isRunning {
                    sessionTimer
                }
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(.circle)
            }
        }
        .padding(.top, 4)
    }

    private var sessionTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let elapsed = Int(viewModel.activeElapsed)
            let m = elapsed / 60
            let s = elapsed % 60
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isPaused ? .orange : .red)
                    .frame(width: 6, height: 6)
                Text(String(format: "%02d:%02d", m, s))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var recordButton: some View {
        Group {
            if viewModel.isRunning {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.toggleRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(recordPulse ? 0.25 : 0.0))
                            .frame(width: 80, height: 80)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recordPulse)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 64, height: 64)
                            .shadow(color: .red.opacity(0.5), radius: 12)

                        Image(systemName: "stop.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.isRunning)
                .onAppear { recordPulse = true }
                .onDisappear { recordPulse = false }
            } else {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.toggleRecording()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Démarrer la mesure")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0, green: 1, blue: 0.53))
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: Color(red: 0, green: 1, blue: 0.53).opacity(0.3), radius: 16, y: 4)
                }
                .disabled(!audioService.hasPermission)
                .accessibilityLabel("Démarrer la mesure")
            }
        }
    }

    private var secondaryControls: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.resetPeak()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.ultraThinMaterial.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 12))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.peakHold)

            Button {
                viewModel.togglePause()
            } label: {
                Label(
                    viewModel.isPaused ? "Reprendre" : "Pause",
                    systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 14, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.white.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var doseCard: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Dose d'exposition")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(viewModel.recommendedMaxTime)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(viewModel.dosePercentNiosh > 100 ? .red : viewModel.dosePercentNiosh > 50 ? .orange : Color(red: 0, green: 1, blue: 0.53))
            }

            GeometryReader { geo in
                let width = geo.size.width
                let nioshPct = min(viewModel.dosePercentNiosh / 100.0, 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0, green: 1, blue: 0.53), .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, width * nioshPct), height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: nioshPct)
                }
            }
            .frame(height: 8)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NIOSH 85 dB/8h")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", viewModel.dosePercentNiosh))
                        .font(.system(size: 18, weight: .heavy).monospacedDigit())
                        .foregroundStyle(viewModel.dosePercentNiosh > 100 ? .red : .white)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("OSHA 90 dB/8h")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", viewModel.dosePercentOsha))
                        .font(.system(size: 18, weight: .heavy).monospacedDigit())
                        .foregroundStyle(viewModel.dosePercentOsha > 100 ? .red : .white)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Temps restant")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.recommendedMaxTime)
                        .font(.system(size: 18, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dose d'exposition NIOSH \(String(format: "%.0f", viewModel.dosePercentNiosh)) pourcent, OSHA \(String(format: "%.0f", viewModel.dosePercentOsha)) pourcent, temps restant \(viewModel.recommendedMaxTime)")
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            MetricCard(
                label: "Leq",
                value: viewModel.isRunning && viewModel.leq > 0 ? String(format: "%.1f", viewModel.leq) : "—",
                unit: "dB(A)",
                icon: "equal.circle.fill",
                color: Color(red: 0, green: 1, blue: 0.53)
            )
            MetricCard(
                label: "Lmax",
                value: viewModel.isRunning && viewModel.maxDecibels > -Double.infinity ? String(format: "%.1f", viewModel.maxDecibels) : "—",
                unit: "dB",
                icon: "arrow.up.circle.fill",
                color: Color.orange
            )
            MetricCard(
                label: "Lmin",
                value: viewModel.isRunning && viewModel.minDecibels < Double.infinity ? String(format: "%.1f", viewModel.minDecibels) : "—",
                unit: "dB",
                icon: "arrow.down.circle.fill",
                color: Color(red: 0.2, green: 0.78, blue: 0.35)
            )
            MetricCard(
                label: "Peak",
                value: viewModel.isRunning && viewModel.peakHold > 0 ? String(format: "%.1f", viewModel.peakHold) : "—",
                unit: "dB",
                icon: "waveform.badge.exclamationmark",
                color: Color(red: 1, green: 0.25, blue: 0.25)
            )
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var permissionDeniedOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red.opacity(0.8))
            }

            Text("Accès au microphone requis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("DecibelPro a besoin du microphone pour mesurer le niveau sonore.\nActivez l'accès dans les Réglages de votre iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Ouvrir les Réglages")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: 280)
                .frame(height: 50)
                .background(Color(red: 0, green: 1, blue: 0.53))
                .clipShape(.rect(cornerRadius: 14))
            }

            Button {
                Task { await audioService.requestPermission() }
            } label: {
                Text("Vérifier à nouveau")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.97))
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .font(.system(size: 28, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }
}
