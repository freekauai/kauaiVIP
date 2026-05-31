# Kauai VIP 2026 iOS — Security Review
*Reviewed: May 28, 2026*

---

## CRITICAL

### C-1: Driver Name Stored in Plaintext UserDefaults
**File:** `vip 2026/TimesheetStore.swift` lines 34, 139

The driver's real name is written to `UserDefaults` under key `"kauai_vip_2026_driver_name"`. UserDefaults is a plain-text `.plist` in the app's Library/Preferences container. On an unencrypted Mac backup or a jailbroken device, any process with filesystem access can read it without authentication.

**Fix:** Store the driver name in the iOS Keychain using `SecItemAdd`/`SecItemCopyMatching`. The existing migration pattern in `TimesheetStore.load()` (lines 128–133) is a ready-made template — read from UserDefaults once, write to Keychain, delete the UserDefaults key.

---

### C-2: No Authentication Gate on App Launch
**File:** `vip 2026/ContentView.swift` lines 28–56 / `vip 2026/PasscodeView.swift` (stub)

The only "gate" is checking whether `store.driverName.isEmpty`. Once a name is set, all trip logs, client names, and earnings data are immediately accessible. The passcode feature was removed and no biometric replacement was added. If the phone is left unlocked in a vehicle, a client or third party has unobstructed access to every client name, trip time, and schedule.

**Fix:** Add Face ID / Touch ID via `LocalAuthentication`. Present `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometricsAndPasscode, ...)` in `ContentView` on `onAppear` and whenever `scenePhase == .active`. An `@State var isUnlocked = false` toggle with a biometric overlay is enough.

---

## MODERATE

### M-1: Main Data File Has No iOS Data Protection Class
**File:** `vip 2026/TimesheetStore.swift` line 114

```swift
try data.write(to: periodsFileURL, options: .atomic)
```

The JSON file `kauai_vip_periods.json` is written without `.completeFileProtection`. iOS defaults to `.completeUntilFirstUserAuthentication`, meaning the file is readable when the device is locked (parked car scenario).

**Fix:** `try data.write(to: periodsFileURL, options: [.atomic, .completeFileProtection])`

---

### M-2: Export Temp Files Unprotected and Not Cleaned Up
**File:** `vip 2026/SharedComponents.swift` lines 555–557

```swift
let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
try data.write(to: url, options: .atomic)
```

PDFs and CSVs with client names are written to the temp directory with no file protection and are never deleted after the share sheet dismisses.

**Fix:** Add `.completeFileProtection` to the write options. Use `UIActivityViewController.completionWithItemsHandler` to delete the file after sharing.

---

### M-3: WeatherKit Entitlement Present But Unused
**File:** `vip 2026.xcodeproj/vip-2026.entitlements` line 5

