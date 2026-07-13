// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Weather Modal                    ║
// ║           WeatherModalView.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import MapKit

// MARK: - Condition Item
private struct ConditionItem: Identifiable {
    let id:    String   // label — stable and unique within the conditions grid
    let icon:  String
    let value: String
}

struct WeatherModalView: View {
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var bridgeService:  BridgeService
    @Environment(\.dismiss) var dismiss

    @State private var showSurfMap = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0d2137"), AppTheme.oceanDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {

                        // ── Hero Current Weather ────────────────────────
                        heroCard

                        // ── Per-shore Town Temps (4-way split) ──────────
                        if !weatherManager.townTemps.isEmpty {
                            townTempsCard
                        }

                        // ── Hourly Forecast ─────────────────────────────
                        if !weatherManager.hourlyForecast.isEmpty {
                            hourlyCard
                        }

                        // ── Moon Phase ──────────────────────────────────
                        moonCard

                        // ── Surf Conditions ─────────────────────────────
                        surfCard

                        // ── Conditions Grid ─────────────────────────────
                        conditionsGrid

                        // ── Hanalei Bridge ──────────────────────────────
                        bridgeCard

                        // ── Driver Advisory ─────────────────────────────
                        if !weatherManager.advisoryLines.isEmpty {
                            advisoryCard
                        }

                        // ── Where's the Surf? (per-spot map) ─────────────
                        CoralButton("🏄 Where's the Surf?") { showSurfMap = true }

