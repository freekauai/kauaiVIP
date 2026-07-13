// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — App Entry Point                  ║
// ║           KauaiVIP2026App.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Weather: Open-Meteo (free, no API key, no entitlement needed)
// Bridge:  NOAA Tides & Currents (free, no key)
// Maps:    Apple MapKit (built-in)
// Auth:    LocalAuthentication (built-in, no capability needed)
//
// Minimum Deployment: iOS 16.0
// No special capabilities required.

import SwiftUI

@main
struct KauaiVIP2026App: App {
    @StateObject private var store          = TimesheetStore()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var bridgeService  = BridgeService()
    @StateObject private var authManager    = BiometricAuthManager()

    /// Persisted theme preference — "blueLight" (default, the released look) |
    /// "blueDark" | "light" | "dark" | "system".
    /// Written by SettingsView; applied below via .preferredColorScheme().
    /// Default must match SettingsView's, or the picker shows the wrong selection.
    @AppStorage("appTheme") private var appTheme: String = "blueLight"

    /// Whether biometric lock is enabled (mirrors SettingsView toggle).
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool = false

    @Environment(\.scenePhase) private var scenePhase

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "dark", "blueDark":   return .dark
        case "light", "blueLight": return .light
        default:                   return nil   // nil → follow the device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()   // SUV splash, then the app
                .environmentObject(store)
                .environmentObject(weatherManager)
                .environmentObject(bridgeService)
                .environmentObject(authManager)
                .preferredColorScheme(preferredColorScheme)
                // Rebuild the tree when the theme changes so the palette-driven
                // (static) AppTheme colors re-resolve — needed when switching
                // between two themes of the same light/dark scheme.
                .id(appTheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background where requireBiometrics:
                authManager.lockApp()   // re-opening requires re-authentication
            case .active:
                // Refresh stale data on return from background;
                // both services self-throttle (min 30 s between fetches).
                weatherManager.refresh()
                bridgeService.refresh()
            default:
                break
            }
        }
    }
}
