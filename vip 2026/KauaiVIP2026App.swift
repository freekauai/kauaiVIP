// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — App Entry Point                  ║
// ║           KauaiVIP2026App.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Weather: Open-Meteo (free, no API key, no entitlement needed)
// Bridge:  NOAA Tides & Currents (free, no key)
// Maps:    Apple MapKit (built-in)
//
// Minimum Deployment: iOS 16.0
// No special capabilities required.

import SwiftUI

@main
struct KauaiVIP2026App: App {
    @StateObject private var store          = TimesheetStore()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var bridgeService  = BridgeService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(weatherManager)
                .environmentObject(bridgeService)
        }
    }
}
