// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Stats Screen                     ║
// ║           StatsView.swift                                    ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: TimesheetStore
    @Environment(\.dismiss) var dismiss

    @State private var scope: StatScope = .allTime

    enum StatScope: String, CaseIterable {
        case allTime = "All Time"
        case periods = "Periods"
        case monthly = "Monthly"
    }

    private var allTrips: [Trip] { store.periods.flatMap(\.trips) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Scope", selection: $scope) {
                        ForEach(StatScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppTheme.screenPad)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            switch scope {
                            case .allTime: allTimeContent
                            case .periods: periodsContent
                            case .monthly: monthlyContent
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Stats · \(store.driverName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: exportScopeCSV) {
                            Label("Export \(scope.rawValue) (CSV)", systemImage: "tablecells")
                        }
                        Button(action: exportAllCSV) {
                            Label("Export All Trips (CSV)", systemImage: "tablecells.badge.ellipsis")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppTheme.coral)
                    }
                    .disabled(store.periods.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Export

    private func exportAllCSV() {
        let data = Data(store.allTripsCsvString.utf8)
        shareFile(data: data, filename: "KauaiVIP_AllTrips.csv")
    }

    private func exportScopeCSV() {
        let csv: String
        switch scope {
        case .allTime:
            csv = store.allTripsCsvString
        case .periods:
            csv = store.allTripsCsvString  // same data, period column already included
        case .monthly:
            let groups = monthlyGroups()
            var rows = ["Month,Date,Vehicle,Service,Client,PU Time,DO Time,Left Base,Back Base,Notes"]
            for (month, trips) in groups {
                for t in trips {
                    rows.append([
                        "\"\(month)\"", t.formattedDate, t.vehicle.rawValue,
                        t.service.rawValue, "\"\(t.clientName)\"",
                        t.formattedPickup, t.formattedDropoff,
                        t.formattedLeftBase, t.formattedBackBase,
                        "\"\(t.notes)\""
                    ].joined(separator: ","))
                }
            }
            csv = rows.joined(separator: "\n")
        }
        shareFile(data: Data(csv.utf8), filename: "KauaiVIP_\(scope.rawValue.replacingOccurrences(of: " ", with: "")).csv")
    }

    // MARK: - All Time

    private var allTimeContent: some View {
        VStack(spacing: 0) {
            SectionLabel(text: "Overview")

            AppCard {
                HStack(spacing: 0) {
                    BigStat(label: "Trips",   value: "\(allTrips.count)",           color: AppTheme.textPrimary)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Charter", value: "\(charterTrips(allTrips))",    color: AppTheme.success)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Periods", value: "\(store.periods.count)",       color: AppTheme.info)
                }
            }
            .padding(.horizontal, AppTheme.screenPad)

            AppCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Charter Hours").labelStyle()
                    Text(charterHoursFormatted(allTrips))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.warning)
                }
            }
            .padding(.horizontal, AppTheme.screenPad)
            .padding(.top, AppTheme.cardSpacing)

            SectionLabel(text: "By Service Type")
            serviceBreakdown(trips: allTrips)
                .padding(.horizontal, AppTheme.screenPad)

            SectionLabel(text: "By Vehicle")
            vehicleBreakdown(trips: allTrips)
                .padding(.horizontal, AppTheme.screenPad)
        }
    }

    // MARK: - By Period

    private var periodsContent: some View {
        VStack(spacing: 0) {
            if store.periods.isEmpty {
                EmptyStateView(icon: "📋", message: "No Periods", sub: "Add a pay period to see stats.")
            } else {
                ForEach(store.periods) { period in
                    periodSection(period)
                }
            }
        }
    }

    private func periodSection(_ period: PayPeriod) -> some View {
        VStack(spacing: 0) {
            SectionLabel(text: period.label)

            AppCard {
                HStack(spacing: 0) {
                    BigStat(label: "Trips",   value: "\(period.trips.count)",          color: AppTheme.textPrimary)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Charter", value: "\(charterTrips(period.trips))",  color: AppTheme.success)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Days",    value: "\(period.dayCount)",              color: AppTheme.info)
                }
            }
            .padding(.horizontal, AppTheme.screenPad)

            AppCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Charter Hours").labelStyle()
                    Text(charterHoursFormatted(period.trips))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.warning)
                }
            }
            .padding(.horizontal, AppTheme.screenPad)
            .padding(.top, AppTheme.cardSpacing)

            if !period.trips.isEmpty {
                SectionLabel(text: "By Service Type")
                serviceBreakdown(trips: period.trips)
                    .padding(.horizontal, AppTheme.screenPad)

                SectionLabel(text: "By Vehicle")
                vehicleBreakdown(trips: period.trips)
                    .padding(.horizontal, AppTheme.screenPad)
            }

            Divider()
                .background(AppTheme.oceanLight.opacity(0.4))
                .padding(.horizontal, AppTheme.screenPad)
                .padding(.top, AppTheme.cardSpacing)
        }
    }

    // MARK: - By Month

    private var monthlyContent: some View {
        VStack(spacing: 0) {
            let groups = monthlyGroups()
            if groups.isEmpty {
                EmptyStateView(icon: "📅", message: "No Data", sub: "Log trips to see monthly stats.")
            } else {
                ForEach(groups, id: \.0) { month, trips in
                    monthSection(month: month, trips: trips)
                }
            }
        }
    }

    private func monthSection(month: String, trips: [Trip]) -> some View {
        VStack(spacing: 0) {
            SectionLabel(text: month)

            AppCard {
                HStack(spacing: 0) {
                    BigStat(label: "Trips",   value: "\(trips.count)",          color: AppTheme.textPrimary)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Charter", value: "\(charterTrips(trips))",  color: AppTheme.success)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Days",    value: "\(uniqueDays(trips))",     color: AppTheme.info)
                }
            }
            .padding(.horizontal, AppTheme.screenPad)

            AppCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Charter Hours").labelStyle()
                    Text(charterHoursFormatted(trips))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.warning)
                }
            }
            .padding(.horizontal, AppTheme.screenPad)
            .padding(.top, AppTheme.cardSpacing)

            if !trips.isEmpty {
                SectionLabel(text: "By Service Type")
                serviceBreakdown(trips: trips)
                    .padding(.horizontal, AppTheme.screenPad)

                SectionLabel(text: "By Vehicle")
                vehicleBreakdown(trips: trips)
                    .padding(.horizontal, AppTheme.screenPad)
            }

            Divider()
                .background(AppTheme.oceanLight.opacity(0.4))
                .padding(.horizontal, AppTheme.screenPad)
                .padding(.top, AppTheme.cardSpacing)
        }
    }

    // MARK: - Service Breakdown Card

    private func serviceBreakdown(trips: [Trip]) -> some View {
        AppCard {
            VStack(spacing: 10) {
                ForEach(ServiceType.allCases) { service in
                    let count = trips.filter { $0.service == service }.count
                    if count > 0 {
                        HStack(spacing: 10) {
                            Text(service.icon)
                                .font(.system(size: 16))
                                .frame(width: 24)
                            Text(service.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(width: 90, alignment: .leading)
                            GeometryReader { geo in
                                let fraction = trips.isEmpty ? 0.0 : CGFloat(count) / CGFloat(trips.count)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(serviceColor(service))
                                    .frame(width: max(4, geo.size.width * fraction), height: 10)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(height: 10)
                            Text("\(count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Vehicle Breakdown Card

    private func vehicleBreakdown(trips: [Trip]) -> some View {
        AppCard {
            VStack(spacing: 10) {
                ForEach(Vehicle.allCases) { vehicle in
                    let count = trips.filter { $0.vehicle == vehicle }.count
                    if count > 0 {
                        HStack(spacing: 10) {
                            Text(vehicle.icon)
                                .font(.system(size: 16))
                                .frame(width: 24)
                            Text(vehicle.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(width: 90, alignment: .leading)
                            GeometryReader { geo in
                                let fraction = trips.isEmpty ? 0.0 : CGFloat(count) / CGFloat(trips.count)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.info)
                                    .frame(width: max(4, geo.size.width * fraction), height: 10)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(height: 10)
                            Text("\(count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func uniqueDays(_ trips: [Trip]) -> Int {
        Set(trips.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private func charterTrips(_ trips: [Trip]) -> Int {
        trips.filter { $0.service == .charter }.count
    }

    private func charterHoursFormatted(_ trips: [Trip]) -> String {
        let total = trips
            .filter { $0.service == .charter }
            .compactMap(\.charterDuration)
            .reduce(0.0, +)
        guard total > 0 else { return "--" }
        let h = Int(total) / 3_600
        let m = (Int(total) % 3_600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func monthlyGroups() -> [(String, [Trip])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var groups: [String: (Date, [Trip])] = [:]
        for trip in allTrips {
            let key = fmt.string(from: trip.date)
            if groups[key] == nil {
                groups[key] = (trip.date, [trip])
            } else {
                groups[key]!.1.append(trip)
            }
        }
        return groups
            .map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.1 > $1.1 }
            .map { ($0.0, $0.2) }
    }

    private func serviceColor(_ service: ServiceType) -> Color {
        switch service {
        case .airport: return AppTheme.info
        case .charter: return AppTheme.success
        }
    }
}

// MARK: - Stat Components

private struct BigStat: View {
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
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

