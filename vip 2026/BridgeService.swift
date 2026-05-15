// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — NOAA Bridge & Traffic Service    ║
// ║           BridgeService.swift                                ║
// ╚══════════════════════════════════════════════════════════════╝
//
// NOAA Tides & Currents — station 1611347 (Hanalei, Kauai)
// Bridge thresholds:
//   < 5.0 ft  →  OPEN   / Normal
//   5.0–7.0   →  1-LANE / Caution
//   > 7.0 ft  →  CLOSED / Severe

import Foundation
import SwiftUI
import Combine

// MARK: - Bridge Status Level
enum BridgeLevel: String {
    case normal  = "Normal"
    case caution = "Caution"
    case closed  = "Closed"

    var statusColor: Color {
        switch self {
        case .normal:  return AppTheme.success
        case .caution: return AppTheme.warning
        case .closed:  return AppTheme.error
        }
    }
    var trafficLabel: String {
        switch self {
        case .normal:  return "Normal"
        case .caution: return "Heavy"
        case .closed:  return "Severe"
        }
    }
    var bridgeLabel: String {
        switch self {
        case .normal:  return "Open"
        case .caution: return "1-Lane"
        case .closed:  return "CLOSED"
        }
    }
    var bannerIcon: String {
        switch self {
        case .normal:  return "🚦"
        case .caution: return "⚠️"
        case .closed:  return "🚨"
        }
    }
    var sfSymbol: String {
        switch self {
        case .normal:  return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .closed:  return "xmark.octagon.fill"
        }
    }
}

// MARK: - NOAA Response Models
private struct NOAAResponse: Decodable {
    let data:  [NOAAReading]?
    let error: NOAAError?
}
private struct NOAAReading: Decodable {
    let t: String
    let v: String
    let s: String?
    let f: String?
    let q: String?
}
private struct NOAAError: Decodable {
    let message: String
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
    static let cautionFt: Double = 5.0   // < cautionFt  → Normal / Open
    static let closedFt:  Double = 7.0   // ≥ closedFt   → Closed
    static let gaugeFt:   Double = 10.0  // visual gauge maximum

    @Published var bridgeStatus: String      = "Open"
    @Published var trafficLevel: String      = "Normal"
    @Published var level:        BridgeLevel = .normal
    @Published var waterLevelFt: String      = "N/A"
    @Published var rawWaterFt:   Double?     = nil
    @Published var routes:       [KauaiRoute] = kDefaultRoutes
    @Published var isLoading:    Bool         = true
    @Published var fetchError:   String?      = nil
    @Published var lastUpdated:  Date?        = nil

    // MARK: Gauge helpers (consumed by views)
    var gaugePct: Double {
        guard let raw = rawWaterFt else { return 0 }
        return min(raw / BridgeService.gaugeFt, 1.0)
    }
    var gaugeColor: Color {
        guard let raw = rawWaterFt else { return AppTheme.success }
        return raw >= BridgeService.closedFt  ? AppTheme.error
             : raw >= BridgeService.cautionFt ? AppTheme.warning
             : AppTheme.success
    }

    private let stationID = "1611347"
    private var refreshTimer: Timer?

    /// Minimum seconds between manual refreshes. Auto-timer is unaffected.
    private let minRefreshInterval: TimeInterval = 30

    // MARK: - Init
    init() {
        Task { await fetchBridgeStatus() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { await self?.fetchBridgeStatus() }
        }
    }

    deinit { refreshTimer?.invalidate() }

    // MARK: - Fetch
    func fetchBridgeStatus() async {
        isLoading  = true
        fetchError = nil

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyyMMdd"
        let today = dateFmt.string(from: Date())

        guard var components = URLComponents(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter") else {
            isLoading = false
            return
        }
        components.queryItems = [
            .init(name: "product",    value: "water_level"),
            .init(name: "station",    value: stationID),
            .init(name: "datum",      value: "MLLW"),
            .init(name: "time_zone",  value: "lst_ldt"),
            .init(name: "units",      value: "english"),
            .init(name: "format",     value: "json"),
            .init(name: "begin_date", value: today),
            .init(name: "end_date",   value: today),
            .init(name: "interval",   value: "h"),
        ]

        guard let url = components.url else { isLoading = false; return }

        do {
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("KauaiVIP2026/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let noaaResponse = try JSONDecoder().decode(NOAAResponse.self, from: data)

            // NOAA returns an error object when data is unavailable (e.g. outside measurement hours).
            // Treat this as "no data" rather than a hard failure so the app degrades gracefully.
            if noaaResponse.error != nil {
                waterLevelFt = "Unavailable"
                lastUpdated  = Date()
                isLoading    = false
                return
            }

            guard let readings = noaaResponse.data,
                  let latest   = readings.last(where: { !$0.v.trimmingCharacters(in: .whitespaces).isEmpty }),
                  let wl       = Double(latest.v) else {
                // Station has no recent readings — show a neutral state, not an error.
                waterLevelFt = "Unavailable"
                lastUpdated  = Date()
                isLoading    = false
                return
            }

            rawWaterFt   = wl
            waterLevelFt = String(format: "%.2f ft", wl)
            applyThreshold(wl)
            lastUpdated  = Date()
            isLoading    = false

        } catch {
            // Network failure — degrade silently; don't surface a raw error string.
            waterLevelFt = "Unavailable"
            isLoading    = false
        }
    }

    func refresh() {
        guard !isLoading else { return }
        if let last = lastUpdated, Date().timeIntervalSince(last) < minRefreshInterval { return }
        Task { await fetchBridgeStatus() }
    }

    // MARK: - Threshold logic
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
