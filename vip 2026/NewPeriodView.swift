// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — New Pay Period Screen            ║
// ║           NewPeriodView.swift                                ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct NewPeriodView: View {
    @EnvironmentObject var store: TimesheetStore
    @Environment(\.dismiss) var dismiss

    @State private var startDate = Date()
    @State private var endDate   = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var showAlert  = false
    @State private var alertMsg   = ""

    private var dayCount: Int {
        max(0, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day.map { $0 + 1 } ?? 0)
    }
    private var isValid: Bool { (14...16).contains(dayCount) && endDate > startDate }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {

                        // ── Date Range ─────────────────────────────────
                        AppCard {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("📅 PERIOD DATES").labelStyle()

                                // Start
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Start Date")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.textSecondary)
                                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(AppTheme.coral)
                                        .colorScheme(.dark)
                                        .onChange(of: startDate) { _, newDate in
                                            endDate = Calendar.current.date(byAdding: .day, value: 14, to: newDate) ?? endDate
                                        }
                                }

                                Divider().background(AppTheme.oceanLight)

                                // End
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("End Date")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.textSecondary)
                                    DatePicker("End Date", selection: $endDate,
                                               in: startDate...,
                                               displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(AppTheme.coral)
                                        .colorScheme(.dark)
                                }
                            }
                        }

                        // ── Day Count Indicator ────────────────────────
                        dayCountBadge

                        // ── Info Box ───────────────────────────────────
                        AppCard {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppTheme.info)
                                    .font(.system(size: 18))
                                Text("Pay periods must be **14 to 16 days** to align with Kauai VIP's bi-monthly schedule. Start dates should fall on the 1st or 16th of each month.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // ── Overlap Warning ────────────────────────────
                        if hasOverlap {
                            AppCard {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.warning)
                                    Text("This period overlaps with an existing period.")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.warning)
                                }
                            }
                        }

                        // ── Create Button ──────────────────────────────
                        CoralButton("Create Period", disabled: !isValid, action: createPeriod)
                            .padding(.bottom, 32)
                    }
                    .padding(AppTheme.screenPad)
                }
            }
            .navigationTitle("New Pay Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { createPeriod() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.4)
                }
            }
            .alert("Invalid Period", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMsg)
            }
        }
    }

    // MARK: - Day Count Badge
    private var dayCountBadge: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERIOD LENGTH").labelStyle()
                    Text("\(dayCount) days")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isValid ? AppTheme.success : AppTheme.error)
                }
                Spacer()
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isValid ? AppTheme.success : AppTheme.error)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(isValid ? AppTheme.success : AppTheme.error, lineWidth: 1.5)
        )
        .animation(.easeInOut, value: isValid)
    }

    // MARK: - Overlap Check
    private var hasOverlap: Bool {
        store.periods.contains { existing in
            !(endDate < existing.startDate || startDate > existing.endDate)
        }
    }

    // MARK: - Create
    private func createPeriod() {
        guard isValid else {
            alertMsg = "Period must be between 14 and 16 days."
            showAlert = true
            return
        }
        let period = PayPeriod(startDate: startDate, endDate: endDate)
        store.addPeriod(period)
        dismiss()
    }
}
