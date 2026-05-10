// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Main Home Screen                 ║
// ║           MainView.swift                                     ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct MainView: View {
    @EnvironmentObject var store:          TimesheetStore
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var bridgeService:  BridgeService

    @Binding var activeModal: ContentView.AppModal?

    @State private var showNewPeriod     = false
    @State private var selectedPeriod:   PayPeriod? = nil
    @State private var didAutoNavigate   = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppTheme.oceanDeep.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Traffic Banner ────────────────────────────────
                    TrafficBanner()

                    // ── Top Action Buttons ────────────────────────────
                    TopActionButtons(
                        onWeather: { activeModal = .weather },
                        onMap:     { activeModal = .map },
                        onTraffic: { activeModal = .traffic },
                        onStats:   { activeModal = .stats }
                    )

                    // ── Scrollable Content ────────────────────────────
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            headerSection
                            liveConditionsCard
                            miniRouteMapCard
                            periodListSection
                        }
                        .padding(.bottom, 100) // FAB clearance
                    }
                }

                // ── Floating Add Button ───────────────────────────────
                VStack {
                    Spacer()
                    CoralButton("+ New Pay Period", action: { showNewPeriod = true })
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, 28)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.oceanDeep.opacity(0), AppTheme.oceanDeep],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if !didAutoNavigate, let latest = store.periods.first {
                    didAutoNavigate = true
                    selectedPeriod = latest
                }
            }
            .navigationDestination(item: $selectedPeriod) { period in
                PeriodDetailView(periodID: period.id, activeModal: $activeModal)
            }
            .sheet(isPresented: $showNewPeriod) {
                NewPeriodView()
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("🏝️ KAUAI VIP")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .tracking(2)
            Text("2026")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.coral)
                .tracking(5)
            if !store.driverName.isEmpty {
                Text(store.driverName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.top, 4)
            }
            Text("Driver Timesheet System")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Live Conditions Card
    private var liveConditionsCard: some View {
        AppCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIVE CONDITIONS")
                        .labelStyle()

                    HStack(spacing: 10) {
                        WeatherIcon(symbolName: weatherManager.sfSymbol, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weatherManager.tempF)
                                .font(.system(size: 22, weight: .bold))
                            Text(weatherManager.conditionText)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 14) {
                        Label(weatherManager.windDescription, systemImage: "wind")
                        Label(weatherManager.humidityPct,    systemImage: "humidity.fill")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)

                    // Bridge status inline
                    Label {
                        Text("Hanalei Bridge: \(bridgeService.bridgeStatus)")
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: bridgeService.level.sfSymbol)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(bridgeService.level.statusColor)
                }
                Spacer()
                Button("Details") { activeModal = .weather }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.coral)
            }
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.top, 4)
    }

    // MARK: - Mini Route Map Card
    private var miniRouteMapCard: some View {
        AppCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Label("Kauai Route Map", systemImage: "map.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button("Apple Maps ›") { activeModal = .map }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.coral)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().background(AppTheme.oceanLight)

                // Inline route strip
                VStack(spacing: 0) {
                    RouteStopRow(icon: "📍", name: "Princeville",    sub: "North Shore",   color: AppTheme.success,  isLast: false)
                    RouteStopRow(icon: "🌉", name: "Hanalei Bridge", sub: bridgeService.bridgeStatus, color: bridgeService.level.statusColor, isLast: false)
                    RouteStopRow(icon: "📍", name: "Kapaa",          sub: "Eastside",      color: AppTheme.warning,  isLast: false)
                    RouteStopRow(icon: "✈️", name: "Lihue Airport",  sub: "LIH",           color: AppTheme.success,  isLast: true)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.top, AppTheme.cardSpacing)
    }

    // MARK: - Period List
    private var periodListSection: some View {
        VStack(spacing: 0) {
            SectionLabel(text: "Timesheet Periods")

            if store.periods.isEmpty {
                EmptyStateView(
                    icon: "📋",
                    message: "No Periods Yet",
                    sub: "Tap '+ New Pay Period' below to get started."
                )
            } else {
                ForEach(store.periods) { period in
                    PeriodCard(period: period)
                        .onTapGesture { selectedPeriod = period }
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, AppTheme.elemSpacing)
                }
            }
        }
    }
}

// MARK: - Route Stop Row
private struct RouteStopRow: View {
    let icon:   String
    let name:   String
    let sub:    String
    let color:  Color
    let isLast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Connector line + dot
            VStack(spacing: 0) {
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.oceanLight)
                        .frame(width: 2, height: 10)
                }
                Text(icon).font(.system(size: 18))
                Rectangle()
                    .fill(AppTheme.oceanLight)
                    .frame(width: 2, height: 10)
                    .opacity(isLast ? 0 : 1)
            }
            .frame(width: 32)

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text(sub)
                .font(.system(size: 12))
                .foregroundColor(color)
                .fontWeight(sub == "CLOSED" || sub == "1-Lane" ? .bold : .regular)

            Spacer()
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Period Card
struct PeriodCard: View {
    let period: PayPeriod

    var body: some View {
        AppCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📅 \(period.label)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 16) {
                        Label("\(period.trips.count) trips", systemImage: "car.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                        Label("\(period.dayCount) days", systemImage: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.coral)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.top, 4)
            }
        }
    }
}
