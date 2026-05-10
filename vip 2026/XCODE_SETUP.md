# KAUAI VIP 2026 — Xcode Setup Guide

## Step 1 — Create the Project

1. Open **Xcode** → **File → New → Project**
2. Choose **iOS → App**
3. Set:
   - **Product Name:** `KauaiVIP2026`
   - **Bundle ID:** `com.yourname.kauaivip2026`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployment:** iOS 16.0
4. Click **Next** → choose a folder → **Create**

---

## Step 2 — Add the Swift Files

Delete the default `ContentView.swift` that Xcode created.

Then drag all 16 files from this folder into the Xcode project navigator:

```
KauaiVIP2026App.swift        ← App entry point
Theme.swift                  ← Colors, styles, modifiers
Models.swift                 ← Trip, PayPeriod, Vehicle, ServiceType
TimesheetStore.swift         ← Data store + UserDefaults persistence
WeatherManager.swift         ← Open-Meteo weather integration (free, no key)
BridgeService.swift          ← NOAA Hanalei Bridge API
SharedComponents.swift       ← Reusable views (banner, buttons, cards)
ContentView.swift            ← Root router / passcode gate
PasscodeView.swift           ← Passcode screen (KVIP2026)
MainView.swift               ← Home screen with period list
PeriodDetailView.swift       ← Trips list + summary
TripFormView.swift           ← Add / Edit trip form
NewPeriodView.swift          ← Create new pay period
WeatherModalView.swift       ← Weather sheet (Open-Meteo data)
TrafficModalView.swift       ← Traffic sheet (NOAA bridge data)
KauaiMapView.swift           ← Apple Maps with Kauai pins
```

When Xcode asks: ✅ **Copy items if needed** | Target: ✅ **KauaiVIP2026**

---

## Step 3 — No Special Capabilities Needed

Weather is powered by **Open-Meteo** — completely free, no API key, no Apple Developer account required, no entitlements.

> ✅ No WeatherKit capability needed
> ✅ No location permission needed (weather is hardcoded to Lihue Airport coords)
> ✅ No paid developer account required to run weather features

The only network calls the app makes are:
- `api.open-meteo.com` — weather data
- `api.tidesandcurrents.noaa.gov` — Hanalei Bridge water level

Both are free public APIs requiring no credentials.

---

## Step 4 — Select a Simulator or Device

- **Simulator:** iPhone 15 Pro (iOS 17+) works great
- **Device:** Plug in your iPhone → select it from the device menu
- iOS 16.0 minimum required

---

## Step 5 — Build & Run

Press **⌘ + R** or click the ▶ Play button.

Enter passcode: **KVIP2026**

---

## API Reference

| API | Endpoint | Purpose |
|-----|----------|---------|
| Open-Meteo | `api.open-meteo.com/v1/forecast` | Live temperature, wind, conditions, UV, hourly forecast — **free, no key** |
| NOAA Tides & Currents | `api.tidesandcurrents.noaa.gov/api/prod/datagetter?station=1611347` | Hanalei River water level → bridge status |
| Apple Maps (MapKit) | Native `Map` SwiftUI view | Kauai route map with pins + navigation |

---

## Troubleshooting

**Weather shows "unavailable"**
→ Check your internet connection. Open-Meteo requires network access.
→ Try the refresh button (↻) in the weather sheet.

**NOAA returns empty data**
→ Normal outside of tide measurement hours; app shows cached values.

**Map doesn't show traffic overlay**
→ Traffic overlays require iOS 17+; on iOS 16 the standard map still shows.

**Build error on WeatherManager.swift**
→ Make sure you are using the updated WeatherManager.swift (Open-Meteo version).
→ There should be NO `import WeatherKit` anywhere in the project.

---

## Access Code
```
KVIP2026
```

---

*KAUAI VIP 2026 · Driver Timesheet System*
*Built with SwiftUI · Open-Meteo · MapKit · NOAA APIs*
