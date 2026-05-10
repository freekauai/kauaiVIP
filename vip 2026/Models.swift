// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Data Models                      ║
// ║           Models.swift                                       ║
// ╚══════════════════════════════════════════════════════════════╝

import Foundation
import UIKit

// MARK: - Vehicle
enum Vehicle: String, CaseIterable, Codable, Identifiable {
    case suv       = "SUV"
    case sprinterA = "Sprinter A"
    case sprinterB = "Sprinter B"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .suv:       return "🚙"
        case .sprinterA: return "🚐"
        case .sprinterB: return "🚐"
        }
    }
}

// MARK: - ServiceType
enum ServiceType: String, CaseIterable, Codable, Identifiable {
    case airport = "Airport"
    case charter = "Charter"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .airport: return "✈️"
        case .charter: return "🏝️"
        }
    }
}

// MARK: - Trip
struct Trip: Identifiable, Codable {
    var id:           UUID        = UUID()
    var date:         Date        = Date()
    var vehicle:      Vehicle     = .suv
    var service:      ServiceType = .airport
    var clientName:   String      = ""
    var notes:        String      = ""

    // Optional time fields
    var hasPUTime:    Bool        = false
    var pickupTime:   Date?       = nil
    var hasDOTime:    Bool        = false
    var dropoffTime:  Date?       = nil
    var hasLeftBase:  Bool        = false
    var timeLeftBase: Date?       = nil
    var hasBackBase:  Bool        = false
    var timeBackBase: Date?       = nil

    // MARK: Computed

