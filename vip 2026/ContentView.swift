// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Root Router                      ║
// ║           ContentView.swift                                  ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct ContentView: View {
    @AppStorage("kauai_vip_setup_complete") private var setupComplete = false
    @State private var activeModal: AppModal? = nil

    enum AppModal: Identifiable {
        case weather, map, traffic, stats
        var id: String {
            switch self {
            case .weather: return "weather"
            case .map:     return "map"
            case .traffic: return "traffic"
            case .stats:   return "stats"
            }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.oceanDeep.ignoresSafeArea()

            if setupComplete {
                MainView(activeModal: $activeModal)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                PasscodeView(setupComplete: $setupComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: setupComplete)
        .sheet(item: $activeModal) { modal in
            switch modal {
            case .weather: WeatherModalView()
                    .environmentObject(weatherManager)
                    .environmentObject(bridgeService)
            case .map:     KauaiMapView()
                    .environmentObject(bridgeService)
            case .traffic: TrafficModalView()
                    .environmentObject(bridgeService)
            case .stats:   StatsView()
                    .environmentObject(store)
            }
        }
    }

    // Needed to forward environment objects into sheets
    @EnvironmentObject private var store:          TimesheetStore
    @EnvironmentObject private var weatherManager: WeatherManager
    @EnvironmentObject private var bridgeService:  BridgeService
}
