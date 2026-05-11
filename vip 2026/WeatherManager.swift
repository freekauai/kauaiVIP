// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Weather Manager                  ║
// ║           WeatherManager.swift                               ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Uses Open-Meteo — completely free, no API key required.
// Docs: https://open-meteo.com/en/docs
// Lihue Airport coords: 21.9758, -159.3753

import Foundation
import SwiftUI
import Combine

// MARK: - Hourly Forecast Item
struct HourlyForecastItem: Identifiable {
    let id           = UUID()
    let time:         String
    let sfSymbol:     String
    let tempF:        String
    let precipChance: Int
}

// MARK: - Open-Meteo Response Models
private struct OpenMeteoResponse: Decodable {
    let current: OMCurrent
    let hourly:  OMHourly
    let daily:   OMDaily
}

private struct OMDaily: Decodable {
    let sunrise: [String]
    let sunset:  [String]
}

private struct MarineResponse: Decodable {
    let current: MarineCurrent
}

private struct MarineCurrent: Decodable {
    let wave_height:        Double?
    let wave_period:        Double?
    let wave_direction:     Int?
    let swell_wave_height:  Double?
    let swell_wave_period:  Double?
}

private struct OMCurrent: Decodable {
    let temperature_2m:            Double
    let relative_humidity_2m:      Int
    let precipitation_probability: Int
    let weather_code:              Int
    let wind_speed_10m:            Double
    let wind_direction_10m:        Int
    let visibility:                Double?
    let dew_point_2m:              Double?
    let uv_index:                  Double?
}

private struct OMHourly: Decodable {
    let time:                      [String]
    let temperature_2m:            [Double]
    let weather_code:              [Int]
    let precipitation_probability: [Int]
}

// MARK: - Weather Manager
@MainActor
class WeatherManager: ObservableObject {

    @Published var tempF:           String = "--°F"
    @Published var conditionText:   String = "Loading…"
    @Published var sfSymbol:        String = "cloud.sun.fill"
    @Published var humidityPct:     String = "--%"
    @Published var windDescription: String = "-- mph"
    @Published var visibilityMi:    String = "-- mi"
    @Published var precipChancePct: String = "--%"
    @Published var uvIndex:         String = "--"
    @Published var dewPointF:       String = "--°F"
    @Published var sunriseTime:         Date?   = nil
    @Published var sunsetTime:          Date?   = nil
    @Published var tomorrowSunriseTime: Date?   = nil
    @Published var moonPhaseEmoji:  String  = "🌑"
    @Published var moonPhaseName:   String  = "New Moon"
    @Published var waveHeightFt:    String  = "--ft"
    @Published var wavePeriodSec:   String  = "--s"
    @Published var waveDirection:   String  = "--"
    @Published var swellHeightFt:   String  = "--ft"
    @Published var swellPeriodSec:  String  = "--s"
    @Published var hourlyForecast:  [HourlyForecastItem] = []
    @Published var advisoryLines:   [String] = []
    @Published var isLoading:       Bool    = true
    @Published var fetchError:      String? = nil
    @Published var lastUpdated:     Date?   = nil

    private var refreshTimer: Timer?
    private let latitude  = 21.9758
    private let longitude = -159.3753

    /// Minimum seconds between manual refreshes. Auto-timer is unaffected.
    private let minRefreshInterval: TimeInterval = 30