                        // ── Data Sources ────────────────────────────────
                        footerNote
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.top, 8)
                }
            }
            .sheet(isPresented: $showSurfMap) {
                SurfSpotsMapView()
            }
            .navigationTitle("☀️ Kauai Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0d2137"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)   // navy bar → keep title legible in light theme
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        weatherManager.refresh()
                        bridgeService.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.coral)
                    }
                }
            }
        }
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        AppCard {
            VStack(spacing: 12) {
                if weatherManager.isLoading {
                    ProgressView().tint(AppTheme.coral)
                } else if let err = weatherManager.fetchError {
                    Text(err)
                        .foregroundColor(AppTheme.error)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                } else {
                    WeatherIcon(symbolName: weatherManager.sfSymbol, size: 60)

                    Text(weatherManager.tempF)
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(weatherManager.conditionText)
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.textSecondary)

                    Label("Lihue, Kauai", systemImage: "location.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.coral)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Town Temps Card (split into 4 equal quarters)
    private var townTempsCard: some View {
        AppCard(padding: 0) {
            HStack(spacing: 0) {
                ForEach(Array(weatherManager.townTemps.enumerated()), id: \.element.id) { idx, town in
                    VStack(spacing: 4) {
                        Text(town.tempF)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(town.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)   // each town = 1/4 of the card
                    .padding(.vertical, 16)

                    if idx < weatherManager.townTemps.count - 1 {
                        Divider().frame(height: 40).background(AppTheme.oceanLight)
                    }
                }
            }
        }
    }

    // MARK: - Hourly Card
    private var hourlyCard: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("HOURLY FORECAST")
                    .labelStyle()
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                Divider().background(AppTheme.oceanLight)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(weatherManager.hourlyForecast) { item in
                            VStack(spacing: 8) {
                                Text(item.time)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textTertiary)
                                WeatherIcon(symbolName: item.sfSymbol, size: 26)
                                Text(item.tempF)
                                    .font(.system(size: 14, weight: .semibold))
                                if item.precipChance > 10 {
                                    Text("\(item.precipChance)%")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.info)
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: - Conditions Grid
    private var conditionsGrid: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("CONDITIONS").labelStyle()

                let items: [ConditionItem] = [
                    .init(id: "Humidity",    icon: "humidity.fill",      value: weatherManager.humidityPct),
                    .init(id: "Wind",        icon: "wind",               value: weatherManager.windDescription),
                    .init(id: "Visibility",  icon: "eye.fill",           value: weatherManager.visibilityMi),
                    .init(id: "Rain Chance", icon: "drop.fill",          value: weatherManager.precipChancePct),
                    .init(id: "UV Index",    icon: "sun.max.fill",       value: weatherManager.uvIndex),
                    .init(id: "Dew Point",   icon: "thermometer.medium", value: weatherManager.dewPointF),
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.coral)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.id)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textTertiary)
                                Text(item.value)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Moon Card
    private var moonCard: some View {
        AppCard {
            HStack(spacing: 16) {
                Text(weatherManager.moonPhaseEmoji)
                    .font(.system(size: 44))

                VStack(alignment: .leading, spacing: 4) {
                    Text("MOON PHASE").labelStyle()
                    Text(weatherManager.moonPhaseName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Kauai, Hawaii")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textTertiary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Surf Card
    private var surfCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("🌊 SURF CONDITIONS").labelStyle()

                let items: [ConditionItem] = [
                    .init(id: "Wave Height",   icon: "waveform",              value: weatherManager.waveHeightFt),
                    .init(id: "Wave Period",   icon: "clock.fill",            value: weatherManager.wavePeriodSec),
                    .init(id: "Direction",     icon: "arrow.up.circle.fill",  value: weatherManager.waveDirection),
                    .init(id: "Swell Height",  icon: "waveform.path",         value: weatherManager.swellHeightFt),
                    .init(id: "Swell Period",  icon: "timer",                 value: weatherManager.swellPeriodSec),
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "4FC3F7"))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.id)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textTertiary)
                                Text(item.value)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                }

                Text("Source: Open-Meteo Marine API · North Pacific swell")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
    }

    // MARK: - Bridge Card
    private var bridgeCard: some View {
        AppCard {
            HStack(spacing: 14) {
                Image(systemName: bridgeService.level.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(bridgeService.level.statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("HANALEI BRIDGE").labelStyle()
                    Text(bridgeService.bridgeStatus)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(bridgeService.level.statusColor)
                    HStack(spacing: 12) {
                        Text("Traffic: \(bridgeService.trafficLevel)")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                        if bridgeService.waterLevelFt != "N/A" {
                            Text("River: \(bridgeService.waterLevelFt)")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(bridgeService.level.statusColor.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Advisory Card
    private var advisoryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("🚗 DRIVER ADVISORY").labelStyle()
                ForEach(weatherManager.advisoryLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Footer
    private var footerNote: some View {
        VStack(spacing: 4) {
            if let updated = weatherManager.lastUpdated {
                Text("Updated: \(updated.formatted(date: .omitted, time: .shortened))")
            }
            Text("Weather & Surf: Open-Meteo · Moon: computed")
        }
        .font(.system(size: 11))
        .foregroundColor(AppTheme.textTertiary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 20)
    }
}

// MARK: - Surf Spot Model
struct SurfSpot: Identifiable, Hashable {
    let id = UUID()
    let name:  String
    let shore: String
    let coord: CLLocationCoordinate2D

    static func == (l: SurfSpot, r: SurfSpot) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// Per-spot surf reading (formatted, ready to display).
struct SurfReading {
    let waveHeightFt:   String
    let wavePeriodSec:  String
    let waveDirection:  String
    let swellHeightFt:  String
    let swellPeriodSec: String
    let waveFeet:       Double?   // numeric, for the map pill
}

// Open-Meteo Marine decodables (local to this file)
private struct SpotMarineResponse: Decodable { let current: SpotMarineCurrent }
private struct SpotMarineCurrent: Decodable {
    let wave_height:       Double?
    let wave_period:       Double?
    let wave_direction:    Double?   // Double (not Int) — Open-Meteo may return a decimal heading
    let swell_wave_height: Double?
    let swell_wave_period: Double?
}

private func surfCompass(_ deg: Int) -> String {
    let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                "S","SSW","SW","WSW","W","WNW","NW","NNW"]
    return dirs[Int((Double(deg) / 22.5).rounded()) % 16]
}

// MARK: - Where's the Surf? — per-spot map
struct SurfSpotsMapView: View {
    @Environment(\.dismiss) var dismiss

    @State private var readings:   [UUID: SurfReading] = [:]
    @State private var selected:   SurfSpot? = nil
    @State private var isLoading   = true
    @State private var loadFailed  = false

    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 22.05, longitude: -159.50),
                           span:   MKCoordinateSpan(latitudeDelta: 0.7, longitudeDelta: 0.7)))

    // Top Kauai surf spots — one+ per shore.
    private let spots: [SurfSpot] = [
        SurfSpot(name: "Hanalei Bay",  shore: "North Shore", coord: .init(latitude: 22.2050, longitude: -159.5030)),
        SurfSpot(name: "Tunnels",      shore: "North Shore", coord: .init(latitude: 22.2235, longitude: -159.5660)),
        SurfSpot(name: "Polihale",     shore: "West Side",   coord: .init(latitude: 22.0850, longitude: -159.7610)),
        SurfSpot(name: "PK's / Poipu", shore: "South Shore", coord: .init(latitude: 21.8740, longitude: -159.4600)),
        SurfSpot(name: "Shipwrecks",   shore: "South Shore", coord: .init(latitude: 21.8710, longitude: -159.4360)),
        SurfSpot(name: "Kalapaki",     shore: "East Side",   coord: .init(latitude: 21.9570, longitude: -159.3520)),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, selection: $selected) {
                    ForEach(spots) { spot in
                        Annotation(spot.name, coordinate: spot.coord, anchor: .bottom) {
                            pin(for: spot)
                        }
                        .tag(spot)
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)

                // ── Bottom overlay ───────────────────────────────────
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Loading surf…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
                } else if loadFailed {
                    VStack(spacing: 6) {
                        Image(systemName: "wifi.exclamationmark").font(.system(size: 22))
                        Text("Couldn't load surf data")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Check your connection and tap to retry.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .foregroundColor(.white)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 40)
                    .onTapGesture { Task { await loadAll() } }
                } else if let spot = selected {
                    detailCard(spot)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom))
                } else if !topThree.isEmpty {
                    topThreeCard
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring(response: 0.3), value: selected?.id)
            .navigationTitle("🏄 Where's the Surf?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
            .task { await loadAll() }
        }
    }

    // MARK: Ranking (biggest surf first)
    /// Spots that have a wave reading, sorted by wave height descending.
    private var ranked: [SurfSpot] {
        spots
            .filter { readings[$0.id]?.waveFeet != nil }
            .sorted { (readings[$0.id]?.waveFeet ?? 0) > (readings[$1.id]?.waveFeet ?? 0) }
    }
    private var topThree: [SurfSpot] { Array(ranked.prefix(3)) }
    /// 1-based rank for the top three; nil for everything else.
    private func rank(of spot: SurfSpot) -> Int? {
        topThree.firstIndex { $0.id == spot.id }.map { $0 + 1 }
    }

    // MARK: Map pin
    @ViewBuilder
    private func pin(for spot: SurfSpot) -> some View {
        let isSel = selected?.id == spot.id
        let rankNum = rank(of: spot)
        let diameter: CGFloat = isSel ? 46 : (rankNum != nil ? 40 : 30)
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(rankNum != nil ? AppTheme.coral : Color(hex: "0288D1"))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                if let rankNum {
                    Text("\(rankNum)")
                        .font(.system(size: isSel ? 22 : 18, weight: .black))
                        .foregroundColor(.white)
                } else {
                    Text("🏄").font(.system(size: 14))
                }
            }
            Text(readings[spot.id]?.waveHeightFt ?? "—")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color(hex: "0277BD"))
                .cornerRadius(4)
        }
        .onTapGesture { selected = isSel ? nil : spot }
    }

    // MARK: Top-3 ranked card (open by default)
    private var topThreeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("🏆 TOP SURF SPOTS")
                .labelStyle()
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            ForEach(Array(topThree.enumerated()), id: \.element.id) { idx, spot in
                let r = readings[spot.id]
                Button { selected = spot } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.coral).frame(width: 28, height: 28)
                            Text("\(idx + 1)").font(.system(size: 15, weight: .black)).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spot.name).font(.system(size: 15, weight: .bold)).foregroundColor(AppTheme.textPrimary)
                            Text(spot.shore).font(.system(size: 12)).foregroundColor(AppTheme.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(r?.waveHeightFt ?? "—").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "4FC3F7"))
                            Text("swell \(r?.swellHeightFt ?? "—")").font(.system(size: 11)).foregroundColor(AppTheme.textTertiary)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                if idx < topThree.count - 1 {
                    Divider().background(AppTheme.oceanLight).padding(.leading, 56)
                }
            }
            Color.clear.frame(height: 34)   // clear the home indicator (card ignores bottom safe area)
        }
        .background(AppTheme.oceanMedium)
        .clipCorners(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.4), radius: 20, y: -5)
    }

    // MARK: Detail card
    private func detailCard(_ spot: SurfSpot) -> some View {
        let r = readings[spot.id]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spot.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(spot.shore)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                Button { selected = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(16)

            Divider().background(AppTheme.oceanLight)

            if let r {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    surfStat("Wave Height",  r.waveHeightFt,  "waveform")
                    surfStat("Wave Period",  r.wavePeriodSec, "clock.fill")
                    surfStat("Direction",    r.waveDirection, "arrow.up.circle.fill")
                    surfStat("Swell",        r.swellHeightFt, "waveform.path")
                    surfStat("Swell Period", r.swellPeriodSec,"timer")
                }
                .padding(16)
            } else {
                Text(isLoading ? "Loading surf data…" : "Surf data unavailable for this spot.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(16)
            }

            Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coord))
                item.name = spot.name
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } label: {
                Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.coral)
                    .cornerRadius(AppTheme.buttonRadius)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 34)   // clear the home indicator (card ignores bottom safe area)
        }
        .background(AppTheme.oceanMedium)
        .clipCorners(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.4), radius: 20, y: -5)
    }

    private func surfStat(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "4FC3F7"))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).foregroundColor(AppTheme.textTertiary)
                Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
        }
    }

    // MARK: Fetch (one Open-Meteo Marine call per spot, concurrently)
    @MainActor
    private func loadAll() async {
        isLoading  = true
        loadFailed = false
        var fresh: [UUID: SurfReading] = [:]
        await withTaskGroup(of: (UUID, SurfReading?).self) { group in
            for spot in spots {
                group.addTask { (spot.id, await Self.fetch(spot.coord)) }
            }
            for await (id, reading) in group {
                if let reading { fresh[id] = reading }
            }
        }
        readings   = fresh
        isLoading  = false
        loadFailed = fresh.isEmpty
        #if DEBUG
        print("🏄 surf map: \(fresh.count)/\(spots.count) spots loaded")
        #endif
    }

    private static func fetch(_ c: CLLocationCoordinate2D) async -> SurfReading? {
        guard var comp = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine") else { return nil }
        comp.queryItems = [
            .init(name: "latitude",  value: "\(c.latitude)"),
            .init(name: "longitude", value: "\(c.longitude)"),
            .init(name: "current",   value: ["wave_height","wave_period","wave_direction",
                                             "swell_wave_height","swell_wave_period"].joined(separator: ",")),
        ]
        guard let url = comp.url else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                #if DEBUG
                print("🏄 surf fetch \(c.latitude),\(c.longitude): HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                #endif
                return nil
            }
            let decoded = try JSONDecoder().decode(SpotMarineResponse.self, from: data)
            let cur = decoded.current
            func ft(_ m: Double?) -> String { m.map { String(format: "%.1fft", $0 * 3.28084) } ?? "—" }
            return SurfReading(
                waveHeightFt:   ft(cur.wave_height),
                wavePeriodSec:  cur.wave_period.map { "\(Int($0.rounded()))s" } ?? "—",
                waveDirection:  cur.wave_direction.map { surfCompass(Int($0.rounded())) } ?? "—",
                swellHeightFt:  ft(cur.swell_wave_height),
                swellPeriodSec: cur.swell_wave_period.map { "\(Int($0.rounded()))s" } ?? "—",
                waveFeet:       cur.wave_height.map { $0 * 3.28084 }
            )
        } catch {
            #if DEBUG
            print("🏄 surf fetch \(c.latitude),\(c.longitude) failed: \(error)")
            #endif
            return nil
        }
    }
}
