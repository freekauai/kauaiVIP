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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
        }
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
                SectionLabel(text: "\(store.periods.count) Pay Periods")
                ForEach(store.periods) { period in
                    periodRow(period)
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, AppTheme.elemSpacing)
                }
            }
        }
    }

    private func periodRow(_ period: PayPeriod) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(period.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 0) {
                    SmallStat(label: "Trips",   value: "\(period.trips.count)",              color: AppTheme.textPrimary)
                    Divider().frame(height: 32).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SmallStat(label: "Charter", value: "\(charterTrips(period.trips))",       color: AppTheme.success)
                    Divider().frame(height: 32).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SmallStat(label: "Hours",   value: charterHoursFormatted(period.trips),  color: AppTheme.warning)
                    Divider().frame(height: 32).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SmallStat(label: "Days",    value: "\(period.dayCount)",                  color: AppTheme.info)
                }

                if !period.trips.isEmpty {
                    serviceBar(trips: period.trips)
                }
            }
        }
    }

    // MARK: - By Month

    private var monthlyContent: some View {
        VStack(spacing: 0) {
            let groups = monthlyGroups()
            if groups.isEmpty {
                EmptyStateView(icon: "📅", message: "No Data", sub: "Log trips to see monthly stats.")
            } else {
                SectionLabel(text: "\(groups.count) Months")
                ForEach(groups, id: \.0) { month, trips in
                    monthRow(month: month, trips: trips)
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, AppTheme.elemSpacing)
                }
            }
        }
    }

    private func monthRow(month: String, trips: [Trip]) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(month)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 0) {
                    SmallStat(label: "Trips",   value: "\(trips.count)",              color: AppTheme.textPrimary)
                    Divider().frame(height: 32).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SmallStat(label: "Charter", value: "\(charterTrips(trips))",       color: AppTheme.success)
                    Divider().frame(height: 32).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SmallStat(label: "Hours",   value: charterHoursFormatted(trips),  color: AppTheme.warning)
                }

                if !trips.isEmpty {
                    serviceBar(trips: trips)
                }
            }
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

    // MARK: - Inline Service Bar (for period/month rows)

    private func serviceBar(trips: [Trip]) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(ServiceType.allCases) { service in
                    let count = trips.filter { $0.service == service }.count
                    if count > 0 {
                        let fraction = CGFloat(count) / CGFloat(trips.count)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(serviceColor(service))
                            .frame(width: max(4, geo.size.width * fraction), height: 6)
                    }
                }
            }
        }
        .frame(height: 6)
    }

    // MARK: - Helpers

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

private struct SmallStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
