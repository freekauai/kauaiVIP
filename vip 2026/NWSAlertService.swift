// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — NWS Alert Service                ║
// ║           NWSAlertService.swift                              ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Fetches official NWS weather alerts for Kauai County via
// the free, public api.weather.gov — no API key required.
//
// Endpoint: GET /alerts/active?area=HI
// Filtered client-side for alerts whose areaDesc mentions Kauai.

import Foundation
import SwiftUI
import Combine

// MARK: - Alert Model
struct NWSAlert: Identifiable {
    let id:          String
    let event:       String
    let headline:    String
    let description: String
    let severity:    String
    let urgency:     String
    let areaDesc:    String
    let onset:       Date?
    let expires:     Date?

    // Visual helpers
    var severityColor: Color {
        switch severity.lowercased() {
        case "extreme":  return Color(hex: "FF3B30")
        case "severe":   return Color(hex: "FF6B35")
        case "moderate": return AppTheme.warning
        default:         return AppTheme.info
        }
    }

    var severityIcon: String {
        switch severity.lowercased() {
        case "extreme":  return "exclamationmark.octagon.fill"
        case "severe":   return "exclamationmark.triangle.fill"
        case "moderate": return "exclamationmark.triangle.fill"
        default:         return "info.circle.fill"
        }
    }

    var isHighPriority: Bool {
        ["extreme", "severe"].contains(severity.lowercased())
    }

    var expiresFormatted: String {
        guard let e = expires else { return "" }
        return "Until " + e.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

// MARK: - Decodable Response
private struct NWSResponse: Decodable {
    let features: [NWSFeature]
}
private struct NWSFeature: Decodable {
    let properties: NWSProperties
}
private struct NWSProperties: Decodable {
    let id:          String?
    let event:       String?
    let headline:    String?
    let description: String?
    let severity:    String?
    let urgency:     String?
    let areaDesc:    String?
    let onset:       String?
    let expires:     String?
    let status:      String?
    let messageType: String?
}

// MARK: - Service
@MainActor
class NWSAlertService: ObservableObject {

    @Published var alerts:      [NWSAlert] = []
    @Published var isLoading:   Bool       = false
    @Published var fetchError:  String?    = nil
    @Published var lastUpdated: Date?      = nil

    /// Number of high-priority (Severe / Extreme) active alerts
    var highPriorityCount: Int { alerts.filter { $0.isHighPriority }.count }
    var hasAlerts: Bool { !alerts.isEmpty }

    private var refreshTimer: Timer?
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Init
    init() {
        Task { await fetchAlerts() }
        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { await self?.fetchAlerts() }
        }
    }
    deinit { refreshTimer?.invalidate() }

    // MARK: - Fetch
    func fetchAlerts() async {
        isLoading  = true
        fetchError = nil

        guard let url = URL(string: "https://api.weather.gov/alerts/active?area=HI") else {
            isLoading = false; return
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("KauaiVIP2026/1.0 (joey@kauaivip.com)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let nwsResponse = try JSONDecoder().decode(NWSResponse.self, from: data)

            // Filter for Kauai — keep only Actual alerts mentioning Kauai in areaDesc
            let kauaiAlerts: [NWSAlert] = nwsResponse.features.compactMap { feature in
                let p = feature.properties
                guard
                    let id       = p.id,
                    let event    = p.event,
                    let area     = p.areaDesc,
                    let status   = p.status,   status == "Actual",
                    let msgType  = p.messageType, msgType != "Cancel",
                    area.localizedCaseInsensitiveContains("kauai")
                else { return nil }

                return NWSAlert(
                    id:          id,
                    event:       event,
                    headline:    p.headline    ?? event,
                    description: p.description ?? "",
                    severity:    p.severity    ?? "Unknown",
                    urgency:     p.urgency     ?? "Unknown",
                    areaDesc:    area,
                    onset:       p.onset.flatMap   { isoFormatter.date(from: $0) },
                    expires:     p.expires.flatMap { isoFormatter.date(from: $0) }
                )
            }

            alerts      = kauaiAlerts
            lastUpdated = Date()
            isLoading   = false

        } catch {
            fetchError = error.localizedDescription
            isLoading  = false
        }
    }

    func refresh() {
        Task { await fetchAlerts() }
    }
}
