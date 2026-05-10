// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Shared UI Components             ║
// ║           SharedComponents.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

// MARK: - App Header (consistent across all screens)
struct AppHeader: View {
    @EnvironmentObject var store: TimesheetStore
    var subtitle: String? = nil   // e.g. period label on detail screen

    var body: some View {
        VStack(spacing: 2) {
            Text("🏝️ KAUAI VIP 2026")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(2)
            Text(store.driverName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.coral)
                    .tracking(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.oceanDeep)
    }
}

// MARK: - Traffic / Bridge Status Banner
struct TrafficBanner: View {
    @EnvironmentObject var bridgeService: BridgeService

    var body: some View {
        HStack(spacing: 8) {
            Text(bridgeService.level.bannerIcon)
            Text("Traffic: \(bridgeService.trafficLevel)")
                .fontWeight(.semibold)
            Circle().frame(width: 4, height: 4).opacity(0.5)
            Text("Hanalei Bridge: \(bridgeService.bridgeStatus)")
                .fontWeight(.semibold)
            Spacer()
            if bridgeService.waterLevelFt != "N/A" {
                Text(bridgeService.waterLevelFt)
                    .font(.system(size: 11))
                    .opacity(0.75)
            }
        }
        .font(.system(size: 13))
        .foregroundColor(bridgeService.level == .caution ? .black : .white)
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.vertical, 9)
        .background(bridgeService.level.statusColor)
        .animation(.easeInOut(duration: 0.3), value: bridgeService.level.rawValue)
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
            TopButton(icon: "sun.max.fill",         label: "WEATHER",   color: Color(hex: "FDB813"), action: onWeather)
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
                .frame(width: 66)

            // ── Traffic ──────────────────────────────────────────
            TopButton(icon: "light.beacon.max.fill", label: "TRAFFIC", color: AppTheme.coral,   action: onTraffic)
                .frame(width: 66)

            // ── Stats ─────────────────────────────────────────────
            TopButton(icon: "chart.bar.fill",        label: "STATS",   color: AppTheme.success, action: onStats)
                .frame(width: 66)
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
            .background(AppTheme.oceanMedium)
            .cornerRadius(AppTheme.cardRadius)
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
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

    @State private var selHour:   Int = 12
    @State private var selMinute: Int = 0
    @State private var selPeriod: String = "AM"

    var body: some View {
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
        .colorScheme(.dark)
        .padding(.vertical, 4)
        .background(AppTheme.oceanLight.opacity(0.3))
        .cornerRadius(10)
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
        selMinute = (min / 5) * 5
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
    try? data.write(to: url)
    let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let root  = scene.keyWindow?.rootViewController {
        root.present(vc, animated: true)
    }
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
