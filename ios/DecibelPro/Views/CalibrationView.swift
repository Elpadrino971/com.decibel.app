import SwiftUI

struct CalibrationView: View {
    let calibrationService: CalibrationService
    let audioService: AudioMeterService
    let storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var customOffset: Double
    @State private var hapticTrigger: Int = 0
    @State private var showPaywall: Bool = false

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    init(calibrationService: CalibrationService, audioService: AudioMeterService, storeManager: StoreManager) {
        self.calibrationService = calibrationService
        self.audioService = audioService
        self.storeManager = storeManager
        _customOffset = State(initialValue: calibrationService.currentOffset)
    }

    var body: some View {
        NavigationStack {
            List {
                presetsSection
                manualSection
                testToneSection
                activeCalibrationSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(accentGreen)
                }
            }
            .sensoryFeedback(.selection, trigger: hapticTrigger)
            .sheet(isPresented: $showPaywall) {
                PaywallView(storeManager: storeManager)
            }
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        Section {
            ForEach(calibrationService.presets.filter { $0.id != "custom" }) { preset in
                let isStandard = preset.id == "iphone_standard"
                let isLocked = !isStandard && !storeManager.isFeatureUnlocked(.advancedCalibration)

                Button {
                    if isLocked {
                        showPaywall = true
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            calibrationService.applyPreset(preset)
                            audioService.calibration = preset.offset
                            customOffset = preset.offset
                            hapticTrigger += 1
                        }
                    }
                } label: {
                    presetRow(preset, isLocked: isLocked)
                }
            }
        } header: {
            Label("Presets professionnels", systemImage: "tuningfork")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        } footer: {
            Text("Sélectionnez un preset adapté à votre environnement de mesure.")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    private func presetRow(_ preset: CalibrationPreset, isLocked: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: preset.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(calibrationService.activePresetId == preset.id ? accentGreen : .secondary)
                .frame(width: 34, height: 34)
                .background(
                    (calibrationService.activePresetId == preset.id ? accentGreen : Color.white)
                        .opacity(calibrationService.activePresetId == preset.id ? 0.15 : 0.06)
                )
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(preset.referenceNorm)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 4))
                }
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%+.1f", preset.offset))
                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(calibrationService.activePresetId == preset.id ? accentGreen : .white.opacity(0.5))
                Text("dB")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.2))
            } else if calibrationService.activePresetId == preset.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(accentGreen)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .contentShape(.rect)
        .opacity(isLocked ? 0.5 : 1)
    }

    // MARK: - Manual

    private var manualSection: some View {
        let isLocked = !storeManager.isFeatureUnlocked(.advancedCalibration)

        return Section {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(calibrationService.activePresetId == "custom" ? accentGreen : .secondary)
                        Text("Offset manuel")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text(String(format: "%+.1f dB", customOffset))
                        .font(.system(.title3, weight: .heavy).monospacedDigit())
                        .foregroundStyle(calibrationService.activePresetId == "custom" ? accentGreen : .white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: customOffset)
                }

                Slider(value: $customOffset, in: -20...20, step: 0.5)
                    .tint(accentGreen)
                    .disabled(isLocked)
                    .onChange(of: customOffset) { _, newValue in
                        if isLocked {
                            showPaywall = true
                            return
                        }
                        calibrationService.setCustomOffset(newValue)
                        audioService.calibration = newValue
                        hapticTrigger += 1
                    }

                HStack {
                    Text("-20 dB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("0")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                    Text("+20 dB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if calibrationService.activePresetId == "custom" {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(accentGreen)
                        Text("Mode personnalisé actif")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accentGreen.opacity(0.8))
                    }
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Calibration manuelle", systemImage: "dial.low.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        } footer: {
            Text("Ajustez finement l'offset par pas de 0,5 dB. Comparez avec un sonomètre de référence pour une calibration optimale.")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    // MARK: - Test Tone

    private var testToneSection: some View {
        Section {
            Button {
                calibrationService.toggleTestTone()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: calibrationService.isPlayingTestTone ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(calibrationService.isPlayingTestTone ? .orange : accentGreen)
                        .symbolEffect(.variableColor.iterative, isActive: calibrationService.isPlayingTestTone)
                        .frame(width: 34, height: 34)
                        .background(
                            (calibrationService.isPlayingTestTone ? Color.orange : accentGreen).opacity(0.15)
                        )
                        .clipShape(.rect(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(calibrationService.isPlayingTestTone ? "Tonalité en cours…" : "Signal de référence 94 dB")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Sinus 1 kHz · 5 secondes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if calibrationService.isPlayingTestTone {
                        ProgressView()
                            .tint(.orange)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(accentGreen)
                    }
                }
                .contentShape(.rect)
            }
        } header: {
            Label("Signal de test", systemImage: "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        } footer: {
            Text("Émettez un signal sinusoïdal de référence pour comparer avec un sonomètre calibré. Ajustez ensuite l'offset jusqu'à lire 94 dB.")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    // MARK: - Active Calibration Summary

    private var activeCalibrationSection: some View {
        Section {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calibration active")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let active = calibrationService.presets.first(where: { $0.id == calibrationService.activePresetId }) {
                        Text(active.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text("Personnalisé")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Offset appliqué")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%+.1f dB", calibrationService.currentOffset))
                        .font(.system(.title3, weight: .heavy).monospacedDigit())
                        .foregroundStyle(accentGreen)
                }
            }
            .padding(.vertical, 4)

            Button("Réinitialiser à zéro", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    calibrationService.reset()
                    audioService.calibration = 0
                    customOffset = 0
                    hapticTrigger += 1
                }
            }
            .font(.subheadline)
        } header: {
            Label("Résumé", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .listRowBackground(Color.white.opacity(0.04))
    }
}
