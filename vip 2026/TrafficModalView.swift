// ╔══════════════════════════════════════════════════════════════╗
// ║           RUNSHEET — Traffic Modal (USGS River Gauge)       ║
// ║           TrafficModalView.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct TrafficModalView: View {
    @EnvironmentObject var bridgeService: BridgeService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {

                        // ── Bridge Status Hero ──────────────────────────
                        bridgeHeroCard

                        // ── Water Level Gauge ───────────────────────────
                        waterLevelCard

                        // ── Route List ──────────────────────────────────
                        routesSection

                        // ── Island Map ──────────────────────────────────
                        islandRouteVisual

                        // ── Last Updated ────────────────────────────────
                        footerNote
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("🚦 Live Traffic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { bridgeService.refresh() } label: {
                        Image(systemName: "arrow.clockwise").foregroundColor(AppTheme.coral)
                    }
                }
            }
        }
    }

    // MARK: - Bridge Hero
    private var bridgeHeroCard: some View {
        AppCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(bridgeService.level.statusColor.opacity(0.15))
                        .frame(width: 68, height: 68)
                    Image(systemName: bridgeService.level.sfSymbol)
                        .font(.system(size: 36))
                        .foregroundColor(bridgeService.level.statusColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("HANALEI BRIDGE").labelStyle()
                    Text(bridgeService.bridgeStatus)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(bridgeService.level.statusColor)
                    Text("Traffic level: \(bridgeService.trafficLevel)")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                    if bridgeService.waterLevelFt != "N/A" {
                        Label("River: \(bridgeService.waterLevelFt)", systemImage: "waveform.path")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(bridgeService.level.statusColor, lineWidth: 1.5)
        )
    }

    // MARK: - Water Level Card
    private var waterLevelCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("RIVER WATER LEVEL (USGS GAGE)").labelStyle()

                if bridgeService.rawWaterFt != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(bridgeService.waterLevelFt)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(bridgeService.gaugeColor)
                            Spacer()
                            Text("Max ~\(Int(BridgeService.gaugeFt)) ft")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.oceanLight)
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(bridgeService.gaugeColor)
                                    .frame(width: geo.size.width * bridgeService.gaugePct, height: 12)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text("0 ft").font(.system(size: 10)).foregroundColor(AppTheme.textTertiary)
                            Spacer()
                            Text("\(Int(BridgeService.cautionFt)) ft (Caution)").font(.system(size: 10)).foregroundColor(AppTheme.warning)
                            Spacer()
                            Text("\(Int(BridgeService.closedFt)) ft (Closed)").font(.system(size: 10)).foregroundColor(AppTheme.error)
                        }
                    }
                } else {
                    Text("Water level data unavailable")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Routes Section
    private var routesSection: some View {
        VStack(spacing: 0) {
            Text("KEY ROUTES").labelStyle()
                .padding(.bottom, 6)

            ForEach(bridgeService.routes) { route in
                RouteRow(route: route)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Island Route Visual
    private var islandRouteVisual: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ISLAND MAP")
                    .labelStyle()
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                Divider().background(AppTheme.oceanLight)

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // Fractional x anchors — scale with available width
                    let routeX  = w * 0.43          // vertical route line
                    let rightX  = w * 0.54          // pins right of the line
                    let leftX   = w * 0.17          // pins left  of the line
                    let bridgeW = w * 0.055         // half-width of bridge crossbar

                    ZStack {
                        AppTheme.oceanDeep

                        // Route line (north → south)
                        Path { path in
                            path.move(to:    CGPoint(x: routeX, y: h * 0.09))
                            path.addLine(to: CGPoint(x: routeX, y: h * 0.91))
                        }
                        .stroke(AppTheme.oceanLight, lineWidth: 3)

                        // Bridge crossbar
                        Path { path in
                            path.move(to:    CGPoint(x: routeX - bridgeW, y: h * 0.34))
                            path.addLine(to: CGPoint(x: routeX + bridgeW, y: h * 0.34))
                        }
                        .stroke(bridgeService.level.statusColor, lineWidth: 5)

                        // Location pins
                        IslandPin(name: "Princeville",    icon: "📍", x: rightX, y: h * 0.09, color: AppTheme.success)
                        IslandPin(name: "Hanalei Bridge", icon: "🌉", x: rightX, y: h * 0.33, color: bridgeService.level.statusColor)
                        IslandPin(name: "Kapaa",          icon: "📍", x: rightX, y: h * 0.55, color: AppTheme.warning)
                        IslandPin(name: "Lihue Airport",  icon: "✈️", x: rightX, y: h * 0.75, color: AppTheme.success)
                        IslandPin(name: "Poipu",          icon: "🌺", x: leftX,  y: h * 0.84, color: AppTheme.success)
                        IslandPin(name: "Waimea",         icon: "🏔️", x: leftX,  y: h * 0.66, color: AppTheme.success)
                    }
                }
                .frame(height: 220)
                .clipped()
            }
        }
    }

    // MARK: - Footer
    private var footerNote: some View {
        VStack(spacing: 4) {
            if let updated = bridgeService.lastUpdated {
                Text("Updated: \(updated.formatted(date: .omitted, time: .shortened))")
            }
            Text("USGS Water Services · Site 16103000 · Hanalei River, Kauai")
        }
        .font(.system(size: 11))
        .foregroundColor(AppTheme.textTertiary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 20)
    }
}

// MARK: - Route Row
private struct RouteRow: View {
    let route: KauaiRoute

    var body: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 6) {
                        Image(systemName: route.level.sfSymbol)
                            .font(.system(size: 12))
                        Text(route.level.trafficLabel)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(route.level.statusColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let total = route.delay > 0 ? route.delay + route.estMins : route.estMins
                    if route.level == .closed {
                        Text("CLOSED")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.error)
                    } else {
                        Text("\(total) min")
                            .font(.system(size: 20, weight: .bold))
                        if route.delay > 0 {
                            Text("+\(route.delay) min delay")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.warning)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Island Pin
private struct IslandPin: View {
    let name:  String
    let icon:  String
    let x:     CGFloat
    let y:     CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 14))
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
        .position(x: x, y: y)
    }
}
