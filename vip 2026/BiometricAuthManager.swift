// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Biometric Auth Manager           ║
// ║           BiometricAuthManager.swift                         ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Handles Face ID / Touch ID authentication via LocalAuthentication.
// Falls back to device passcode so it works on all devices.
// No capability change required — LocalAuthentication is a built-in framework.

import Foundation
import Combine
import SwiftUI
import LocalAuthentication

@MainActor
final class BiometricAuthManager: ObservableObject {

    /// Whether the app is currently unlocked. Starts false so the lock
    /// screen shows immediately on first launch.
    @Published var isUnlocked: Bool = false

    /// Human-readable failure reason surfaced to the lock screen UI.
    @Published var authError: String? = nil

    // MARK: - Authenticate

    /// Attempts Face ID / Touch ID with automatic fallback to device passcode.
    /// On success sets `isUnlocked = true` and clears `authError`.
    /// On failure surfaces a message in `authError`.
    func authenticate() async {
        let context = LAContext()
        var error: NSError?

        // Prefer biometrics, fall back to device passcode
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            policy = .deviceOwnerAuthentication
        } else {
            // No Face ID enrolled AND no device passcode (common on simulators):
            // there is nothing to authenticate against — unlock rather than
            // brick the app on the lock screen forever.
            withAnimation(.easeInOut(duration: 0.35)) {
                isUnlocked = true
                authError  = nil
            }
            return
        }

        let reason = "Unlock Kauai VIP to access your trip data."

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isUnlocked = true
                    authError  = nil
                }
            }
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                // User dismissed — don't surface an error, just stay locked
                break
            case .biometryNotEnrolled:
                authError = "No Face ID / Touch ID enrolled. Please set one up in Settings."
            case .biometryNotAvailable:
                authError = "Biometrics not available on this device."
            case .biometryLockout:
                authError = "Too many failed attempts. Please use your device passcode."
            default:
                authError = laError.localizedDescription
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Lock

    /// Locks the app. Called when the scene moves to background so
    /// re-opening always requires re-authentication.
    func lockApp() {
        isUnlocked = false
        authError  = nil
    }
}
