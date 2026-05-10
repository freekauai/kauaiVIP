# 🐛 Weather Data Debugging Guide

## Issue: Missing UV Index, Visibility, and Humidity

### What I've Added

#### 1. **Debug Logging** in `WeatherManager.swift`
When weather is fetched, you'll now see console output like:
```
🌤️ Weather fetched successfully
   Temperature: 82.0°F
   Condition: Partly Cloudy
   Humidity: 0.68
   UV Index: UVIndex(value: 7, category: .high)
   Visibility: 10.0 mi
   Wind: 12.5 mph
```

#### 2. **Better Error Handling**
- Shows "--" or "N/A" when data is unavailable
- Prints warnings in console when specific metrics are missing
- Error state display in UI

#### 3. **Loading States**
- Shows spinner while fetching weather
- Shows error message if fetch fails

---

## How to Debug

### Step 1: Check the Xcode Console
After opening the weather page, look for these messages:

**✅ Success:**
```
🌤️ Weather fetched successfully
```

**❌ Failure:**
```
❌ Weather fetch error: [error details]
```

**⚠️ Missing Data:**
```
⚠️ Humidity unavailable
⚠️ UV Index unavailable
⚠️ Visibility unavailable
```

### Step 2: Verify WeatherKit Capability
1. **Xcode** → Select project → Target → **Signing & Capabilities**
2. Verify **WeatherKit** is listed
3. If not, click **+ Capability** → Add **WeatherKit**

### Step 3: Check Apple Developer Portal
1. Go to [developer.apple.com](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. Select your App ID
4. Verify **WeatherKit** is ✅ enabled
5. If changed, regenerate provisioning profile in Xcode

### Step 4: Check Location Permissions
1. Run the app
2. When prompted, allow location access
3. Or: Settings → Your App → Location → "While Using"

### Step 5: Test on Real Device
WeatherKit can behave differently on simulators vs real devices:
- **Simulator**: May have limited/cached data
- **Real Device**: Full live weather data

---

## Common Causes

### 1. **WeatherKit Not Enabled**
**Symptom:** JWT authentication error  
**Fix:** Enable WeatherKit in Developer Portal + Xcode

### 2. **No Location Permission**
**Symptom:** Shows "--" for all values  
**Fix:** Grant location permission in Settings

### 3. **Network Issues**
**Symptom:** "Weather unavailable" error  
**Fix:** Check internet connection

### 4. **Simulator Limitations**
**Symptom:** Partial data available  
**Fix:** Test on real device

### 5. **Data Not Available from WeatherKit**
**Symptom:** Console shows specific metrics unavailable  
**Fix:** This is normal for some locations/conditions

---

## What Data Comes From WeatherKit

| Metric | Always Available? | Notes |
|--------|-------------------|-------|
| Temperature | ✅ Yes | Core metric |
| Condition | ✅ Yes | Core metric |
| Wind | ✅ Yes | Speed + direction |
| Humidity | ⚠️ Usually | May be unavailable in rare cases |
| UV Index | ⚠️ Usually | Depends on time of day |
| Visibility | ⚠️ Usually | May not be available everywhere |
| Moon Phase | ✅ Yes | From daily forecast |

---

## Expected Console Output

### Successful Weather Fetch:
```
🌤️ Weather fetched successfully
   Temperature: 82.0°F
   Condition: Partly Cloudy
   Humidity: 0.68
   UV Index: UVIndex(value: 7, category: .high)
   Visibility: Measurement<UnitLength>(value: 16093.44, unit: m)
   Wind: 12.5 mph

🌤️ Weather fetched successfully (for Poipu)
🌤️ Weather fetched successfully (for Hanalei)
🌤️ Weather fetched successfully (for Kokee)
```

### Missing Data:
```
🌤️ Weather fetched successfully
   [data shown]
⚠️ UV Index unavailable
⚠️ Visibility unavailable
```

### Complete Failure:
```
❌ Weather fetch error: The operation couldn't be completed. (WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors error 2.)
```
*This means WeatherKit isn't properly configured*

---

## Quick Checklist

- [ ] WeatherKit capability added in Xcode
- [ ] WeatherKit enabled in Developer Portal
- [ ] Location permission granted
- [ ] Internet connection active
- [ ] Testing on real device (not just simulator)
- [ ] Clean build after changes (`Cmd + Shift + K`)
- [ ] Check Xcode console for debug output

---

## Next Steps

1. **Run the app** and open the weather page
2. **Check Xcode console** for debug output
3. **Take a screenshot** of the console if data is missing
4. **Share the console output** to diagnose the exact issue

The debug logging will tell us exactly which data points are available from WeatherKit!

---

**Last Updated:** April 4, 2026
