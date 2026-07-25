// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Shared UI Components             ║
// ║           SharedComponents.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

// MARK: - Traffic / Bridge Status Banner
struct TrafficBanner: View {
    @EnvironmentObject var bridgeService:  BridgeService
    @EnvironmentObject var weatherManager: WeatherManager
    @State private var showFAQ = false

    var body: some View {
        let textColor: Color = bridgeService.level == .caution ? .black : .white

        VStack(spacing: 0) {
            // ── Sunrise / Sunset countdown row (self-ticking leaf) ─
            SunCountdownRow(sunrise:         weatherManager.sunriseTime,
                            sunset:          weatherManager.sunsetTime,
                            tomorrowSunrise: weatherManager.tomorrowSunriseTime,
                            textColor:       textColor)
                .padding(.horizontal, AppTheme.screenPad)
                .padding(.top, 7)
                .padding(.bottom, 5)

            Rectangle()
                .fill(textColor.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, AppTheme.screenPad)

            // ── Traffic + Bridge row ──────────────────────────────
            HStack(spacing: 8) {
                Text(bridgeService.level.bannerIcon)
                Text("Traffic: \(bridgeService.trafficLevel)")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Circle().frame(width: 4, height: 4).opacity(0.5)
                Text("Hanalei Bridge: \(bridgeService.bridgeStatus)")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)   // keep status readable; drop water level first
                Spacer(minLength: 4)
                if bridgeService.rawWaterFt != nil {
                    Text(bridgeService.waterLevelFt)
                        .font(.system(size: 11))
                        .opacity(0.75)
                        .lineLimit(1)
                }
                Button { showFAQ = true } label: {
                    Text("?")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(textColor.opacity(0.18))
                        .clipShape(Circle())
                        .foregroundColor(textColor)
                        .frame(width: 32, height: 32)     // enlarge tap target
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Bridge status help")
            }
            .font(.system(size: 13))
            .foregroundColor(textColor)
            .padding(.horizontal, AppTheme.screenPad)
            .padding(.vertical, 8)
        }
        .background(bridgeService.level.statusColor)
        .animation(.easeInOut(duration: 0.3), value: bridgeService.level.rawValue)
        .sheet(isPresented: $showFAQ) { FAQView() }
    }
}

// MARK: - Sunrise / Sunset countdown (leaf view)
/// Ticks once per second via TimelineView so ONLY this row re-renders —
/// keeps the 1-second clock out of every screen's body (battery).
private struct SunCountdownRow: View {
    let sunrise:         Date?
    let sunset:          Date?
    let tomorrowSunrise: Date?
    let textColor:       Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            HStack(spacing: 6) {
                Text(sunEventIcon(now) + " " + sunEventName(now))
                    .fontWeight(.bold)
                Spacer()
                Text(sunCountdown(now))
                    .fontWeight(.bold)
            }
            .font(.system(size: 15))
            .foregroundColor(textColor)
        }
    }

    // MARK: - Sun event helpers (all times HST / Pacific/Honolulu)

    private func nextSunTarget(_ now: Date) -> Date? {
        guard let rise = sunrise, let set = sunset else { return nil }
        if now < rise { return rise }
        if now < set  { return set }
        // After sunset — use real tomorrow sunrise if available, else +24h
        return tomorrowSunrise ?? rise.addingTimeInterval(86_400)
    }

    private func sunEventIcon(_ now: Date) -> String {
        guard let rise = sunrise, let set = sunset else { return "🌅" }
        if now < rise { return "🌅" }
        if now < set  { return "🌇" }
        return "🌅"
    }

    private func sunEventName(_ now: Date) -> String {
        guard let rise = sunrise, let set = sunset else { return "Sunrise · HST" }
        if now < rise { return "Sunrise · HST" }
        if now < set  { return "Sunset · HST" }
        return "Tomorrow's Sunrise · HST"
    }

    private func sunCountdown(_ now: Date) -> String {
        guard let target = nextSunTarget(now) else { return "--" }
        let secs = max(0, Int(target.timeIntervalSince(now)))
        if secs == 0 { return "Now" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return "in \(h)h \(m)m" }
        if m > 0 { return "in \(m)m \(s)s" }
        return "in \(s)s"
    }
}

