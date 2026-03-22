import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioService = AudioMeterService()
    @State private var meterViewModel: MeterViewModel?
    @State private var storeManager = StoreManager()
    @State private var reportViewModel = ReportViewModel()
    @State private var calibrationService = CalibrationService()
    @State private var selectedTab: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Sonomètre", systemImage: "waveform", value: 0) {
                if let vm = meterViewModel {
                    MeterView(viewModel: vm, audioService: audioService, calibrationService: calibrationService, storeManager: storeManager)
                }
            }

            Tab("Historique", systemImage: "chart.bar.fill", value: 1) {
                HistoryView(storeManager: storeManager)
            }

            Tab("Rapports", systemImage: "doc.text.fill", value: 2) {
                ReportsView(storeManager: storeManager, reportViewModel: reportViewModel)
            }

            Tab("Réglages", systemImage: "gearshape.fill", value: 3) {
                SettingsView(audioService: audioService, storeManager: storeManager, calibrationService: calibrationService)
            }
        }
        .tint(Color(red: 0, green: 1, blue: 0.53))
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .preferredColorScheme(.dark)
        .onAppear {
            setupAppearance()
            if meterViewModel == nil {
                let vm = MeterViewModel(audioService: audioService)
                vm.setModelContext(modelContext)
                meterViewModel = vm
            }
            reportViewModel.setModelContext(modelContext)
            reportViewModel.isPro = storeManager.isProUnlocked || storeManager.isPDFExportUnlocked
            calibrationService.loadPresets()
            audioService.calibration = UserDefaults.standard.double(forKey: "calibrationOffset")
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                reportViewModel.isPro = storeManager.isProUnlocked || storeManager.isPDFExportUnlocked
                reportViewModel.fetchSessions()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard let vm = meterViewModel else { return }
            switch newPhase {
            case .background:
                if vm.isRunning {
                    vm.enterBackground()
                }
            case .active:
                if vm.isRunning {
                    vm.enterForeground()
                }
            default:
                break
            }
        }
    }

    private func setupAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}
