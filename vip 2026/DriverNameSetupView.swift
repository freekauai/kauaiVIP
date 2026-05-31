// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — First-Launch Driver Setup        ║
// ║           DriverNameSetupView.swift                          ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Shown on first launch (or whenever driverName is empty) before
// MainView. Saves the name via TimesheetStore.saveDriverName(),
// which writes to UserDefaults key "kauai_vip_2026_driver_name"
// and publishes the change to store.driverName. ContentView will
// automatically switch to MainView once the name is non-empty.

import SwiftUI

struct DriverNameSetupView: View {
    @EnvironmentObject var store: TimesheetStore
    @State private var nameInput = ""
    @State private var companyInput = ""
    @FocusState private var fieldFocused: Bool

    private var isValid: Bool {
        !nameInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.oceanDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo / Title ──────────────────────────────────
                VStack(spacing: 8) {
                    Text("🏝️")
                        .font(.system(size: 64))
                    Text("KAUAI VIP 2026")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .tracking(2)
                    Text("Driver Timesheet System")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textTertiary)
                }

                Spacer()

                // ── Name Entry Card ───────────────────────────────
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WHO'S DRIVING?").labelStyle()
                        Text("Enter your name to personalise timesheets and PDF exports. A company name is optional.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("Driver — your full name", text: $nameInput)
                            .foregroundColor(AppTheme.textPrimary)
                            .font(.system(size: AppTheme.body))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppTheme.oceanLight.opacity(0.4))
                            .cornerRadius(AppTheme.fieldRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                                    .stroke(AppTheme.oceanLight, lineWidth: 1)
                            )
                            .focused($fieldFocused)
                            .submitLabel(.next)

                        TextField("Company (optional)", text: $companyInput)
                            .foregroundColor(AppTheme.textPrimary)
                            .font(.system(size: AppTheme.body))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppTheme.oceanLight.opacity(0.4))
                            .cornerRadius(AppTheme.fieldRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                                    .stroke(AppTheme.oceanLight, lineWidth: 1)
                            )
                            .onSubmit { saveName() }
                    }
                }
                .padding(.horizontal, AppTheme.screenPad)

                // ── CTA ───────────────────────────────────────────
                CoralButton("Get Started →", disabled: !isValid, action: saveName)
                    .padding(.horizontal, AppTheme.screenPad)
                    .padding(.top, AppTheme.cardSpacing)
                    .padding(.bottom, 48)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private func saveName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.saveCompanyName(companyInput)   // optional — empty is fine
        store.saveDriverName(trimmed)         // saved last: flips ContentView to MainView
    }
}