    /// Driver duty time for this trip.
    /// Prefers Left Base → Back Base (total time away from base).
    /// Falls back to Pickup → Dropoff if base times aren't set.
    var charterDuration: TimeInterval? {
        if hasLeftBase, hasBackBase, let lb = timeLeftBase, let bb = timeBackBase {
            let interval = bb.timeIntervalSince(lb)
            return interval > 0 ? interval : nil
        }
        if hasPUTime, hasDOTime, let pu = pickupTime, let doTime = dropoffTime {
            let interval = doTime.timeIntervalSince(pu)
            return interval > 0 ? interval : nil
        }
        return nil
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
    var formattedPickup: String {
        guard hasPUTime, let t = pickupTime else { return "--" }
        return t.formatted(date: .omitted, time: .shortened)
    }
    var formattedDropoff: String {
        guard hasDOTime, let t = dropoffTime else { return "--" }
        return t.formatted(date: .omitted, time: .shortened)
    }
    var formattedLeftBase: String {
        guard hasLeftBase, let t = timeLeftBase else { return "--" }
        return t.formatted(date: .omitted, time: .shortened)
    }
    var formattedBackBase: String {
        guard hasBackBase, let t = timeBackBase else { return "--" }
        return t.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - PayPeriod
struct PayPeriod: Identifiable, Codable, Hashable {
    static func == (lhs: PayPeriod, rhs: PayPeriod) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    var id:        UUID   = UUID()
    var startDate: Date
    var endDate:   Date
    var trips:     [Trip] = []

    // MARK: Computed
    var label: String {
        let startFmt = startDate.formatted(.dateTime.month(.abbreviated).day())
        let endFmt   = endDate.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startFmt) – \(endFmt)"
    }
    var dayCount: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day.map { $0 + 1 } ?? 0
    }
    var isValidLength: Bool {
        (14...16).contains(dayCount)
    }
    /// Total on-clock time across all trips that have at least two time points.
    var totalCharterDuration: TimeInterval {
        trips.filter { $0.service == .charter }.compactMap(\.charterDuration).reduce(0, +)
    }

    /// "Xh Ym" or "--" when no trips have enough time data.
    var formattedCharterHours: String {
        let total = totalCharterDuration
        guard total > 0 else { return "--" }
        let h = Int(total) / 3_600
        let m = (Int(total) % 3_600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

// MARK: - PDF Export Helper
extension PayPeriod {
    func pdfData(driverName: String) -> Data {
        let pageW:    CGFloat = 612
        let pageH:    CGFloat = 792
        let margin:   CGFloat = 36
        let contentW: CGFloat = pageW - margin * 2

        let oceanDeep  = UIColor(red: 0.055, green: 0.176, blue: 0.318, alpha: 1)
        let coralColor = UIColor(red: 0.95,  green: 0.42,  blue: 0.31,  alpha: 1)
        let rowAlt     = UIColor(red: 0.94,  green: 0.965, blue: 0.98,  alpha: 1)

        let cols: [(String, CGFloat)] = [
            ("DATE", 52), ("VEHICLE", 72), ("SERVICE", 62), ("CLIENT", 100),
            ("PU", 48), ("DO", 48), ("LB", 48), ("BB", 48)
        ]

        func drawText(_ text: String, in ctx: UIGraphicsPDFRendererContext,
                      at pt: CGPoint, font: UIFont, color: UIColor, width: CGFloat) -> CGFloat {
            let para = NSMutableParagraphStyle()
            para.alignment = .left
            let astr = NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: para
            ])
            let bound = astr.boundingRect(with: CGSize(width: width, height: 2000),
                                          options: .usesLineFragmentOrigin, context: nil)
            astr.draw(in: CGRect(origin: pt, size: CGSize(width: width, height: bound.height + 2)))
            return bound.height
        }

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var cg = ctx.cgContext

            // ── Header background ──────────────────────────────────────────
            cg.setFillColor(oceanDeep.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: pageW, height: 118))

            // App name (small, above driver name)
            _ = drawText("KAUAI VIP 2026", in: ctx, at: CGPoint(x: margin, y: 14),
                         font: .systemFont(ofSize: 10, weight: .semibold),
                         color: UIColor.white.withAlphaComponent(0.55), width: contentW)

            // Driver name — prominent
            let name = driverName.isEmpty ? "Driver Report" : driverName
            _ = drawText(name, in: ctx, at: CGPoint(x: margin, y: 30),
                         font: .systemFont(ofSize: 26, weight: .bold),
                         color: .white, width: contentW)

            // Subtitle
            _ = drawText("Driver Timesheet Report  •  \(self.label)", in: ctx,
                         at: CGPoint(x: margin, y: 68),
                         font: .systemFont(ofSize: 12, weight: .medium),
                         color: UIColor.white.withAlphaComponent(0.82), width: contentW)

            // Generated date
            let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
            _ = drawText("Generated: \(df.string(from: Date()))", in: ctx,
                         at: CGPoint(x: margin, y: 90),
                         font: .systemFont(ofSize: 9),
                         color: UIColor.white.withAlphaComponent(0.5), width: contentW)

            var y: CGFloat = 130

            // ── Stats row ──────────────────────────────────────────────────
            let airportCount = trips.filter { $0.service == .airport }.count
            let charterCount = trips.filter { $0.service == .charter }.count
            let stats: [(String, String, UIColor)] = [
                ("TRIPS",        "\(trips.count)",               oceanDeep),
                ("AIRPORT",      "\(airportCount)",              oceanDeep),
                ("CHARTER",      "\(charterCount)",              oceanDeep),
                ("CHARTER HRS",  self.formattedCharterHours,     coralColor),
                ("DAYS",         "\(dayCount)",                  oceanDeep),
            ]
            let statW = contentW / CGFloat(stats.count)
            for (i, stat) in stats.enumerated() {
                let sx = margin + CGFloat(i) * statW
                _ = drawText(stat.0, in: ctx, at: CGPoint(x: sx, y: y),
                             font: .systemFont(ofSize: 8, weight: .semibold),
                             color: .gray, width: statW)
                _ = drawText(stat.1, in: ctx, at: CGPoint(x: sx, y: y + 12),
                             font: .systemFont(ofSize: 20, weight: .bold),
                             color: stat.2, width: statW)
            }
            y += 44

            // ── Column header row ──────────────────────────────────────────
            func drawDivider(at dy: CGFloat) {
                cg = ctx.cgContext
                cg.setStrokeColor(UIColor.lightGray.cgColor)
                cg.setLineWidth(0.5)
                cg.move(to:    CGPoint(x: margin, y: dy))
                cg.addLine(to: CGPoint(x: pageW - margin, y: dy))
                cg.strokePath()
            }

            drawDivider(at: y)
            y += 7

            var cx = margin
            for col in cols {
                _ = drawText(col.0, in: ctx, at: CGPoint(x: cx, y: y),
                             font: .systemFont(ofSize: 8, weight: .bold),
                             color: .gray, width: col.1)
                cx += col.1
            }
            y += 14
            drawDivider(at: y)
            y += 5

            // ── Trip rows ──────────────────────────────────────────────────
            let dayFmt = DateFormatter(); dayFmt.dateFormat = "d"
            let monFmt = DateFormatter(); monFmt.dateFormat = "MMM"
            let sorted = trips.sorted { $0.date < $1.date }

            for (idx, trip) in sorted.enumerated() {
                let hasNotes = !trip.notes.isEmpty
                let rowH: CGFloat = hasNotes ? 34 : 22

                if y + rowH > pageH - margin {
                    ctx.beginPage()
                    cg = ctx.cgContext
                    y = margin
                }

                if idx % 2 == 0 {
                    cg = ctx.cgContext
                    cg.setFillColor(rowAlt.cgColor)
                    cg.fill(CGRect(x: margin - 4, y: y - 1, width: contentW + 8, height: rowH))
                }

                cx = margin
                let dateStr = "\(dayFmt.string(from: trip.date)) \(monFmt.string(from: trip.date).uppercased())"
                let cells: [(String, CGFloat, UIFont, UIColor)] = [
                    (dateStr,            cols[0].1, .systemFont(ofSize: 10, weight: .semibold), oceanDeep),
                    (trip.vehicle.rawValue, cols[1].1, .systemFont(ofSize: 10), .black),
                    (trip.service.rawValue, cols[2].1, .systemFont(ofSize: 10), .black),
                    (trip.clientName,    cols[3].1, .systemFont(ofSize: 10, weight: .medium), .black),
                    (trip.formattedPickup   == "--" ? "" : trip.formattedPickup,   cols[4].1, .systemFont(ofSize: 9), .darkGray),
                    (trip.formattedDropoff  == "--" ? "" : trip.formattedDropoff,  cols[5].1, .systemFont(ofSize: 9), .darkGray),
                    (trip.formattedLeftBase == "--" ? "" : trip.formattedLeftBase, cols[6].1, .systemFont(ofSize: 9), .darkGray),
                    (trip.formattedBackBase == "--" ? "" : trip.formattedBackBase, cols[7].1, .systemFont(ofSize: 9), .darkGray),
                ]
                for cell in cells {
                    _ = drawText(cell.0, in: ctx, at: CGPoint(x: cx, y: y + 4),
                                 font: cell.2, color: cell.3, width: cell.1 - 4)
                    cx += cell.1
                }

                if hasNotes {
                    _ = drawText("↳  \(trip.notes)", in: ctx,
                                 at: CGPoint(x: margin + 8, y: y + 19),
                                 font: .italicSystemFont(ofSize: 8), color: .gray, width: contentW - 8)
                }
                y += rowH
            }

            // ── Footer ─────────────────────────────────────────────────────
            let footerY: CGFloat = pageH - 20
            drawDivider(at: footerY - 6)
            _ = drawText("KAUAI VIP 2026  ·  Driver Timesheet System", in: ctx,
                         at: CGPoint(x: margin, y: footerY),
                         font: .systemFont(ofSize: 8), color: .lightGray, width: contentW / 2)
        }
    }
}

