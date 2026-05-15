// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Root Router                      ║
// ║           ContentView.swift                                  ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct ContentView: View {
    @State private var activeModal:    AppModal? = nil
    @State private var setupName:      String    = ""   // local binding for setup form

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

    private var setupComplete: Bool {
        !store.driverName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.oceanDeep.ignoresSafeArea()

            if setupComplete {
                MainView(activeModal: $activeModal)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                DriverNameSetupView(driverName: $setupName, onComplete: { name in
                    store.saveDriverName(name)
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: setupComplete)
        .alert("Save Failed", isPresented: Binding(
            get: { store.lastSaveError != nil },
            set: { if !$0 { store.lastSaveError = nil } }
        )) {
            Button("OK", role: .cancel) { store.lastSaveError = nil }
        } message: {
            Text(store.lastSaveError ?? "")
        }
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