// MARK: - Driver Name Band
/// The blue band with the driver's name (plus optional next-trip countdown)
/// shown directly under the top strip — identical on every page.
struct DriverBand: View {
    let name: String                 // driver name — always primary
    var company: String? = nil       // company name — subline under the driver
    var countdown: String? = nil     // single "Next:" line (used when no chips)
    var countdowns: [(label: String, value: String)] = []   // per-trip chips, side by side

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.oceanDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 12)

            if let company {
                Text(company)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.oceanDeep.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
            }

            if !countdowns.isEmpty {
                // One chip per countdown-enabled trip, side by side.
                // Scrolls horizontally if more fit than the screen allows.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(countdowns.enumerated()), id: \.offset) { _, chip in
                            VStack(spacing: 1) {
                                Text(chip.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.oceanDeep.opacity(0.75))
                                    .lineLimit(1)
                                Text(chip.value)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(AppTheme.oceanDeep)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppTheme.oceanDeep.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)   // centers when chips don't fill the width
                }
                .padding(.top, 4)
            } else if let countdown {
                Text("Next: \(countdown)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.oceanDeep.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.success)
    }
}

// MARK: - Top Action Buttons (Weather / Apple Map / Traffic)
struct TopActionButtons: View {
    let onWeather: () -> Void
    let onMap:     () -> Void
    let onTraffic: () -> Void
    let onStats:   () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TopButton(icon: "sun.max.fill",         label: "WEATHER",   color: AppTheme.warning, action: onWeather)
            TopButton(icon: "map.fill",              label: "APPLE MAP", color: AppTheme.info,        action: onMap)
            TopButton(icon: "light.beacon.max.fill", label: "TRAFFIC",   color: AppTheme.coral,       action: onTraffic)
            TopButton(icon: "chart.bar.fill",        label: "STATS",     color: AppTheme.success,     action: onStats)
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.vertical, 10)
    }
}

// MARK: - Period Top Buttons (live weather widget + Map + Traffic)
/// Used on the trips/period detail screen. Replaces the generic weather
/// button with a compact live-conditions widget that taps into the full modal.
struct PeriodTopButtons: View {
    let onWeather: () -> Void
    let onMap:     () -> Void
    let onTraffic: () -> Void
    let onStats:   () -> Void

    @EnvironmentObject var weatherManager: WeatherManager

    var body: some View {
        HStack(spacing: 10) {
            // ── Live weather widget ──────────────────────────────
            Button(action: onWeather) {
                HStack(spacing: 8) {
                    WeatherIcon(symbolName: weatherManager.sfSymbol, size: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(weatherManager.tempF)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(weatherManager.conditionText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                        Text("\(weatherManager.moonPhaseEmoji) · 🌊 \(weatherManager.waveHeightFt)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(AppTheme.oceanMedium)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.oceanLight, lineWidth: 1))
            }

            // ── Map ──────────────────────────────────────────────
            TopButton(icon: "map.fill",              label: "MAP",     color: AppTheme.info,    action: onMap)
                .frame(minWidth: 56, maxWidth: 72)

            // ── Traffic ──────────────────────────────────────────
            TopButton(icon: "light.beacon.max.fill", label: "TRAFFIC", color: AppTheme.coral,   action: onTraffic)
                .frame(minWidth: 56, maxWidth: 72)

            // ── Stats ─────────────────────────────────────────────
            TopButton(icon: "chart.bar.fill",        label: "STATS",   color: AppTheme.success, action: onStats)
                .frame(minWidth: 56, maxWidth: 72)
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.vertical, 10)
    }
}

private struct TopButton: View {
    let icon:   String
    let label:  String
    let color:  Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.oceanMedium)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.oceanLight, lineWidth: 1)
            )
        }
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

// MARK: - Press Event Modifier
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded   { _ in onRelease() }
        )
    }
}

// MARK: - App Card (elevated surface)
/// Canonical card container. Wraps content in the standard card surface defined
/// by AppCardModifier (Theme.swift). All card styling flows from that single source.
struct AppCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 14

    init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(AppCardModifier())
    }
}

// MARK: - Section Header Label
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: AppTheme.caption, weight: .semibold))
            .foregroundColor(AppTheme.textTertiary)
            .tracking(0.8)
            .padding(.horizontal, AppTheme.screenPad)
            .padding(.top, AppTheme.sectionSpacing)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Coral Primary Button
