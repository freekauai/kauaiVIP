// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Driver Name Setup                ║
// ║           PasscodeView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

// MARK: - Driver Name Setup Screen
struct DriverNameSetupView: View {
    @Binding var driverName: String
    let onComplete: (String) -> Void

    @State private var nameInput = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0d2137"), AppTheme.oceanMedium, AppTheme.oceanDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon + heading
                VStack(spacing: 12) {
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

                    Text("Enter your name to get started.")
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

                VStack(spacing: 4) {
                    Text("KAUAI VIP 2026 · Driver Edition")
                    Text("Your name is saved on this device only.")
                }
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
            }
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
