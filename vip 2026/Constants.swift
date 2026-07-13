// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — App-Wide Constants               ║
// ║           Constants.swift                                    ║
// ╚══════════════════════════════════════════════════════════════╝

import Foundation

enum AppConstants {
    // MARK: - Developer / Contact
    static let developerName    = "Joey Wray"
    static let developerWebsite = "https://joeywray.com"
    static let supportEmail     = "Joey@joeywray.com"

    // MARK: - Kauai Today (sister app + site)
    static let kauaiTodayAppURLString = "https://apps.apple.com/us/app/kauai-today/id6770365838"
    static let kauaiTodayWebURLString = "https://kauaitoday.info"
    static var kauaiTodayAppURL: URL? { URL(string: kauaiTodayAppURLString) }
    static var kauaiTodayWebURL: URL? { URL(string: kauaiTodayWebURLString) }

    // MARK: - Deep-link helpers
    static var mailtoURL: URL? {
        URL(string: "mailto:\(supportEmail)?subject=RunSheet%20Feedback")
    }
    static var websiteURL: URL? {
        URL(string: developerWebsite)
    }
}
