# 🐛 Weather Debugging Guide

> **Note:** This app uses **Open-Meteo**, not WeatherKit.
> No API key, no entitlement, no Apple Developer account required for weather.

---

## Current Architecture

| Component | Technology | Notes |
|-----------|-----------|-------|
| Weather data | [Open-Meteo](https://open-meteo.com) | Free, no key, works on simulator |
| Marine / surf | Open-Meteo Marine API | Free, same origin |
| Moon phase | Synodic calculation | No API — computed locally |
| Location | Hardcoded Lihue Airport (21.9758, -159.3753) | No CLLocationManager needed |

---

## How to Debug

### Step 1: Check the error banner in the UI
When a fetch fails, the weather hero card shows a red error message instead of the temperature.
The error text comes directly from `URLError.localizedDescription`.

### Step 2: Check network access
Open-Meteo is a free public API — no auth, no rate limits for normal usage.

```
https://api.open-meteo.com/v1/forecast     ← weather
https://marine-api.open-meteo.com/v1/marine ← surf
```

Both must be reachable. Check:
- Device/simulator has internet access
- No corporate VPN or firewall blocking `open-meteo.com`

### Step 3: Try the refresh button
The refresh button (↻) in the weather sheet toolbar triggers a new fetch.
It has a 30-second throttle — rapid taps within that window are silently ignored.

### Step 4: Run on simulator vs real device
Open-Meteo works identically on simulator and real device because it uses hardcoded
coordinates, not GPS. Simulator limitations do **not** affect weather data.

---

## Common Symptoms & Fixes

### "Weather unavailable" error in the UI
- **Cause:** Network request to `api.open-meteo.com` failed
- **Fix:** Check internet connection. Try refreshing.

### All fields show "--" after loading
- **Cause:** Fetch failed before data was applied (error state)
- **Fix:** Check `fetchError` property — it will contain the error message

### Surf fields (wave height, period) show "--"
- **Cause:** Marine API fetch failed (it's separate from the weather fetch)
- **Note:** The marine fetch is fire-and-forget — a marine failure does NOT block weather data

### UV Index shows "--"
- **Cause:** `uv_index` is optional in Open-Meteo; it can be `null` at night or for some locations
- **This is normal** — the advisory logic uses 0 (no UV warning) when unavailable

### Visibility shows "--"
- **Cause:** `visibility` is optional in Open-Meteo response
- **This is normal** for some atmospheric conditions

---

## What Data Comes From Open-Meteo

| Metric | Field in API | Optional? |
|--------|-------------|-----------|
| Temperature | `current.temperature_2m` | No |
| Humidity | `current.relative_humidity_2m` | No |
| Wind speed + direction | `current.wind_speed_10m`, `current.wind_direction_10m` | No |
| Precipitation chance | `current.precipitation_probability` | No |
| Weather code → condition + icon | `current.weather_code` | No |
| Visibility | `current.visibility` | Yes — can be null |
| Dew point | `current.dew_point_2m` | Yes — can be null |
| UV index | `current.uv_index` | Yes — null at night |
| Sunrise / sunset | `daily.sunrise`, `daily.sunset` | No |
| Hourly forecast (6 hours) | `hourly.*` | No |
| Wave height, period, direction | Marine API | Optional — separate fetch |
| Swell height, period | Marine API | Optional — separate fetch |

---

## No Entitlements or Capabilities Needed

The Xcode target entitlements file (`vip 2026.entitlements`) is intentionally **empty**.

- ❌ No WeatherKit capability
- ❌ No location permission (`NSLocationWhenInUseUsageDescription` not required)
- ❌ No paid Apple Developer account required to build/run weather features

> There is a stale `vip-2026.entitlements` inside the `.xcodeproj` folder that still contains
> `com.apple.developer.weatherkit = true`. That file is **not referenced** by the build
> (the build uses `vip 2026/vip 2026.entitlements`). It is safe to ignore.

---

## Quick Checklist

- [ ] Internet connection active
- [ ] App can reach `api.open-meteo.com` (not blocked by firewall/VPN)
- [ ] No `import WeatherKit` anywhere in project source files
- [ ] Using `WeatherManager.swift` (Open-Meteo version) — header should say "Uses Open-Meteo"

---

*Last Updated: May 2026 — migrated from WeatherKit to Open-Meteo*
