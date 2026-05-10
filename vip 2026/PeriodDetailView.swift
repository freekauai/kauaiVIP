// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Period Detail Screen             ║
// ║           PeriodDetailView.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct PeriodDetailView: View {
    let periodID: UUID
    @Binding var activeModal: ContentView.AppModal?

    @EnvironmentObject var store:          TimesheetStore
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var bridgeService:  BridgeService
    @Environment(\.dismiss) var dismiss

    @State private var showAddTrip  = false
    @State private var editingTrip: Trip? = nil
    @State private var tripToDelete: Trip? = nil
    @State private var showDeleteAlert = false

    // Derive period from store so updates are live
    private var period: PayPeriod? {
        store.periods.first { $0.id == periodID }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.oceanDeep.ignoresSafeArea()

            if let period = period {
                VStack(spacing: 0) {
                    TrafficBanner()

                    PeriodTopButtons(
                        onWeather: { activeModal = .weather },
                        onMap:     { activeModal = .map },
                        onTraffic: { activeModal = .traffic },
                        onStats:   { activeModal = .stats }
                    )
                    .environmentObject(weatherManager)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            driverHeader
                            summaryCard(period: period)
                            tripsSection(period: period)
                        }
                        .padding(.bottom, 100)
                    }
                }

                // Floating Add Trip
                VStack {
                    Spacer()
                    CoralButton("+ Add Trip", action: { showAddTrip = true })
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, 28)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.oceanDeep.opacity(0), AppTheme.oceanDeep],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
            } else {
                Text("Period not found").foregroundColor(AppTheme.textTertiary)
            }
        }
        .navigationTitle(period?.label ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: exportPDF) {
                        Label("Export PDF", systemImage: "doc.fill")
                    }
                    Button(action: exportCSV) {
                        Label("Export CSV", systemImage: "tablecells")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppTheme.coral)
                }
            }
        }
        .sheet(isPresented: $showAddTrip) {
            TripFormView(periodID: periodID, existingTrip: nil)
        }
        .sheet(item: $editingTrip) { trip in
            TripFormView(periodID: periodID, existingTrip: trip)
        }
        .alert("Delete Trip?", isPresented: $showDeleteAlert, presenting: tripToDelete) { trip in
            Button("Delete", role: .destructive) {
                store.deleteTrip(trip, fromPeriod: periodID)
            }
            Button("Cancel", role: .cancel) {}
        } message: { trip in
            Text("Remove \(trip.service.rawValue) trip for \(trip.clientName)? This cannot be undone.")
        }
    }

    // MARK: - Driver Header
    private var driverHeader: some View {
        Text(store.driverName)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(AppTheme.oceanDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.success)
    }

    // MARK: - Summary Card
    private func summaryCard(period: PayPeriod) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("PERIOD SUMMARY")
                    .labelStyle()

                HStack(spacing: 0) {
                    SummaryMetric(label: "Trips",        value: "\(period.trips.count)",                                   color: AppTheme.textPrimary)
                    Divider().frame(height: 40).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SummaryMetric(label: "Airport",      value: "\(period.trips.filter { $0.service == .airport }.count)", color: AppTheme.info)
                    Divider().frame(height: 40).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SummaryMetric(label: "Charter",      value: "\(period.trips.filter { $0.service == .charter }.count)", color: AppTheme.success)
                    Divider().frame(height: 40).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SummaryMetric(label: "Charter Hrs",  value: period.formattedCharterHours,                              color: AppTheme.warning)
                }
            }
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.top, AppTheme.cardSpacing)
    }

    // MARK: - Trips Section
    private func tripsSection(period: PayPeriod) -> some View {
        VStack(spacing: 0) {
            SectionLabel(text: "Trips (\(period.trips.count))")

            if period.trips.isEmpty {
                EmptyStateView(
                    icon: "🚗",
                    message: "No Trips Yet",
                    sub: "Tap '+ Add Trip' below to log your first trip for this period."
                )
            } else {
                let sorted = period.trips.sorted { $0.date > $1.date }
                ForEach(sorted) { trip in
                    TripCard(trip: trip,
                             onEdit:   { editingTrip = trip },
                             onDelete: { tripToDelete = trip; showDeleteAlert = true })
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, AppTheme.elemSpacing)
                }
            }
        }
    }

    // MARK: - Export
    private func exportPDF() {
        guard let period = period else { return }
        let safe = period.label.replacingOccurrences(of: " ", with: "_")
        shareFile(data: period.pdfData(driverName: store.driverName),
                  filename: "KauaiVIP_\(safe).pdf")
    }

    private func exportCSV() {
        guard let period = period else { return }
        let safe = period.label.replacingOccurrences(of: " ", with: "_")
        let data = Data(period.csvString.utf8)
        shareFile(data: data, filename: "KauaiVIP_\(safe).csv")
    }
}

// MARK: - Summary Metric
private struct SummaryMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.6)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip:     Trip
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        AppCard(padding: 10) {
            HStack(alignment: .top, spacing: 10) {
                // Date column
                VStack(spacing: 1) {
                    Text(trip.date.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(trip.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .frame(width: 34)

                Divider().frame(height: 36).background(AppTheme.oceanLight)

                // Main info
                VStack(alignment: .leading, spacing: 4) {
                    // Service / vehicle row
                    HStack(spacing: 4) {
                        Text(trip.vehicle.icon).font(.system(size: 12))
                        Text(trip.service.icon).font(.system(size: 12))
                        Text(trip.service.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    // Client
                    Text(trip.clientName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                    // Times
                    if trip.hasPUTime || trip.hasDOTime || trip.hasLeftBase || trip.hasBackBase {
                        HStack(spacing: 8) {
                            if trip.hasPUTime   { TimeChip(label: "PU", value: trip.formattedPickup) }
                            if trip.hasDOTime   { TimeChip(label: "DO", value: trip.formattedDropoff) }
                            if trip.hasLeftBase { TimeChip(label: "LB", value: trip.formattedLeftBase) }
                            if trip.hasBackBase { TimeChip(label: "BB", value: trip.formattedBackBase) }
                        }
                    }
                    // Notes
                    if !trip.notes.isEmpty {
                        Text(trip.notes)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textTertiary)
                            .italic()
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Edit / Delete
                VStack(spacing: 10) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.coral)
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.error)
                    }
                }
            }
        }
    }
}

// MARK: - Time Chip
private struct TimeChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppTheme.oceanLight.opacity(0.5))
        .cornerRadius(6)
    }
}
