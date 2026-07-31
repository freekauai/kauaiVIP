// ╔══════════════════════════════════════════════════════════════╗
// ║           RUNSHEET — USGS Bridge & Traffic Service          ║
// ║           BridgeService.swift                                ║
// ╚══════════════════════════════════════════════════════════════╝
//
// USGS Water Services — site 16103000 (Hanalei River nr Hanalei, Kauai).
// Replaced NOAA station 1611347, which is Port Allen on the SOUTH shore and
// offers no real-time water level — so the bridge status was never live.
// Bridge thresholds (river stage — advisory heuristics, see constants):
//   < 6.0 ft  →  OPEN   / Normal
//   6.0–9.0   →  1-LANE / Caution
//   ≥ 9.0 ft  →  CLOSED / Severe

import Foundation
import SwiftUI
import Combine

// MARK: - Bridge Status Level
enum BridgeLevel: String {
    case unknown = "Unknown"   // no live gauge reading — never claim "Open"
    case normal  = "Normal"
    case caution = "Caution"
    case closed  = "Closed"

    var statusColor: Color {
        switch self {
        case .unknown: return AppTheme.textTertiary
        case .normal:  return AppTheme.success
        case .caution: return AppTheme.warning
        case .closed:  return AppTheme.error
        }
    }
    var trafficLabel: String {
        switch self {
        case .unknown: return "—"
        case .normal:  return "Normal"
        case .caution: return "Heavy"
        case .closed:  return "Severe"
        }
    }
    var bridgeLabel: String {
        switch self {
        case .unknown: return "Status unavailable"
        case .normal:  return "Open"
        case .caution: return "1-Lane"
        case .closed:  return "CLOSED"
        }
    }
    var bannerIcon: String {
        switch self {
        case .unknown: return "❓"
        case .normal:  return "🚦"
        case .caution: return "⚠️"
        case .closed:  return "🚨"
        }
    }
    var sfSymbol: String {
        switch self {
        case .unknown: return "questionmark.circle.fill"
        case .normal:  return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .closed:  return "xmark.octagon.fill"
        }
    }
}

// MARK: - USGS Instantaneous Values Response Models
// waterservices.usgs.gov/nwis/iv — gage height (parameter 00065), feet.
private struct USGSResponse: Decodable {
    struct Value: Decodable {
        struct TimeSeries: Decodable {
            struct Values: Decodable {
                struct Reading: Decodable {
                    let value:    String
                    let dateTime: String
                }
                let value: [Reading]
            }
            let values: [Values]
        }
        let timeSeries: [TimeSeries]
    }
    let value: Value
}

// MARK: - Route Info
struct KauaiRoute: Identifiable {
    let id       = UUID()
    let name:    String
    let from:    String
    let to:      String
    let estMins: Int
    var level:   BridgeLevel = .normal
    var delay:   Int         = 0
}

// MARK: - Default Routes (file-level constant, avoids Self reference error)
private let kDefaultRoutes: [KauaiRoute] = [
    KauaiRoute(name: "Lihue → Kapaa",        from: "Lihue",       to: "Kapaa",       estMins: 18),
    KauaiRoute(name: "Kapaa → Princeville",   from: "Kapaa",       to: "Princeville", estMins: 28),
    KauaiRoute(name: "Princeville → Hanalei", from: "Princeville", to: "Hanalei",     estMins: 8),
    KauaiRoute(name: "Hanalei → End of Rd",   from: "Hanalei",     to: "End of Road", estMins: 12),
    KauaiRoute(name: "Lihue Airport → Poipu", from: "Airport",     to: "Poipu",       estMins: 22),
    KauaiRoute(name: "Kapaa → Waimea",        from: "Kapaa",       to: "Waimea",      estMins: 45),
]

// MARK: - Bridge Service
@MainActor
class BridgeService: ObservableObject {

    // MARK: Threshold constants (single source of truth)
    // Tuned to the USGS Hanalei River gauge (16103000), where normal flow sits
    // near 0–2 ft. Heuristic — the exact bridge-closure stage is not published
    // in a machine-readable feed, so treat these as advisory, not authoritative.
    static let cautionFt: Double = 6.0   // < cautionFt  → Normal / Open
    static let closedFt:  Double = 9.0   // ≥ closedFt   → Closed (flood stage)
    static let gaugeFt:   Double = 12.0  // visual gauge maximum

    @Published var bridgeStatus: String      = BridgeLevel.unknown.bridgeLabel
    @Published var trafficLevel: String      = BridgeLevel.unknown.trafficLabel
    @Published var level:        BridgeLevel = .unknown
    @Published var waterLevelFt: String      = "N/A"
    @Published var rawWaterFt:   Double?     = nil
    @Published var routes:       [KauaiRoute] = kDefaultRoutes
    @Published var isLoading:    Bool         = true
    @Published var fetchError:   String?      = nil
    @Published var lastUpdated:  Date?        = nil

