import SwiftUI

struct SettingsView: View {
    let audioService: AudioMeterService
    let storeManager: StoreManager
    let calibrationService: CalibrationService
    @State private var alertThreshold: Double = {
        let val = UserDefaults.standard.double(forKey: "alertThreshold")
        return val.isZero ? 85 : val
    }()
    @State private var alertEnabled: Bool = UserDefaults.standard.bool(forKey: "alertEnabled")
    @State private var showPaywall: Bool = false
    @State private var showCalibration: Bool = false

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    var body: some View {
        NavigationStack {
            List {
                calibrationSection
                alertSection
                purchaseSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
            .navigationTitle("Réglages")
            .sheet(isPresented: $showPaywall) {
                PaywallView(storeManager: storeManager)
            }
            .sheet(isPresented: $showCalibration) {
                CalibrationView(calibrationService: calibrationService, audioService: audioService, storeManager: storeManager)
            }
        }
    }

    private var calibrationSection: some View {
        Section {
            Button {
                showCalibration = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentGreen)
                        .frame(width: 34, height: 34)
                        .background(accentGreen.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Calibration du microphone")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        HStack(spacing: 6) {
                            if let preset = CalibrationService.professionalPresets.first(where: { $0.id == calibrationService.activePresetId }) {
                                Text(preset.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.1f dB", calibrationService.currentOffset))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(accentGreen)
                        }
                    }

                    Spacer()

                    if calibrationService.currentOffset != 0 {
                        Text("CAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accentGreen)
                            .clipShape(.rect(cornerRadius: 4))
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
        } header: {
            Text("Calibration")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    private var alertSection: some View {
        Section {
            Toggle(isOn: $alertEnabled) {
                Label("Alerte de seuil", systemImage: "bell.badge.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(accentGreen)
            .onChange(of: alertEnabled) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "alertEnabled")
            }

            if alertEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Seuil d'alerte")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(alertThreshold)) dB")
                            .font(.system(.subheadline, weight: .heavy).monospacedDigit())
                            .foregroundStyle(NoiseZone.zone(for: alertThreshold).color)
                    }

                    Slider(value: $alertThreshold, in: 50...120, step: 1)
                        .tint(NoiseZone.zone(for: alertThreshold).color)
                        .onChange(of: alertThreshold) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "alertThreshold")
                        }

                    Text("Zone : \(NoiseZone.zone(for: alertThreshold).label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Recevez un retour haptique lorsque le niveau sonore dépasse le seuil configuré.")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    private var purchaseSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Label("Débloquer DecibelPro", systemImage: "star.fill")
                        .foregroundStyle(accentGreen)
                    Spacer()
                    if storeManager.isProUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accentGreen)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Label("Restaurer les achats", systemImage: "arrow.clockwise")
                    .foregroundStyle(.white)
            }
        } header: {
            Text("Achats")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Développeur")
                Spacer()
                Text("DecibelPro")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("À propos")
        }
        .listRowBackground(Color.white.opacity(0.04))
    }
}
