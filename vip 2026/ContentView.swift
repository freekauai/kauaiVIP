// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Root Router                      ║
// ║           ContentView.swift                                  ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct ContentView: View {
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

    // Biometric auth
    @EnvironmentObject private var authManager: BiometricAuthManager
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool = false

    var body: some View {
        ZStack {
            // ── App content ───────────────────────────────────────
            if store.driverName.isEmpty {
                DriverNameSetupView()
            } else {
                ZStack {
                    AppTheme.oceanDeep.ignoresSafeArea()
                    MainView(activeModal: $activeModal)
                }
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

            // ── Lock screen overlay (honors the Settings toggle) ──
            if requireBiometrics && !authManager.isUnlocked {
                LockScreenView()
                    .environmentObject(authManager)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isUnlocked)
    }

    // Needed to forward environment objects into sheets
    @EnvironmentObject private var store:          TimesheetStore
    @EnvironmentObject private var weatherManager: WeatherManager
    @EnvironmentObject private var bridgeService:  BridgeService
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    @EnvironmentObject private var authManager: BiometricAuthManager

    var body: some View {
        ZStack {
            AppTheme.oceanDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Wordmark ──────────────────────────────────────
                VStack(spacing: 10) {
                    Text("🏝️")
                        .font(.system(size: 64))

                    Text("RUNSHEET")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .tracking(4)

                    Text("2026")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.coral)
                        .tracking(6)

                    Text("Driver Timesheet System")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)
                        .tracking(1)
                }

                Spacer()

                // ── Face ID / Touch ID icon + button ──────────────
                VStack(spacing: 20) {
                    Image(systemName: "faceid")
                        .font(.system(size: 52, weight: .light))
                        .foregroundColor(AppTheme.oceanLight)
                        .padding(20)
                        .background(
                            Circle()
                                .fill(AppTheme.oceanMedium)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                        )

                    Button(action: {
                        Task { await authManager.authenticate() }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Unlock")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppTheme.coral)
                        .cornerRadius(AppTheme.buttonRadius)
                    }
                    .padding(.horizontal, 48)

                    // Error message
                    if let errorMsg = authManager.authError {
                        Text(errorMsg)
                            .font(.system(size: AppTheme.footnote))
                            .foregroundColor(AppTheme.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                            .transition(.opacity)
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            // Auto-trigger Face ID without requiring a tap — after the splash
            // has faded, so the system sheet appears over the branded lock
            // screen instead of floating on the white SUV artwork.
            Task {
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                await authManager.authenticate()
            }
        }
    }
}

// MARK: - Splash Screen
/// Branded launch splash shown each time the app opens, then fades into the app.
struct SplashView: View {
    @State private var driveIn = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()   // the SUV artwork sits on white

            VStack(spacing: 0) {
                Spacer()

                // SUV drives in from the left and settles
                Image("RunSheetVehicle")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 24)
                    .offset(x: driveIn ? 0 : -120)
                    .opacity(driveIn ? 1 : 0)
                    .accessibilityLabel("RunSheet")

                // Wordmark + tagline (matches the in-app rounded-black style)
                VStack(spacing: 6) {
                    Text("RunSheet")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "0F2547"))
                    Text("Driver Timesheet System")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "7488A3"))
                        .tracking(1.5)
                }
                .padding(.top, 22)
                .opacity(driveIn ? 1 : 0)

                Spacer()
            }

            // Copyright pinned at the bottom edge
            VStack {
                Spacer()
                Text("© 2026 Joey Wray")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "7488A3"))
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.1)) {
                driveIn = true
            }
        }
    }
}

// MARK: - Root (splash → app)
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)   // ~1.8s
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
        }
    }
}