    // MARK: Gauge helpers (consumed by views)
    var gaugePct: Double {
        guard let raw = rawWaterFt else { return 0 }
        // Clamp to 0…1 — the gauge can report slightly negative stage.
        return max(0, min(raw / BridgeService.gaugeFt, 1.0))
    }
    var gaugeColor: Color {
        guard let raw = rawWaterFt else { return AppTheme.success }
        return raw >= BridgeService.closedFt  ? AppTheme.error
             : raw >= BridgeService.cautionFt ? AppTheme.warning
             : AppTheme.success
    }

    private let stationID = "16103000"   // USGS — Hanalei River nr Hanalei, Kauai
    private var refreshTimer: Timer?

    /// Minimum seconds between manual refreshes. Auto-timer is unaffected.
    private let minRefreshInterval: TimeInterval = 30

    // MARK: - Init
    init() {
        Task { await fetchBridgeStatus() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isLoading else { return }   // don't overlap an in-flight retry chain
                await self.fetchBridgeStatus()
            }
        }
    }

    deinit { refreshTimer?.invalidate() }

    // MARK: - Fetch (public entry point)
    func fetchBridgeStatus() async {
        await fetchWithRetry(attempt: 0)
    }

    // MARK: - Fetch with exponential back-off (max 3 retries)
    /// Retries on network errors; missing/sentinel readings mark the
    /// status unavailable immediately (no point retrying a dry gauge).
    /// Delays: 1 s → 2 s → 4 s before giving up.
    private func fetchWithRetry(attempt: Int) async {
        // Only reset loading/error on the first attempt
        if attempt == 0 {
            isLoading  = true
            fetchError = nil
        }

        guard var components = URLComponents(string: "https://waterservices.usgs.gov/nwis/iv/") else {
            isLoading = false
            return
        }
        components.queryItems = [
            .init(name: "format",      value: "json"),
            .init(name: "sites",       value: stationID),
            .init(name: "parameterCd", value: "00065"),   // gage height, feet
            .init(name: "siteStatus",  value: "all"),
        ]

        guard let url = components.url else { isLoading = false; return }

        do {
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("KauaiVIP2026/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let usgs = try JSONDecoder().decode(USGSResponse.self, from: data)

            // Latest VALID gage-height reading — skip back past empty values and
            // -999999-style sentinels (USGS marks gaps that way), so one bad
            // trailing interval doesn't wipe out a payload full of good data.
            guard let readings = usgs.value.timeSeries.first?.values.first?.value,
                  let wl = readings.reversed().compactMap({ Double($0.value) })
                      .first(where: { (-100.0..<100.0).contains($0) }) else {
                // No usable reading — say so rather than implying the bridge is open.
                markUnavailable()
                return
            }

            rawWaterFt   = wl
            // Tide influence can pull the gauge slightly negative; showing
            // "-0.01 ft" reads like a glitch, so floor the display at zero.
            waterLevelFt = String(format: "%.2f ft", max(0, wl))
            applyThreshold(wl)
            lastUpdated  = Date()
            isLoading    = false

        } catch {
            // Network / decode failure — retry with back-off.
            if attempt < 3 {
                let delaySec = pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
                await fetchWithRetry(attempt: attempt + 1)
            } else {
                markUnavailable()
            }
        }
    }

    func refresh() {
        guard !isLoading else { return }
        if let last = lastUpdated, Date().timeIntervalSince(last) < minRefreshInterval { return }
        Task { await fetchBridgeStatus() }
    }

    // MARK: - Threshold logic
    /// No live reading — surface an explicit unknown state instead of leaving
    /// the optimistic "Open / Normal" defaults on screen.
    private func markUnavailable() {
        rawWaterFt   = nil
        waterLevelFt = "Unavailable"
        level        = .unknown
        bridgeStatus = level.bridgeLabel
        trafficLevel = level.trafficLabel
        updateRoutes(level: .normal)   // no delay data — keep base route times
        lastUpdated  = Date()
        isLoading    = false
    }

    private func applyThreshold(_ wl: Double) {
        switch wl {
        case ..<BridgeService.cautionFt:                                        level = .normal
        case BridgeService.cautionFt..<BridgeService.closedFt:                 level = .caution
        default:                                                                 level = .closed
        }
        bridgeStatus = level.bridgeLabel
        trafficLevel = level.trafficLabel
        updateRoutes(level: level)
    }

    private func updateRoutes(level: BridgeLevel) {
        routes = routes.map { var r = $0
            if r.name.contains("Princeville") || r.name.contains("Hanalei") {
                r.level = level
                r.delay = level == .caution ? 15 : (level == .closed ? 999 : 0)
            } else {
                r.level = .normal
                r.delay = 0
            }
            return r
        }
    }
}