struct CoralButton: View {
    let title:    String
    let icon:     String?
    let action:   () -> Void
    var disabled: Bool = false

    init(_ title: String, icon: String? = nil, disabled: Bool = false, action: @escaping () -> Void) {
        self.title    = title
        self.icon     = icon
        self.disabled = disabled
        self.action   = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let ic = icon { Text(ic) }
                Text(title).fontWeight(.bold)
            }
        }
        .buttonStyle(CoralButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

// MARK: - Labeled Field (read-only display row)
struct LabeledField: View {
    let label: String
    let value: String
    var valueColor: Color = AppTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.6)
            Text(value)
                .font(.system(size: AppTheme.body, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - App Text Field
struct AppTextField: View {
    let label:       String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.6)
            TextField(placeholder, text: $text)
                .foregroundColor(AppTheme.textPrimary)
                .keyboardType(keyboard)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.oceanLight.opacity(0.4))
                .cornerRadius(AppTheme.fieldRadius)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldRadius).stroke(AppTheme.oceanLight, lineWidth: 1))
        }
    }
}

// MARK: - App Picker Row
struct AppPickerRow<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let label:      String
    @Binding var selection: T

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.6)
            Picker(label, selection: $selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .foregroundColor(AppTheme.coral)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.oceanLight.opacity(0.4))
            .cornerRadius(AppTheme.fieldRadius)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldRadius).stroke(AppTheme.oceanLight, lineWidth: 1))
        }
    }
}

// MARK: - Toggle Time Row
struct ToggleTimeRow: View {
    let label:      String
    @Binding var isOn:  Bool
    @Binding var time:  Date

    @State private var showPicker = false

    private var displayTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: time)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: $isOn.animation()) {
                    Text(label)
                        .font(.system(size: AppTheme.subhead, weight: .medium))
                        .foregroundColor(isOn ? AppTheme.textPrimary : AppTheme.textTertiary)
                }
                .tint(AppTheme.coral)

                if isOn {
                    Spacer()
                    Button(action: { withAnimation(.spring(response: 0.3)) { showPicker.toggle() } }) {
                        Text(displayTime)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.coral)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.oceanLight.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
            }

            if isOn && showPicker {
                FiveMinutePicker(time: $time)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .onChange(of: isOn) { _, on in if !on { showPicker = false } }
    }
}

// MARK: - Five Minute Picker
struct FiveMinutePicker: View {
    @Binding var time: Date

    private let hours   = Array(1...12)
    private let minutes = stride(from: 0, through: 55, by: 5).map { $0 }
    private let periods = ["AM", "PM"]

    @State private var selHour:      Int    = 12
    @State private var selMinute:    Int    = 0
    @State private var selPeriod:    String = "AM"
    /// True when the loaded time was not already on a 5-minute boundary and was rounded.
    @State private var wasRounded:   Bool   = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                // Hour wheel
                Picker("", selection: $selHour) {
                    ForEach(hours, id: \.self) { h in
                        Text("\(h)").tag(h)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 120)
                .clipped()

                Text(":")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, 2)

                // Minute wheel (5s only)
                Picker("", selection: $selMinute) {
                    ForEach(minutes, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 120)
                .clipped()

                // AM/PM wheel
                Picker("", selection: $selPeriod) {
                    ForEach(periods, id: \.self) { p in
                        Text(p).tag(p)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 120)
                .clipped()
            }
            .padding(.vertical, 4)
            .background(AppTheme.oceanLight.opacity(0.3))
            .cornerRadius(10)

            // Show a brief note when the original time was rounded to the nearest 5 minutes.
            if wasRounded {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Rounded to nearest 5 min")
                        .font(.system(size: 11))
                }
                .foregroundColor(AppTheme.warning)
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .onAppear { loadFromDate() }
        .onChange(of: selHour)   { _, _ in writeToDate() }
        .onChange(of: selMinute) { _, _ in writeToDate() }
        .onChange(of: selPeriod) { _, _ in writeToDate() }
    }