```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

The app uses Open-Meteo for all weather data — `WeatherKit` is never imported. Unused entitlements expand the app's attack surface and can trigger App Review scrutiny. WeatherKit also requires a paid developer capability.

**Fix:** Remove the entitlement. Verify which entitlements file the build actually consumes in Build Settings → Code Signing Entitlements.

---

### M-4: Export Filename Partially Derived from User Data Without Full Sanitization
**File:** `vip 2026/PeriodDetailView.swift` lines 307–316

`period.label` (containing an en-dash U+2013) is passed through with only space→underscore replacement. Currently safe because labels are date-derived, but any future incorporation of free-text user input into the label would create a path-traversal risk.

**Fix:** Add a sanitizer that removes `/`, `\`, `..`, and non-ASCII characters before calling `appendingPathComponent`.

---

### M-5: Developer Venmo Handle Hardcoded in Binary
**File:** `vip 2026/Constants.swift` lines 10–16

```swift
static let venmoHandle = "Joey-Wray-1"
static let venmoURL    = "https://venmo.com/u/Joey-Wray-1"
```

These strings are committed to the repo and extractable from any distributed IPA. A Venmo handle directly linked from a commercial transport tool is an unusual exposure.

**Fix:** Consider linking only from a webpage rather than the binary, or be aware this is publicly visible in the distributed app.

---

## LOW

### L-1: PrivacyInfo.xcprivacy Missing Network/File API Declarations
**File:** `vip 2026/PrivacyInfo.xcprivacy`

Declares `NSPrivacyAccessedAPICategoryUserDefaults` but omits outbound network access (`api.open-meteo.com`, `marine-api.open-meteo.com`, `api.tidesandcurrents.noaa.gov`) and file system access (Documents + temp directory). Missing entries can trigger App Store rejection under Apple's Privacy Manifests requirement (enforced since Spring 2024).

---

### L-2: No Certificate Pinning on API Requests
**Files:** `WeatherManager.swift` lines 193–194; `BridgeService.swift` line 184

Both use `URLSession.shared` with no delegate for certificate validation. Low risk given well-known public APIs over HTTPS, but a MITM attacker who compromises a trusted CA could intercept weather/bridge data.

---

### L-3: Marine Weather Errors Silently Swallowed
**File:** `WeatherManager.swift` line 205

Uses `try?` — any server error leaves wave fields at `"--"` with no user notification.

---

### L-4: No Max Length on Client Name Field
**File:** `vip 2026/TripFormView.swift` line 192

Only validates non-empty. A 10,000-character client name would be stored in JSON, embedded in PDF layout, and exported to CSV.

**Fix:** Enforce a 100-character maximum.

---

### L-5: CSV Import Stores Client Names Without Sanitization
**File:** `vip 2026/CSVImportView.swift` line 264

`clientStr` from file is stored directly without trim or length validation. A crafted CSV could embed control characters or oversized strings.

**Fix:** Apply the same validation used in `TripFormView.saveTrip()` to all imported fields.

---

### L-7: No Third-Party Dependencies ✅
No SPM packages, CocoaPods, or Carthage dependencies. All frameworks are Apple system frameworks — no supply-chain risk.

---

## Summary Table

| ID | Severity | Area | Finding |
|----|----------|------|---------|
| C-1 | **Critical** | Data Storage | Driver name in plaintext UserDefaults — should be Keychain |
| C-2 | **Critical** | Authentication | No auth gate; passcode removed, no biometric replacement |
| M-1 | Moderate | File System | Main data JSON lacks `.completeFileProtection` |
| M-2 | Moderate | File System | Export temp files unprotected and not cleaned up |
| M-3 | Moderate | Entitlements | WeatherKit entitlement unused but present |
| M-4 | Moderate | Input Validation | Export filename not fully sanitized |
| M-5 | Moderate | Secrets | Venmo handle/URL hardcoded in binary |
| L-1 | Low | Privacy | PrivacyInfo missing network/file-system API declarations |
| L-2 | Low | Network | No certificate pinning on Open-Meteo / NOAA |
| L-3 | Low | Network | Marine weather errors silently swallowed |
| L-4 | Low | Input Validation | No max-length on client name field |
| L-5 | Low | Input Validation | CSV import skips field sanitization |

---

## Priority Action Plan

1. **Keychain for driver name** (C-1) — ~1 hr. Add `Security` framework, write a `KeychainHelper`, migrate read/write in `TimesheetStore.swift`.
2. **Face ID / Touch ID gate** (C-2) — ~2 hrs. Add `LocalAuthentication`, `isUnlocked` state in `ContentView`, biometric challenge on `onAppear` and `scenePhase` change.
3. **File protection on data writes** (M-1, M-2) — ~30 min. Add `.completeFileProtection` to both write calls; add `completionWithItemsHandler` to delete temp exports after sharing.
4. **Remove WeatherKit entitlement** (M-3) — 5 min.
5. **PrivacyInfo completeness** (L-1) — ~30 min.
