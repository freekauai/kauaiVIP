// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Settings Screen                  ║
// ║           SettingsView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Accessible via the ⚙️ gear icon in the TIMESHEET PERIODS header
// on the main screen. Theme choice is persisted via @AppStorage
// and applied at the WindowGroup level in KauaiVIP2026App.swift.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TimesheetStore
    @Environment(\.dismiss) var dismiss

    // Shared with KauaiVIP2026App.swift and PeriodDetailView.swift
    @AppStorage("appTheme")          private var appTheme:          String = "system"
    @AppStorage("countdownEnabled")  private var countdownEnabled:  Bool   = true
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool   = true

    @State private var driverNameInput:       String = ""
    @State private var companyInput:          String = ""
    @State private var showClearConfirmation: Bool   = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    private var nameIsEmpty: Bool {
        driverNameInput.trimmingCharacters(in: .whitespaces).isEmpty
    }
    /// True when both fields already match what's stored (nothing to save).
    private var infoUnchanged: Bool {
        driverNameInput.trimmingCharacters(in: .whitespaces) == store.driverName &&
        companyInput.trimmingCharacters(in: .whitespaces)    == store.companyName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {
                        driverNameSection
                        themeSection
                        countdownSection
                        biometricsSection
                        appInfoSection
                        dangerSection
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                driverNameInput = store.driverName
                companyInput    = store.companyName
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Periods & Trips", role: .destructive) {
                    store.clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every pay period and trip. This action cannot be undone.")
            }
        }
    }

    // MARK: - Driver Name

    private var driverNameSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("DRIVER & COMPANY").labelStyle()

                TextField("Driver name", text: $driverNameInput)
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

                Text("If no company is set, your name is used on the app and PDF exports.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                CoralButton(
                    "Save",
                    disabled: nameIsEmpty || infoUnchanged,
                    action: saveName
                )
            }
        }
    }

    private func saveName() {
        let trimmed = driverNameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.saveDriverName(trimmed)
        store.saveCompanyName(companyInput)
    }

    // MARK: - Theme

    private var themeSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("APPEARANCE").labelStyle()
                Text("Changes take effect immediately across the whole app.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                Picker("Theme", selection: $appTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Blue Light").tag("blueLight")
                    Text("Blue Dark").tag("blueDark")
                }
                .pickerStyle(.menu)
                .tint(AppTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Countdown Toggle

    private var countdownSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("TRIP COUNTDOWN").labelStyle()

                Toggle(isOn: $countdownEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Show Countdowns")
                            .font(.system(size: AppTheme.subhead, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Display time-to-departure on the next upcoming trip card.")
                            .font(.system(size: AppTheme.footnote))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .tint(AppTheme.coral)
            }
        }
    }

    // MARK: - Biometrics

    private var biometricsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SECURITY").labelStyle()

                Toggle(isOn: $requireBiometrics) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "faceid")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.system(size: 15, weight: .medium))
                            Text("Require Face ID")
                                .font(.system(size: AppTheme.subhead, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        Text("Lock the app when it moves to the background.")
                            .font(.system(size: AppTheme.footnote))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .tint(AppTheme.coral)
            }
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("APP INFO").labelStyle()

                HStack {
                    Text("Version")
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(AppTheme.textPrimary)
                        .fontWeight(.semibold)
                }
                .font(.system(size: AppTheme.subhead))

                Divider().background(AppTheme.oceanLight)

                if let mailURL = AppConstants.mailtoURL {
                    Link(destination: mailURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.coral)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contact Support")
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(AppConstants.supportEmail)
                                    .foregroundColor(AppTheme.coral)
                                    .font(.system(size: AppTheme.footnote))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .font(.system(size: AppTheme.subhead))
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("DANGER ZONE").labelStyle()
                Text("These actions are permanent and cannot be undone.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                Button(action: { showClearConfirmation = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("Clear All Data")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppTheme.error)
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.error.opacity(0.4), lineWidth: 1.5)
        )
    }
}
