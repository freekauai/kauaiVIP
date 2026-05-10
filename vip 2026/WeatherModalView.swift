// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Weather Modal                    ║
// ║           WeatherModalView.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

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

                        // ── Data Sources ────────────────────────────────
                        footerNote
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("☀️ Kauai Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0d2137"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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

                Text("Source: Open-Meteo Marine · North Pacific swell")
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
            Text("Weather: Open-Meteo · Surf: Open-Meteo Marine · Moon: computed")
        }
        .font(.system(size: 11))
        .foregroundColor(AppTheme.textTertiary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 20)
    }
}
