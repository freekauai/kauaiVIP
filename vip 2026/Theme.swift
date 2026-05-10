// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Design System                    ║
// ║           Theme.swift                                        ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

// MARK: - Color Palette
enum AppTheme {
    // Backgrounds
    static let oceanDeep    = Color(hex: "0A1929")   // Main screen bg
    static let oceanMedium  = Color(hex: "1E3A5F")   // Cards, elevated surfaces
    static let oceanLight   = Color(hex: "2E4A6F")   // Borders, dividers

    // Accent
    static let coral        = Color(hex: "FF6B6B")   // Primary CTA, highlights

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: "B0BEC5")
    static let textTertiary  = Color(hex: "78909C")

    // Status
    static let success      = Color(hex: "4CAF50")
    static let warning      = Color(hex: "FFC107")
    static let error        = Color(hex: "F44336")
    static let info         = Color(hex: "2196F3")

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

// MARK: - View Modifiers
struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.oceanMedium)
            .cornerRadius(AppTheme.cardRadius)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppTheme.body, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .background(AppTheme.coral.opacity(configuration.isPressed ? 0.8 : 1.0))
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
