// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Passcode Screen                  ║
// ║           PasscodeView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import CryptoKit

struct PasscodeView: View {
    @Binding var setupComplete: Bool
    @EnvironmentObject private var store: TimesheetStore

    // Persisted driver name — shared with the rest of the app
    @AppStorage("kauai_vip_2026_driver_name") private var driverName: String = ""

    @State private var entered        = ""
    @State private var showError      = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showNameSetup  = false
    @State private var failedAttempts = 0
    @State private var lockCountdown  = 0
    @FocusState private var fieldFocused: Bool

    private static let maxAttempts     = 5
    private static let lockoutSeconds  = 30
    // SHA-256 of the access code — keeps the raw passcode out of source
    private static let correctCodeHash = "8b8e2ce1086a21a385905f84758d1e82606bd5f35e630e25179e87453d978ad7"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0d2137"), AppTheme.oceanMedium, AppTheme.oceanDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showNameSetup {
                DriverNameSetupView(driverName: $driverName, onComplete: { name in
                    store.saveDriverName(name)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        setupComplete = true
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .opacity
                ))
            } else {
                passcodeScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showNameSetup)
        .onAppear { fieldFocused = true }
    }

    // MARK: - Passcode Screen
    private var passcodeScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Text("🏝️")
                    .font(.system(size: 72))
                    .shadow(color: AppTheme.coral.opacity(0.4), radius: 20)

                Text("KAUAI VIP")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .tracking(4)

                Text("2026")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.coral)
                    .tracking(6)

                Text("Driver Timesheet System")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.top, 4)
            }

            Spacer()

            // Input area
            VStack(spacing: 16) {
                if lockCountdown > 0 {
                    Label("Too many attempts — try again in \(lockCountdown)s",
                          systemImage: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.error)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else {
                    Text("ENTER ACCESS CODE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                        .tracking(2)
                }

                SecureField("Access code", text: $entered)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .focused($fieldFocused)
                    .submitLabel(.go)
                    .onSubmit { tryUnlock() }
                    .disabled(lockCountdown > 0)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                            .fill(AppTheme.oceanMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                                    .stroke(showError ? AppTheme.error : AppTheme.oceanLight, lineWidth: 1.5)
                            )
                    )
                    .offset(x: shakeOffset)

                if showError {
                    Text("Invalid access code. Try again.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.error)
                        .transition(.opacity)
                }

                Button(action: tryUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text("Unlock").fontWeight(.bold)
                    }
                }
                .buttonStyle(CoralButtonStyle())
                .disabled(lockCountdown > 0)
            }
            .padding(.horizontal, AppTheme.screenPad)

            Spacer()

            VStack(spacing: 4) {
                Text("KAUAI VIP 2026 · Driver Edition")
                Text("Authorized Personnel Only")
            }
            .font(.system(size: 11))
            .foregroundColor(AppTheme.textTertiary)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Logic
    private func tryUnlock() {
        guard lockCountdown == 0 else { return }

        let hash = SHA256.hash(data: Data(entered.uppercased().utf8))
            .map { String(format: "%02x", $0) }.joined()

        if hash == PasscodeView.correctCodeHash {
            failedAttempts = 0
            if driverName.trimmingCharacters(in: .whitespaces).isEmpty {
                withAnimation { showNameSetup = true }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    setupComplete = true
                }
            }
        } else {
            triggerError()
        }
    }

    private func triggerError() {
        failedAttempts += 1
        showError = true

        withAnimation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shakeOffset = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showError = false }
            entered = ""
        }

        if failedAttempts >= PasscodeView.maxAttempts {
            startLockout()
        }
    }

    private func startLockout() {
        lockCountdown = PasscodeView.lockoutSeconds
        entered       = ""
        fieldFocused  = false

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            lockCountdown -= 1
            if lockCountdown <= 0 {
                timer.invalidate()
                failedAttempts = 0
                withAnimation { fieldFocused = true }
            }
        }
    }
}

// MARK: - Driver Name Setup Screen
struct DriverNameSetupView: View {
    @Binding var driverName: String
    let onComplete: (String) -> Void

    @State private var nameInput = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon + heading
            VStack(spacing: 12) {
                Text("👤")
                    .font(.system(size: 64))

                Text("Welcome to\nKauai VIP 2026")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .tracking(1)

                Text("Enter your name to personalise the app.\nThis is saved on this device only.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Spacer()

            // Name field
            VStack(spacing: 16) {
                Text("DRIVER NAME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
                    .tracking(2)

                TextField("e.g. Joey Kamaka", text: $nameInput)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                            .fill(AppTheme.oceanMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                                    .stroke(showError ? AppTheme.error : AppTheme.coral.opacity(0.6), lineWidth: 1.5)
                            )
                    )

                if showError {
                    Text("Please enter your name to continue.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.error)
                        .transition(.opacity)
                }

                Button(action: saveName) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Get Started").fontWeight(.bold)
                    }
                }
                .buttonStyle(CoralButtonStyle())
            }
            .padding(.horizontal, AppTheme.screenPad)

            Spacer()

            Text("Your name appears on the home screen and timesheets.")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .onAppear { focused = true }
    }

    private func saveName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            withAnimation { showError = true }
            return
        }
        driverName = trimmed
        onComplete(trimmed)
    }
}