// MARK: - CSV Export Helper
extension PayPeriod {
    var csvString: String {
        var rows: [String] = ["Date,Vehicle,Service,Client,PU Time,DO Time,Left Base,Back Base,Notes"]
        for t in trips {
            let row = [
                t.formattedDate,
                t.vehicle.rawValue,
                t.service.rawValue,
                csvQuote(t.clientName),
                t.formattedPickup,
                t.formattedDropoff,
                t.formattedLeftBase,
                t.formattedBackBase,
                csvQuote(t.notes)
            ].joined(separator: ",")
            rows.append(row)
        }
        return rows.joined(separator: "\n")
    }
}

func csvQuote(_ s: String) -> String {
    "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
}

// MARK: - Stats PDF Export Helper
/// Generates a multi-section PDF for Stats exports (All Time / Periods / Monthly).
/// Each element of `sections` is a (sectionTitle, trips) pair.
func makeStatsPDF(title: String, sections: [(String, [Trip])], driverName: String) -> Data {
    let pageW:    CGFloat = 612
    let pageH:    CGFloat = 792
    let margin:   CGFloat = 36
    let contentW: CGFloat = pageW - margin * 2

    let oceanDeep  = UIColor(red: 0.055, green: 0.176, blue: 0.318, alpha: 1)
    let coralColor = UIColor(red: 0.95,  green: 0.42,  blue: 0.31,  alpha: 1)
    let rowAlt     = UIColor(red: 0.94,  green: 0.965, blue: 0.98,  alpha: 1)

    let cols: [(String, CGFloat)] = [
        ("DATE", 52), ("VEHICLE", 72), ("SERVICE", 62), ("CLIENT", 100),
        ("PU", 48), ("DO", 48), ("LB", 48), ("BB", 48)
    ]

    func drawText(_ text: String, in ctx: UIGraphicsPDFRendererContext,
                  at pt: CGPoint, font: UIFont, color: UIColor, width: CGFloat) -> CGFloat {
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        let astr = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: para
        ])
        let bound = astr.boundingRect(with: CGSize(width: width, height: 2000),
                                      options: .usesLineFragmentOrigin, context: nil)
        astr.draw(in: CGRect(origin: pt, size: CGSize(width: width, height: bound.height + 2)))
        return bound.height
    }

    let allTrips = sections.flatMap(\.1)
    let airportCount = allTrips.filter { $0.service == .airport }.count
    let charterCount = allTrips.filter { $0.service == .charter }.count
    let charterDuration = allTrips.filter { $0.service == .charter }
        .compactMap(\.charterDuration).reduce(0.0, +)
    let charterHrsStr: String = {
        guard charterDuration > 0 else { return "--" }
        let h = Int(charterDuration) / 3_600
        let m = (Int(charterDuration) % 3_600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }()

    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

    return renderer.pdfData { ctx in
        func drawDivider(cg: CGContext, at dy: CGFloat) {
            cg.setStrokeColor(UIColor.lightGray.cgColor)
            cg.setLineWidth(0.5)
            cg.move(to: CGPoint(x: margin, y: dy))
            cg.addLine(to: CGPoint(x: pageW - margin, y: dy))
            cg.strokePath()
        }

        func startPage() -> (CGContext, CGFloat) {
            ctx.beginPage()
            return (ctx.cgContext, margin)
        }

        // ── First page ───────────────────────────────────────────
        ctx.beginPage()
        var cg = ctx.cgContext

        // Header background
        cg.setFillColor(oceanDeep.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: pageW, height: 118))

        _ = drawText("KAUAI VIP 2026", in: ctx, at: CGPoint(x: margin, y: 14),
                     font: .systemFont(ofSize: 10, weight: .semibold),
                     color: UIColor.white.withAlphaComponent(0.55), width: contentW)

        let name = driverName.isEmpty ? "Driver Report" : driverName
        _ = drawText(name, in: ctx, at: CGPoint(x: margin, y: 30),
                     font: .systemFont(ofSize: 26, weight: .bold),
                     color: .white, width: contentW)

        _ = drawText(title, in: ctx, at: CGPoint(x: margin, y: 68),
                     font: .systemFont(ofSize: 12, weight: .medium),
                     color: UIColor.white.withAlphaComponent(0.82), width: contentW)

        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        _ = drawText("Generated: \(df.string(from: Date()))", in: ctx,
                     at: CGPoint(x: margin, y: 90),
                     font: .systemFont(ofSize: 9),
                     color: UIColor.white.withAlphaComponent(0.5), width: contentW)

        var y: CGFloat = 130

        // Stats summary row
        let stats: [(String, String, UIColor)] = [
            ("TRIPS",       "\(allTrips.count)", oceanDeep),
            ("AIRPORT",     "\(airportCount)",   oceanDeep),
            ("CHARTER",     "\(charterCount)",   oceanDeep),
            ("CHARTER HRS", charterHrsStr,       coralColor),
            ("SECTIONS",    "\(sections.count)", oceanDeep),
        ]
        let statW = contentW / CGFloat(stats.count)
        for (i, stat) in stats.enumerated() {
            let sx = margin + CGFloat(i) * statW
            _ = drawText(stat.0, in: ctx, at: CGPoint(x: sx, y: y),
                         font: .systemFont(ofSize: 8, weight: .semibold),
                         color: .gray, width: statW)
            _ = drawText(stat.1, in: ctx, at: CGPoint(x: sx, y: y + 12),
                         font: .systemFont(ofSize: 20, weight: .bold),
                         color: stat.2, width: statW)
        }
        y += 44

        let dayFmt = DateFormatter(); dayFmt.dateFormat = "d"
        let monFmt = DateFormatter(); monFmt.dateFormat = "MMM"

        for (sectionTitle, trips) in sections {
            // ── Section header ────────────────────────────────────
            if y + 36 > pageH - margin {
                ctx.beginPage()
                cg = ctx.cgContext
                y = margin
            }

            // Section title bar
            cg = ctx.cgContext
            cg.setFillColor(oceanDeep.withAlphaComponent(0.08).cgColor)
            cg.fill(CGRect(x: margin - 4, y: y, width: contentW + 8, height: 18))
            _ = drawText(sectionTitle.uppercased(), in: ctx, at: CGPoint(x: margin, y: y + 3),
                         font: .systemFont(ofSize: 9, weight: .bold),
                         color: oceanDeep, width: contentW)
            y += 22

            // Column headers
            drawDivider(cg: ctx.cgContext, at: y)
            y += 5
            var cx = margin
            for col in cols {
                _ = drawText(col.0, in: ctx, at: CGPoint(x: cx, y: y),
                             font: .systemFont(ofSize: 8, weight: .bold),
                             color: .gray, width: col.1)
                cx += col.1
            }
            y += 14
            drawDivider(cg: ctx.cgContext, at: y)
            y += 5

            // Trip rows
            let sorted = trips.sorted { $0.date < $1.date }
            for (idx, trip) in sorted.enumerated() {
                let hasNotes = !trip.notes.isEmpty
                let rowH: CGFloat = hasNotes ? 34 : 22

                if y + rowH > pageH - margin {
                    ctx.beginPage()
                    cg = ctx.cgContext
                    y = margin
                }

                if idx % 2 == 0 {
                    cg = ctx.cgContext
                    cg.setFillColor(rowAlt.cgColor)
                    cg.fill(CGRect(x: margin - 4, y: y - 1, width: contentW + 8, height: rowH))
                }

                cx = margin
                let dateStr = "\(dayFmt.string(from: trip.date)) \(monFmt.string(from: trip.date).uppercased())"
                let cells: [(String, CGFloat, UIFont, UIColor)] = [
                    (dateStr,               cols[0].1, .systemFont(ofSize: 10, weight: .semibold), oceanDeep),
                    (trip.vehicle.rawValue, cols[1].1, .systemFont(ofSize: 10), .black),
                    (trip.service.rawValue, cols[2].1, .systemFont(ofSize: 10), .black),
                    (trip.clientName,       cols[3].1, .systemFont(ofSize: 10, weight: .medium), .black),
                    (trip.formattedPickup   == "--" ? "" : trip.formattedPickup,   cols[4].1, .systemFont(ofSize: 9), .darkGray),
                    (trip.formattedDropoff  == "--" ? "" : trip.formattedDropoff,  cols[5].1, .systemFont(ofSize: 9), .darkGray),
                    (trip.formattedLeftBase == "--" ? "" : trip.formattedLeftBase, cols[6].1, .systemFont(ofSize: 9), .darkGray),
                    (trip.formattedBackBase == "--" ? "" : trip.formattedBackBase, cols[7].1, .systemFont(ofSize: 9), .darkGray),
                ]
                for cell in cells {
                    _ = drawText(cell.0, in: ctx, at: CGPoint(x: cx, y: y + 4),
                                 font: cell.2, color: cell.3, width: cell.1 - 4)
                    cx += cell.1
                }
                if hasNotes {
                    _ = drawText("↳  \(trip.notes)", in: ctx,
                                 at: CGPoint(x: margin + 8, y: y + 19),
                                 font: .italicSystemFont(ofSize: 8), color: .gray, width: contentW - 8)
                }
                y += rowH
            }
            y += 8
        }

        // Footer on last page
        let footerY: CGFloat = pageH - 20
        drawDivider(cg: ctx.cgContext, at: footerY - 6)
        _ = drawText("KAUAI VIP 2026  ·  Driver Timesheet System", in: ctx,
                     at: CGPoint(x: margin, y: footerY),
                     font: .systemFont(ofSize: 8), color: .lightGray, width: contentW / 2)
    }
}