    private func loadFromDate() {
        let cal  = Calendar.current
        var hour = cal.component(.hour, from: time)
        let min  = cal.component(.minute, from: time)
        selPeriod = hour >= 12 ? "PM" : "AM"
        if hour == 0       { hour = 12 }
        else if hour > 12  { hour -= 12 }
        selHour   = hour
        let rounded = (min / 5) * 5
        // Notify the user if we had to round a non-5-multiple minute value.
        wasRounded = rounded != min
        selMinute  = rounded
    }

    private func writeToDate() {
        var hour24 = selHour % 12
        if selPeriod == "PM" { hour24 += 12 }
        let cal   = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: time)
        comps.hour   = hour24
        comps.minute = selMinute
        comps.second = 0
        if let d = cal.date(from: comps) { time = d }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text:  String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - SF Symbol Weather Icon (fallback-safe)
struct WeatherIcon: View {
    let symbolName: String
    let size:       CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size, weight: .medium))
    }
}

// MARK: - Share File Helper
func shareFile(data: Data, filename: String) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    do {
        try data.write(to: url, options: .atomic)
    } catch {
        showAlert("Export Failed", message: "Could not write file: \(error.localizedDescription)")
        return
    }
    let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let root  = scene.keyWindow?.rootViewController {
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // Required on iPad — without a source view the popover has no anchor and crashes.
        if let popover = vc.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }
}

private func showAlert(_ title: String, message: String) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root  = scene.keyWindow?.rootViewController else { return }
    var top = root
    while let presented = top.presentedViewController { top = presented }
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    top.present(alert, animated: true)
}

// MARK: - Divider
struct AppDivider: View {
    var body: some View {
        Divider().background(AppTheme.oceanLight)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon:    String
    let message: String
    let sub:     String

    var body: some View {
        VStack(spacing: 12) {
            Text(icon).font(.system(size: 44))
            Text(message)
                .font(.system(size: AppTheme.headline, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            Text(sub)
                .font(.system(size: AppTheme.subhead))
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - App Footer (credits + settings)
/// Shown at the bottom of every main page. Self-contained: presents the
/// Settings sheet itself, so a page only needs to drop `AppFooter()` in.
/// Requires `TimesheetStore` in the environment (to forward into Settings).
struct AppFooter: View {
    @EnvironmentObject private var store: TimesheetStore
    @State private var showSettings = false
    @State private var showSurf     = false

    var body: some View {
        VStack(spacing: 12) {
            CoralButton("🏄 Where's the Surf?") { showSurf = true }
                .padding(.horizontal, AppTheme.screenPad)

            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.coral)
            }
            .accessibilityLabel("Open Settings")

            if let appURL = AppConstants.kauaiTodayAppURL {
                Link(destination: appURL) {
                    Label("Kauai Today app", systemImage: "apple.logo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.coral)
                }
            }
            if let webURL = AppConstants.kauaiTodayWebURL {
                Link(destination: webURL) {
                    Label("Kauai Today interwebs", systemImage: "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.coral)
                }
            }

            Text("Made on Kauai with Aloha 🌺")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textTertiary)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                if let mail = AppConstants.mailtoURL {
                    Link(AppConstants.developerName, destination: mail)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.coral)
                } else {
                    Text(AppConstants.developerName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Text("·").foregroundColor(AppTheme.textTertiary)
                Text("© 2026")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .sheet(isPresented: $showSurf) {
            SurfSpotsMapView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(store)
        }
    }
}

// MARK: - FAQ View
struct FAQView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("🏝️")
                                .font(.system(size: 56))
                            Text("RunSheet")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .tracking(2)
                            Text("Driver Timesheet System")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(.top, 24)

                        // Developer card
                        AppCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("DEVELOPER").labelStyle()

                                HStack(spacing: 14) {
                                    Text("👨‍💻").font(.system(size: 34))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(AppConstants.developerName)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(AppTheme.textPrimary)
                                        if let url = AppConstants.websiteURL {
                                            Link("joeywray.com", destination: url)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(AppTheme.coral)
                                        }
                                    }
                                }

                                Divider().background(AppTheme.oceanLight)

                                if let mailURL = AppConstants.mailtoURL {
                                    Link(destination: mailURL) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(AppTheme.coral)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Questions or Suggestions?")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(AppTheme.textPrimary)
                                                Text(AppConstants.supportEmail)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(AppTheme.coral)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.screenPad)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