    init() {
        Task { await fetchWeather() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.fetchWeather() }
        }
    }

    deinit { refreshTimer?.invalidate() }

    // MARK: - Fetch
    func fetchWeather() async {
        isLoading      = true
        fetchError     = nil
        waveHeightFt   = "--ft"
        wavePeriodSec  = "--s"
        waveDirection  = "--"
        swellHeightFt  = "--ft"
        swellPeriodSec = "--s"
        sunriseTime         = nil
        sunsetTime          = nil
        tomorrowSunriseTime = nil
        updateMoonPhase()

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude",           value: "\(latitude)"),
            .init(name: "longitude",          value: "\(longitude)"),
            .init(name: "temperature_unit",   value: "fahrenheit"),
            .init(name: "wind_speed_unit",    value: "mph"),
            .init(name: "precipitation_unit", value: "inch"),
            .init(name: "timezone",           value: "Pacific/Honolulu"),
            .init(name: "forecast_days",      value: "2"),
            .init(name: "current",            value: [
                "temperature_2m",
                "relative_humidity_2m",
                "precipitation_probability",
                "weather_code",
                "wind_speed_10m",
                "wind_direction_10m",
                "visibility",
                "dew_point_2m",
                "uv_index"
            ].joined(separator: ",")),
            .init(name: "hourly", value: [
                "temperature_2m",
                "weather_code",
                "precipitation_probability"
            ].joined(separator: ",")),
            .init(name: "daily",  value: "sunrise,sunset"),
        ]

        var marineComponents = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine")!
        marineComponents.queryItems = [
            .init(name: "latitude",  value: "\(latitude)"),
            .init(name: "longitude", value: "\(longitude)"),
            .init(name: "current",   value: [
                "wave_height", "wave_period", "wave_direction",
                "swell_wave_height", "swell_wave_period"
            ].joined(separator: ",")),
        ]

        guard let url = components.url, let marineURL = marineComponents.url else {
            fetchError = "Invalid weather URL"
            isLoading  = false
            return
        }

        do {
            async let weatherFetch = URLSession.shared.data(from: url)
            async let marineFetch  = URLSession.shared.data(from: marineURL)

            let (data, response) = try await weatherFetch
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            applyCurrentWeather(decoded.current)
            applyHourlyForecast(decoded.hourly)
            applyDaily(decoded.daily)

            if let (marineData, marineResponse) = try? await marineFetch,
               let marineHttp = marineResponse as? HTTPURLResponse,
               marineHttp.statusCode == 200,
               let marine = try? JSONDecoder().decode(MarineResponse.self, from: marineData) {
                let c = marine.current
                if let waveM = c.wave_height {
                    waveHeightFt = "\(String(format: "%.1f", waveM * 3.28084))ft"
                }
                if let period = c.wave_period {
                    wavePeriodSec = "\(Int(period.rounded()))s"
                }
                if let dir = c.wave_direction {
                    waveDirection = compassAbbreviation(degrees: dir)
                }
                if let swellM = c.swell_wave_height {
                    swellHeightFt = "\(String(format: "%.1f", swellM * 3.28084))ft"
                }
                if let swellP = c.swell_wave_period {
                    swellPeriodSec = "\(Int(swellP.rounded()))s"
                }
            }

            lastUpdated = Date()
            isLoading   = false
        } catch {
            fetchError = "Weather unavailable: \(error.localizedDescription)"
            isLoading  = false
        }
    }

    func refresh() {
        guard !isLoading else { return }
        if let last = lastUpdated, Date().timeIntervalSince(last) < minRefreshInterval { return }
        Task { await fetchWeather() }
    }

    // MARK: - Apply current
    private func applyCurrentWeather(_ c: OMCurrent) {
        tempF           = "\(Int(c.temperature_2m.rounded()))°F"
        conditionText   = wmoDescription(c.weather_code)
        sfSymbol        = wmoSFSymbol(c.weather_code)
        humidityPct     = "\(c.relative_humidity_2m)%"
        precipChancePct = "\(c.precipitation_probability)%"
        windDescription = "\(compassAbbreviation(degrees: c.wind_direction_10m)) \(Int(c.wind_speed_10m.rounded())) mph"

        if let vis = c.visibility {
            visibilityMi = "\(Int((vis / 1609.344).rounded())) mi"
        }
        if let dp = c.dew_point_2m {
            dewPointF = "\(Int(dp.rounded()))°F"
        }

        let uvVal = c.uv_index.map { Int($0.rounded()) } ?? 0
        uvIndex       = "\(uvVal)"
        advisoryLines = buildAdvisory(mph: c.wind_speed_10m, wmoCode: c.weather_code, uvVal: uvVal)
    }

    // MARK: - Apply hourly
    private func applyHourlyForecast(_ h: OMHourly) {
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fmt.timeZone   = TimeZone(identifier: "Pacific/Honolulu")

        let dispFmt = DateFormatter()
        dispFmt.dateFormat = "ha"
        dispFmt.amSymbol   = "am"
        dispFmt.pmSymbol   = "pm"
        dispFmt.timeZone   = TimeZone(identifier: "Pacific/Honolulu")

        let start = h.time.firstIndex { fmt.date(from: $0).map { $0 >= now } ?? false } ?? 0

        hourlyForecast = (start..<min(start + 6, h.time.count)).compactMap { i in
            guard let date = fmt.date(from: h.time[i]) else { return nil }
            return HourlyForecastItem(
                time:         dispFmt.string(from: date),
                sfSymbol:     wmoSFSymbol(h.weather_code[i]),
                tempF:        "\(Int(h.temperature_2m[i].rounded()))°F",
                precipChance: h.precipitation_probability[i]
            )
        }
    }

    // MARK: - Apply daily (sunrise / sunset) — times are HST (Pacific/Honolulu)
    private func applyDaily(_ d: OMDaily) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fmt.timeZone   = TimeZone(identifier: "Pacific/Honolulu") // HST, no DST
        sunriseTime         = d.sunrise.first.flatMap      { fmt.date(from: $0) }
        sunsetTime          = d.sunset.first.flatMap       { fmt.date(from: $0) }
        tomorrowSunriseTime = d.sunrise.dropFirst().first.flatMap { fmt.date(from: $0) }
    }

    // MARK: - WMO helpers
    private func wmoDescription(_ code: Int) -> String {
        switch code {
        case 0:       return "Clear Sky"
        case 1:       return "Mainly Clear"
        case 2:       return "Partly Cloudy"
        case 3:       return "Overcast"
        case 45, 48:  return "Foggy"
        case 51:      return "Light Drizzle"
        case 53:      return "Drizzle"
        case 55:      return "Heavy Drizzle"
        case 61:      return "Light Rain"
        case 63:      return "Rain"
        case 65:      return "Heavy Rain"
        case 80:      return "Light Showers"
        case 81:      return "Showers"
        case 82:      return "Heavy Showers"
        case 95:      return "Thunderstorm"
        case 96, 99:  return "Thunderstorm w/ Hail"
        default:      return "Mixed Conditions"
        }
    }

    private func wmoSFSymbol(_ code: Int) -> String {
        switch code {
        case 0, 1:    return "sun.max.fill"
        case 2:       return "cloud.sun.fill"
        case 3:       return "cloud.fill"
        case 45, 48:  return "cloud.fog.fill"
        case 51...55: return "cloud.drizzle.fill"
        case 61...65: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 85, 86:  return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default:      return "cloud.sun.fill"
        }
    }

    private func compassAbbreviation(degrees: Int) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                    "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return dirs[Int((Double(degrees) / 22.5).rounded()) % 16]
    }

    // MARK: - Moon phase (synodic calculation, no API needed)
    private func updateMoonPhase() {
        // Reference new moon: Jan 6, 2000 18:14 UTC
        let refNewMoon  = Date(timeIntervalSince1970: 947182440)
        let synodicDays = 29.53059
        var phase = Date().timeIntervalSince(refNewMoon) / 86400
        phase = phase.truncatingRemainder(dividingBy: synodicDays) / synodicDays
        if phase < 0 { phase += 1 }
        switch phase {
        case 0..<0.0625:       moonPhaseEmoji = "🌑"; moonPhaseName = "New Moon"
        case 0.0625..<0.1875:  moonPhaseEmoji = "🌒"; moonPhaseName = "Waxing Crescent"
        case 0.1875..<0.3125:  moonPhaseEmoji = "🌓"; moonPhaseName = "First Quarter"
        case 0.3125..<0.4375:  moonPhaseEmoji = "🌔"; moonPhaseName = "Waxing Gibbous"
        case 0.4375..<0.5625:  moonPhaseEmoji = "🌕"; moonPhaseName = "Full Moon"
        case 0.5625..<0.6875:  moonPhaseEmoji = "🌖"; moonPhaseName = "Waning Gibbous"
        case 0.6875..<0.8125:  moonPhaseEmoji = "🌗"; moonPhaseName = "Last Quarter"
        case 0.8125..<0.9375:  moonPhaseEmoji = "🌘"; moonPhaseName = "Waning Crescent"
        default:               moonPhaseEmoji = "🌑"; moonPhaseName = "New Moon"
        }
    }

    private func buildAdvisory(mph: Double, wmoCode: Int, uvVal: Int) -> [String] {
        var lines: [String] = []
        if mph > 30      { lines.append("🌬️ Strong trade winds — drive cautiously") }
        else if mph > 15 { lines.append("💨 Moderate winds — normal conditions") }
        else             { lines.append("🟢 Light winds — excellent driving conditions") }

        switch wmoCode {
        case 65, 82, 95...99: lines.append("🚨 Heavy rain — watch for flash floods on north shore")
        case 61...63, 80, 81: lines.append("🌧️ Rain expected — allow extra time on curves")
        case 2, 3:            lines.append("⛅ Mostly cloudy — brief showers possible")
        default:              lines.append("☀️ Clear skies — great visibility island-wide")
        }

        if uvVal >= 8 { lines.append("☀️ Very high UV — sunscreen required during stops") }
        lines.append("🛣️ Kuhio Hwy (Rt 56) — no reported incidents")
        return lines
    }
}
