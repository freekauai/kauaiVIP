// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Root Router                      ║
// ║           ContentView.swift                                  ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import AVFoundation   // splash engine sound

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
/// Branded launch splash: the SUV drives in from off-screen left (engine
/// sound, leaning into the acceleration), settles into an idle bob while the
/// wordmark and tagline stagger in, then drives off to the right as the app
/// is revealed. Calls `onFinished` when the app should be shown (~3s).
struct SplashView: View {
    var onFinished: () -> Void = {}

    @State private var driveIn  = false   // off-screen left → centered
    @State private var showWordmark = false
    @State private var showTagline  = false
    @State private var showCredit   = false
    @State private var idling   = false   // gentle engine-idle bob
    @State private var backUp   = false   // reverses out of the "spot" first
    @State private var driveOut = false   // …then pulls away off-screen right
    @State private var player: AVAudioPlayer? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()   // the SUV artwork sits on white

                VStack(spacing: 0) {
                    Spacer()

                    // SUV: drive-in / idle bob / drive-out are separate layers
                    // so the repeating bob can't fight the one-shot moves.
                    Image("RunSheetVehicle")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 24)
                        .offset(y: idling ? -1.5 : 1.5)
                        .animation(idling
                                   ? .easeInOut(duration: 0.22).repeatForever(autoreverses: true)
                                   : .default,
                                   value: idling)
                        .rotationEffect(.degrees(driveOut ? 2.5
                                                 : backUp ? -1.5
                                                 : (driveIn ? 0 : -3)))
                        .offset(x: driveOut ? geo.size.width
                                            : backUp ? -44
                                            : (driveIn ? 0 : -geo.size.width))
                        .accessibilityLabel("RunSheet")

                    // Wordmark + tagline (matches the in-app rounded-black style)
                    VStack(spacing: 6) {
                        Text("RunSheet")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "0F2547"))
                            .opacity(showWordmark ? 1 : 0)
                            .offset(y: showWordmark ? 0 : 14)
                        Text("Driver Timesheet System")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "7488A3"))
                            .tracking(1.5)
                            .opacity(showTagline ? 1 : 0)
                            .offset(y: showTagline ? 0 : 10)
                    }
                    .padding(.top, 22)
                    .opacity(driveOut ? 0 : 1)

                    Spacer()
                }

                // Copyright pinned at the bottom edge
                VStack {
                    Spacer()
                    Text("© 2026 Joey Wray")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "7488A3"))
                        .padding(.bottom, 8)
                        .opacity(showCredit && !driveOut ? 1 : 0)
                }
            }
        }
        .task { await runTimeline() }
    }

    // MARK: Timeline
    @MainActor
    private func runTimeline() async {
        // Reduce Motion: skip the theatrics — show everything, brief hold, done.
        if UIAccessibility.isReduceMotionEnabled {
            driveIn = true; showWordmark = true; showTagline = true; showCredit = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            onFinished()
            return
        }

        playEngineSound()

        // Drive in: heavier spring so the SUV overshoots a touch and settles.
        withAnimation(.spring(response: 0.85, dampingFraction: 0.72).delay(0.05)) {
            driveIn = true
        }

        try? await Task.sleep(nanoseconds: 550_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showWordmark = true }

        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showTagline = true }
        withAnimation(.easeIn(duration: 0.4).delay(0.2)) { showCredit = true }

        // Engine idles while the wordmark is read.
        try? await Task.sleep(nanoseconds: 250_000_000)
        idling = true

        // Hold, then back out of the spot… and pull away forward.
        try? await Task.sleep(nanoseconds: 1_250_000_000)
        idling = false
        withAnimation(.easeInOut(duration: 0.35)) { backUp = true }

        try? await Task.sleep(nanoseconds: 430_000_000)
        withAnimation(.easeIn(duration: 0.5)) { driveOut = true }

        try? await Task.sleep(nanoseconds: 450_000_000)
        onFinished()
    }

    // MARK: Engine sound
    /// `.ambient` = respects the silent switch and mixes with (never
    /// interrupts) whatever the driver is already playing.
    private func playEngineSound() {
        guard let url = Bundle.main.url(forResource: "EngineStart", withExtension: "wav") else {
            #if DEBUG
            print("🔇 EngineStart.wav missing from bundle")
            #endif
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.65
        player?.play()
    }
}

// MARK: - Root (splash → app)
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
