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
                            AppFooter()
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Stats · \(store.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: exportScopePDF) {
                            Label("Export PDF", systemImage: "doc.fill")
                        }
                        Button(action: exportScopeCSV) {
                            Label("Export CSV", systemImage: "tablecells")
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

    private func exportScopePDF() {
        let sections: [(String, [Trip])]
        let filename: String
        switch scope {
        case .allTime:
            sections = [("All Trips", allTrips)]
            filename = "RunSheet_AllTime.pdf"
        case .periods:
            sections = store.periods.map { ($0.label, $0.trips) }
            filename = "RunSheet_Periods.pdf"
        case .monthly:
            sections = monthlyGroups()
            filename = "RunSheet_Monthly.pdf"
        }
        let data = makeStatsPDF(
            title: "\(scope.rawValue) Report",
            sections: sections,
            driverName: store.driverName,
            companyName: store.companyName
        )
        shareFile(data: data, filename: filename)
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
                for t in trips.sorted(by: { $0.date < $1.date }) {
                    rows.append([
                        csvQuote(month), csvQuote(t.formattedDate), csvQuote(t.vehicle.rawValue),
                        csvQuote(t.service.rawValue), csvQuote(t.clientName),
                        t.formattedPickup, t.formattedDropoff,
                        t.formattedLeftBase, t.formattedBackBase,
                        csvQuote(t.notes)
                    ].joined(separator: ","))
                }
            }
            csv = rows.joined(separator: "\n")
        }
        shareFile(data: Data(csv.utf8), filename: "RunSheet_\(scope.rawValue.replacingOccurrences(of: " ", with: "")).csv")
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

            SectionLabel(text: "Insights")
            insightsCard(TripStats(allTrips))

            SectionLabel(text: "By Service Type")
            serviceBreakdown(trips: allTrips)
                .padding(.horizontal, AppTheme.screenPad)

            SectionLabel(text: "By Vehicle")
            vehicleBreakdown(trips: allTrips)
                .padding(.horizontal, AppTheme.screenPad)

            placeSection(trips: allTrips)
        }
    }

    // MARK: - By Period

    private var periodsContent: some View {
        VStack(spacing: 0) {
            if store.periods.isEmpty {
                EmptyStateView(icon: "📋", message: "No Periods", sub: "Add a pay period to see stats.")
            } else {
                // Skip the overall card when there's a single period (it would
                // just duplicate that period's numbers).
                if store.periods.count > 1 {
                    SectionLabel(text: "Overall")
                    grandSummaryCard(TripStats(allTrips))
                }

                ForEach(Array(store.periods.enumerated()), id: \.element.id) { idx, period in
                    // store.periods is newest-first, so the next element is the previous period.
                    let prevCount = idx + 1 < store.periods.count ? store.periods[idx + 1].trips.count : nil
                    periodSection(period, previousTripCount: prevCount)
                }
            }
        }
    }

    private func periodSection(_ period: PayPeriod, previousTripCount: Int?) -> some View {
        VStack(spacing: 0) {
            sectionHeader(period.label, current: period.trips.count, previous: previousTripCount)

            AppCard {
                HStack(spacing: 0) {
                    BigStat(label: "Trips",   value: "\(period.trips.count)",          color: AppTheme.textPrimary)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Charter", value: "\(charterTrips(period.trips))",  color: AppTheme.success)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Length",  value: "\(period.dayCount)d",             color: AppTheme.info)
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

                placeSection(trips: period.trips)
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
                if groups.count > 1 {
                    SectionLabel(text: "Overall")
                    grandSummaryCard(TripStats(allTrips))
                }

                ForEach(Array(groups.enumerated()), id: \.element.0) { idx, group in
                    // groups is newest-first, so the next element is the previous month.
                    let prevCount = idx + 1 < groups.count ? groups[idx + 1].1.count : nil
                    monthSection(month: group.0, trips: group.1, previousTripCount: prevCount)
                }
            }
        }
    }

    private func monthSection(month: String, trips: [Trip], previousTripCount: Int?) -> some View {
        VStack(spacing: 0) {
            sectionHeader(month, current: trips.count, previous: previousTripCount)

            AppCard {
                HStack(spacing: 0) {
                    BigStat(label: "Trips",   value: "\(trips.count)",          color: AppTheme.textPrimary)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Charter", value: "\(charterTrips(trips))",  color: AppTheme.success)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Days Worked", value: "\(uniqueDays(trips))", color: AppTheme.info)
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

                placeSection(trips: trips)
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
                ForEach(servicesPresent(in: trips)) { service in
                    let count = trips.filter { $0.service == service }.count
                    if count > 0 {
                        let pct = trips.isEmpty ? 0 : Int((Double(count) / Double(trips.count) * 100).rounded())
                        HStack(spacing: 10) {
                            Text(service.icon)
                                .font(.system(size: 16))
                                .frame(width: 24)
                            Text(service.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
                            Text("\(pct)%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.textTertiary)
                                .frame(width: 38, alignment: .trailing)
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
                ForEach(vehiclesPresent(in: trips)) { vehicle in
                    let count = trips.filter { $0.vehicle == vehicle }.count
                    if count > 0 {
                        let pct = trips.isEmpty ? 0 : Int((Double(count) / Double(trips.count) * 100).rounded())
                        HStack(spacing: 10) {
                            Text(vehicle.icon)
                                .font(.system(size: 16))
                                .frame(width: 24)
                            Text(vehicle.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
                            Text("\(pct)%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.textTertiary)
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Place Breakdown Card

    /// Trips-per-place, most-visited first. A trip can mention several
    /// places, so counts overlap — each row's % is "share of trips that
    /// touch this place", not slices of a pie.
    private func placeCounts(in trips: [Trip]) -> [(place: Place, count: Int)] {
        var counts: [Place: Int] = [:]
        for t in trips {
            for p in t.places(from: store.allPlaces) { counts[p, default: 0] += 1 }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key.name < $1.key.name : $0.value > $1.value }
            .map { (place: $0.key, count: $0.value) }
    }

    private func placeBreakdown(counts: [(place: Place, count: Int)], tripCount: Int) -> some View {
        AppCard {
            VStack(spacing: 10) {
                ForEach(counts, id: \.place) { entry in
                    let pct = tripCount == 0 ? 0 : Int((Double(entry.count) / Double(tripCount) * 100).rounded())
                    HStack(spacing: 10) {
                        Text(entry.place.icon)
                            .font(.system(size: 16))
                            .frame(width: 24)
                        Text(entry.place.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(width: 90, alignment: .leading)
                        GeometryReader { geo in
                            let fraction = tripCount == 0 ? 0.0 : CGFloat(entry.count) / CGFloat(tripCount)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.coral)
                                .frame(width: max(4, geo.size.width * fraction), height: 10)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(height: 10)
                        Text("\(entry.count)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 28, alignment: .trailing)
                        Text("\(pct)%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// "By Place" section — omitted entirely when no notes mention a place.
    @ViewBuilder
    private func placeSection(trips: [Trip]) -> some View {
        let counts = placeCounts(in: trips)
        if !counts.isEmpty {
            SectionLabel(text: "By Place")
            placeBreakdown(counts: counts, tripCount: trips.count)
                .padding(.horizontal, AppTheme.screenPad)
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
        // Collect trips into buckets keyed by month string.
        var groups: [String: [Trip]] = [:]
        for trip in allTrips {
            groups[fmt.string(from: trip.date), default: []].append(trip)
        }
        // Sort by the *earliest* trip date in each bucket so ordering is deterministic
        // regardless of dictionary iteration order.
        return groups
            .map { key, trips -> (String, Date, [Trip]) in
                let earliest = trips.map(\.date).min() ?? Date.distantPast
                return (key, earliest, trips)
            }
            .sorted { $0.1 > $1.1 }   // newest month first
            .map { ($0.0, $0.2) }
    }

    private func serviceColor(_ service: ServiceType) -> Color {
        if service == .charter { return AppTheme.success }
        if service == .airport { return AppTheme.info }
        return AppTheme.coral   // custom services
    }

    /// Distinct services appearing in `trips`, built-ins first (in canonical
    /// order), then any custom services in first-appearance order.
    private func servicesPresent(in trips: [Trip]) -> [ServiceType] {
        var ordered: [ServiceType] = ServiceType.builtIns.filter { s in trips.contains { $0.service == s } }
        for t in trips where !ordered.contains(t.service) { ordered.append(t.service) }
        return ordered
    }

    private func vehiclesPresent(in trips: [Trip]) -> [Vehicle] {
        var ordered: [Vehicle] = Vehicle.builtIns.filter { v in trips.contains { $0.vehicle == v } }
        for t in trips where !ordered.contains(t.vehicle) { ordered.append(t.vehicle) }
        return ordered
    }

    // MARK: - Insight cards

    private func insightsCard(_ stats: TripStats) -> some View {
        AppCard {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    MiniStat(label: "Avg/Day",      value: stats.uniqueDays > 0 ? String(format: "%.1f", stats.avgTripsPerDay) : "--", color: AppTheme.info)
                    MiniStat(label: "Avg Charter",  value: formatDurationHM(stats.avgCharterSeconds),       color: AppTheme.success)
                }
                Divider().background(AppTheme.oceanLight.opacity(0.4))
                HStack(spacing: 0) {
                    MiniStat(label: "Longest Charter", value: formatDurationHM(stats.longestCharterSeconds ?? 0), color: AppTheme.warning)
                    MiniStat(label: "Busiest Day",     value: stats.busiestWeekday?.name ?? "--",                color: AppTheme.coral)
                }
            }
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.top, AppTheme.cardSpacing)
    }

    // MARK: - Grand summary (Periods / Monthly overall)

    private func grandSummaryCard(_ stats: TripStats) -> some View {
        AppCard {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    BigStat(label: "Trips",   value: "\(stats.total)",      color: AppTheme.textPrimary)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Charter", value: "\(stats.charter)",    color: AppTheme.success)
                    Divider().frame(height: 44).background(AppTheme.oceanLight).padding(.horizontal, 12)
                    BigStat(label: "Days Worked", value: "\(stats.uniqueDays)", color: AppTheme.info)
                }
                Divider().background(AppTheme.oceanLight.opacity(0.4))
                HStack(spacing: 0) {
                    MiniStat(label: "Charter Hrs", value: formatDurationHM(stats.charterSeconds), color: AppTheme.warning)
                    MiniStat(label: "Duty Hrs",    value: formatDurationHM(stats.dutySeconds),    color: AppTheme.coral)
                }
            }
        }
        .padding(.horizontal, AppTheme.screenPad)
    }

    // MARK: - Section header with period-over-period delta

    private func sectionHeader(_ title: String, current: Int, previous: Int?) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: AppTheme.caption, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.8)
            Spacer()
            deltaBadge(current: current, previous: previous)
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.top, AppTheme.sectionSpacing)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func deltaBadge(current: Int, previous: Int?) -> some View {
        if let previous, previous != current {
            let d = current - previous
            HStack(spacing: 2) {
                Image(systemName: d > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text("\(abs(d)) vs prev")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(d > 0 ? AppTheme.success : AppTheme.error)
        }
    }
}

// MARK: - Stat Components

private struct MiniStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

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

