// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Design System                    ║
// ║           Theme.swift                                        ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import UIKit

// MARK: - Color Palette
// Backgrounds, text and accent resolve from the user's selected theme:
// System / Light / Dark / Blue Light / Blue Dark (stored in @AppStorage
// "appTheme"). "System" follows the device light/dark; the rest are explicit
// palettes. The app root applies .id(appTheme) so a theme change rebuilds the
// view tree and these computed colors re-resolve.
enum AppTheme {
    // Backgrounds
    static var oceanDeep:   Color { resolve(\.bg) }     // Main screen bg
    static var oceanMedium: Color { resolve(\.card) }   // Cards, elevated surfaces
    static var oceanLight:  Color { resolve(\.border) } // Borders, dividers

    // Accent — primary CTA / highlights (blue in the Blue themes, coral otherwise)
    static var coral: Color { resolve(\.accent) }

    // Text
    static var textPrimary:   Color { resolve(\.textPrimary) }
    static var textSecondary: Color { resolve(\.textSecondary) }
    static var textTertiary:  Color { resolve(\.textTertiary) }

    // "Success"/positive accent — theme-matched (teal/sky, never green).
    static var success: Color { resolve(\.success) }

    // Status (shared across all themes)
    static let warning      = Color(hex: "FFC107")
    static let error        = Color(hex: "F44336")
    static let info         = Color(hex: "2196F3")

    /// Resolves a palette color for the currently-selected theme.
    private static func resolve(_ key: KeyPath<ThemePalette, Color>) -> Color {
        switch UserDefaults.standard.string(forKey: "appTheme") ?? "blueLight" {
        case "light":     return ThemePalette.classicLight[keyPath: key]
        case "dark":      return ThemePalette.classicDark[keyPath: key]
        case "blueLight": return ThemePalette.blueLight[keyPath: key]
        case "blueDark":  return ThemePalette.blueDark[keyPath: key]
        default:          return Color(light: ThemePalette.classicLight[keyPath: key],
                                       dark:  ThemePalette.classicDark[keyPath: key])
        }
    }

    // Spacing
    static let screenPad:    CGFloat = 16
    static let cardSpacing:  CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let elemSpacing:  CGFloat = 8
    static let tightSpacing: CGFloat = 4

    // Corner Radii
    static let cardRadius:   CGFloat = 12
    static let buttonRadius: CGFloat = 8
    static let fieldRadius:  CGFloat = 8

    // Font sizes
    static let hugeTitle:  CGFloat = 34
    static let largeTitle: CGFloat = 28
    static let title1:     CGFloat = 24
    static let title2:     CGFloat = 20
    static let headline:   CGFloat = 17
    static let body:       CGFloat = 16
    static let subhead:    CGFloat = 14
    static let footnote:   CGFloat = 13
    static let caption:    CGFloat = 12
}

// MARK: - Theme Palettes
/// One palette per selectable theme. Blue themes use a popular azure/blue
/// (Tailwind blue-600 / blue-500) as the accent and blue-tinted surfaces.
private struct ThemePalette {
    let bg, card, border, accent, success: Color
    let textPrimary, textSecondary, textTertiary: Color

    // Classic "ocean" (default light / dark) — success is a teal that fits the ocean palette
    static let classicLight = ThemePalette(
        bg: Color(hex: "F2F6FA"), card: Color(hex: "FFFFFF"), border: Color(hex: "D5DEE7"), accent: Color(hex: "FF6B6B"), success: Color(hex: "0E9DB4"),
        textPrimary: Color(hex: "0A1929"), textSecondary: Color(hex: "546E7A"), textTertiary: Color(hex: "78909C"))

    static let classicDark = ThemePalette(
        bg: Color(hex: "0A1929"), card: Color(hex: "1E3A5F"), border: Color(hex: "2E4A6F"), accent: Color(hex: "FF6B6B"), success: Color(hex: "2BB7C9"),
        textPrimary: .white, textSecondary: Color(hex: "B0BEC5"), textTertiary: Color(hex: "78909C"))

    // Blue (popular azure) light / dark — success is a sky-blue that matches the theme
    static let blueLight = ThemePalette(
        bg: Color(hex: "EFF4FF"), card: Color(hex: "FFFFFF"), border: Color(hex: "D6E2FB"), accent: Color(hex: "2563EB"), success: Color(hex: "0EA5E9"),
        textPrimary: Color(hex: "0F2547"), textSecondary: Color(hex: "44556F"), textTertiary: Color(hex: "7488A3"))

    static let blueDark = ThemePalette(
        bg: Color(hex: "0B1733"), card: Color(hex: "15264D"), border: Color(hex: "243B6B"), accent: Color(hex: "3B82F6"), success: Color(hex: "38BDF8"),
        textPrimary: .white, textSecondary: Color(hex: "AEC0E0"), textTertiary: Color(hex: "7C92BC"))
}

// MARK: - Dynamic (light/dark) Color
extension Color {
    /// A color that resolves to `light` in light mode and `dark` in dark mode,
    /// following the active UITraitCollection (driven by .preferredColorScheme).
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Canonical Card Style Constants
// Single source of truth consumed by both AppCardModifier and AppCard (SharedComponents).
extension AppTheme {
    static let cardShadowColor:  Color   = .black.opacity(0.25)
    static let cardShadowRadius: CGFloat = 6
    static let cardShadowX:      CGFloat = 0
    static let cardShadowY:      CGFloat = 3
}

// MARK: - View Modifiers
/// Applies the canonical card surface style to any existing view.
/// For wrapping content in a card container use `AppCard` (SharedComponents.swift).
struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.oceanMedium)
            .cornerRadius(AppTheme.cardRadius)
            .shadow(color: AppTheme.cardShadowColor,
                    radius: AppTheme.cardShadowRadius,
                    x: AppTheme.cardShadowX,
                    y: AppTheme.cardShadowY)
    }
}

extension View {
    func appCard() -> some View { modifier(AppCardModifier()) }

    func labelStyle() -> some View {
        self.font(.system(size: AppTheme.caption, weight: .semibold))
            .foregroundColor(AppTheme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

// MARK: - CoralButton Style
struct CoralButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    /// Fill color — CoralButton passes gray when disabled so the button
    /// reads as inert instead of a half-faded (still tappable-looking) accent.
    var fillColor: Color = AppTheme.coral
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppTheme.body, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .background(fillColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            .cornerRadius(AppTheme.buttonRadius)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppTheme.subhead, weight: .semibold))
            .foregroundColor(AppTheme.coral)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius).stroke(AppTheme.coral, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
