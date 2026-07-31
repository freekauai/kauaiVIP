// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Data Models                      ║
// ║           Models.swift                                       ║
// ╚══════════════════════════════════════════════════════════════╝

import Foundation
import UIKit

// MARK: - Vehicle
/// String-backed (not an enum) so drivers can add their own vehicles in Settings.
/// Encodes as a bare string — its name — so it is byte-compatible with trips
/// saved when this was a plain `enum Vehicle: String` (e.g. "SUV").
struct Vehicle: Hashable, Identifiable, RawRepresentable, Codable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    var id:   String { rawValue }
    var name: String { rawValue }

    /// Built-ins keep their emoji; user-added vehicles fall back to a generic car.
    var icon: String {
        switch rawValue {
        case "SUV":                      return "🚙"
        case "Sprinter A", "Sprinter B": return "🚐"
        default:                         return "🚗"
        }
    }

    // Encode/decode as a single string so the on-disk shape matches the old enum.
    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

extension Vehicle {
    static let suv       = Vehicle(rawValue: "SUV")
    static let sprinterA = Vehicle(rawValue: "Sprinter A")
    static let sprinterB = Vehicle(rawValue: "Sprinter B")
    /// The vehicles that ship with the app — always listed first, never deletable.
    static let builtIns: [Vehicle] = [.suv, .sprinterA, .sprinterB]
}

// MARK: - ServiceType
/// String-backed for the same reason as `Vehicle`. The `.charter` constant is
/// load-bearing: charter-hours totals key off `service == .charter`.
struct ServiceType: Hashable, Identifiable, RawRepresentable, Codable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    var id:   String { rawValue }
    var name: String { rawValue }

    var icon: String {
        switch rawValue {
        case "Airport": return "✈️"
        case "Charter": return "🏝️"
        default:        return "📋"
        }
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

extension ServiceType {
    static let airport = ServiceType(rawValue: "Airport")
    static let charter = ServiceType(rawValue: "Charter")
    /// The services that ship with the app — always listed first, never deletable.
    static let builtIns: [ServiceType] = [.airport, .charter]
}

// MARK: - Trip
struct Trip: Identifiable, Codable {
    var id:           UUID        = UUID()
    var date:         Date        = Date()
    var vehicle:      Vehicle     = .suv
    var service:      ServiceType = .airport
    var clientName:   String      = ""
    var notes:        String      = ""
    var isActive:     Bool        = true    // user toggle — false = dimmed/excluded from next-up

    // Optional time fields
    var hasPUTime:    Bool        = false
    var pickupTime:   Date?       = nil
    var hasDOTime:    Bool        = false
    var dropoffTime:  Date?       = nil
    var hasLeftBase:  Bool        = false
    var timeLeftBase: Date?       = nil
    var hasBackBase:  Bool        = false
    var timeBackBase: Date?       = nil

    // Display options (per-trip) — both default OFF, set in the edit form.
    var isHighlighted: Bool       = false   // gold border + star on the card
    var showCountdown: Bool       = false   // live HST countdown to this trip's earliest entered time

    // MARK: Computed

    /// Re-anchors a time-of-day onto this trip's calendar date. The time pickers
    /// store hour/minute on whatever date the picker was initialized with (often
    /// "today"), so schedule math (countdown / live window) must combine the
    /// entered time-of-day with the trip's actual date.
    private func onTripDate(_ t: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let hm    = cal.dateComponents([.hour, .minute], from: t)
        comps.hour   = hm.hour
        comps.minute = hm.minute
        return cal.date(from: comps) ?? t
    }

    /// Entered time fields in a charter's natural chronological order
    /// (leave base → pickup → drop-off → back to base), each anchored to the
    /// trip's date. Any field whose clock time lands before the previous one is
    /// rolled to the next day, so overnight trips (e.g. 9 PM pickup, 12:30 AM
    /// back-to-base) measure correctly instead of spanning ~20 hours backward.
    private var orderedTimes: [Date] {
        let cal = Calendar.current
        let sequence: [Date?] = [
            hasLeftBase ? timeLeftBase : nil,
            hasPUTime   ? pickupTime   : nil,
            hasDOTime   ? dropoffTime  : nil,
            hasBackBase ? timeBackBase : nil,
        ]
        var result: [Date] = []
        for t in sequence.compactMap({ $0 }) {
            var anchored = onTripDate(t)
            if let previous = result.last {
                while anchored < previous {
                    anchored = cal.date(byAdding: .day, value: 1, to: anchored)
                        ?? anchored.addingTimeInterval(86_400)
                }
            }
            result.append(anchored)
        }
        return result
    }

    /// Charter billing time: pickup → drop-off, plus a 1-hour travel
    /// allowance. Left Base / Back Base are still recorded and shown on
    /// trips and PDFs, but are NOT part of this calculation. Requires both
    /// a pickup and a drop-off time; an overnight drop-off (past midnight)
    /// rolls to the next day so the math stays correct.
    var charterDuration: TimeInterval? {
        guard hasPUTime, let pu = pickupTime,
              hasDOTime, let dropoff = dropoffTime else { return nil }
        let cal   = Calendar.current
        let start = onTripDate(pu)
        var end   = onTripDate(dropoff)
        while end < start {
            end = cal.date(byAdding: .day, value: 1, to: end)
                ?? end.addingTimeInterval(86_400)
        }
        let span = end.timeIntervalSince(start)
        // Sanity cap: a drop-off entered a few minutes BEFORE the pickup
        // (data-entry slip) would roll "overnight" into a ~24h bill. Real
        // charters never run this long, so treat it as invalid instead of
        // silently inflating the period's charter hours.
        guard span < 16 * 3_600 else { return nil }
        return span + 3_600   // +1h travel allowance (PU == DO still bills 1h)
    }

    /// Full duty span: first entered time point → last (LB → PU → DO → BB,
    /// date-anchored, overnight-aware). Used for the "Duty Hrs" stat — the
    /// driver's actual time on the road — as opposed to `charterDuration`,
    /// which is the billing rule (PU→DO + 1h, LB/BB excluded).
    var dutySpan: TimeInterval? {
        let times = orderedTimes
        guard let start = times.first, let end = times.last, end > start else { return nil }
        return end.timeIntervalSince(start)
    }

    /// The trip's start time (first chronological field); used for countdowns.
    var earliestEnteredTime: Date? {
        orderedTimes.first
    }

    /// The trip's next time point still in the future (leave base → pickup →
    /// drop-off → back to base, anchored to the trip's date). As each time
    /// passes, the countdown rolls forward to the next one.
    func nextUpcomingTime(after now: Date) -> Date? {
        orderedTimes.first { $0 > now }
    }

    /// True if `now` falls within this trip's active window (start → end).
    func isLive(at now: Date) -> Bool {
        let times = orderedTimes
        guard let start = times.first, let end = times.last, end > start else { return false }
        return now >= start && now <= end
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

// MARK: - Trip backward-compatible Codable
// A custom decoder (in an extension, so the synthesized memberwise init the
// app relies on is preserved) decodes every field with `decodeIfPresent`,
// falling back to defaults. This lets trips saved by older builds — which
// lack newer keys like `isHighlighted` / `showCountdown` — load without
// throwing. The synthesized encoder is kept as-is.
extension Trip {
    private enum CodingKeys: String, CodingKey {
        case id, date, vehicle, service, clientName, notes, isActive
        case hasPUTime, pickupTime, hasDOTime, dropoffTime
        case hasLeftBase, timeLeftBase, hasBackBase, timeBackBase
        case isHighlighted, showCountdown
    }

    init(from decoder: Decoder) throws {
        self = Trip()   // start from defaults, then override what's present
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self,        forKey: .id)            ?? id
        date          = try c.decodeIfPresent(Date.self,        forKey: .date)          ?? date
        vehicle       = try c.decodeIfPresent(Vehicle.self,     forKey: .vehicle)       ?? vehicle
        service       = try c.decodeIfPresent(ServiceType.self, forKey: .service)       ?? service
        clientName    = try c.decodeIfPresent(String.self,      forKey: .clientName)    ?? clientName
        notes         = try c.decodeIfPresent(String.self,      forKey: .notes)         ?? notes
        isActive      = try c.decodeIfPresent(Bool.self,        forKey: .isActive)      ?? isActive
        hasPUTime     = try c.decodeIfPresent(Bool.self,        forKey: .hasPUTime)     ?? hasPUTime
        pickupTime    = try c.decodeIfPresent(Date.self,        forKey: .pickupTime)    ?? pickupTime
        hasDOTime     = try c.decodeIfPresent(Bool.self,        forKey: .hasDOTime)     ?? hasDOTime
        dropoffTime   = try c.decodeIfPresent(Date.self,        forKey: .dropoffTime)   ?? dropoffTime
        hasLeftBase   = try c.decodeIfPresent(Bool.self,        forKey: .hasLeftBase)   ?? hasLeftBase
        timeLeftBase  = try c.decodeIfPresent(Date.self,        forKey: .timeLeftBase)  ?? timeLeftBase
        hasBackBase   = try c.decodeIfPresent(Bool.self,        forKey: .hasBackBase)   ?? hasBackBase
        timeBackBase  = try c.decodeIfPresent(Date.self,        forKey: .timeBackBase)  ?? timeBackBase
        isHighlighted = try c.decodeIfPresent(Bool.self,        forKey: .isHighlighted) ?? isHighlighted
        showCountdown = try c.decodeIfPresent(Bool.self,        forKey: .showCountdown) ?? showCountdown
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
    func pdfData(driverName: String, companyName: String = "") -> Data {
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
            _ = drawText("RUNSHEET", in: ctx, at: CGPoint(x: margin, y: 14),
                         font: .systemFont(ofSize: 10, weight: .semibold),
                         color: UIColor.white.withAlphaComponent(0.55), width: contentW)

            // Driver name — always the prominent headline
            let name = driverName.isEmpty ? "Driver Report" : driverName
            _ = drawText(name, in: ctx, at: CGPoint(x: margin, y: 30),
                         font: .systemFont(ofSize: 26, weight: .bold),
                         color: .white, width: contentW)

            // Company name — its own line under the driver
            if !companyName.isEmpty {
                _ = drawText(companyName, in: ctx, at: CGPoint(x: margin, y: 60),
                             font: .systemFont(ofSize: 13, weight: .semibold),
                             color: UIColor.white.withAlphaComponent(0.85), width: contentW)
            }

            // Subtitle
            _ = drawText("Driver Timesheet Report  •  \(self.label)", in: ctx,
                         at: CGPoint(x: margin, y: companyName.isEmpty ? 68 : 78),
                         font: .systemFont(ofSize: 12, weight: .medium),
                         color: UIColor.white.withAlphaComponent(0.82), width: contentW)

            // Generated date
            let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
            _ = drawText("Generated: \(df.string(from: Date()))", in: ctx,
                         at: CGPoint(x: margin, y: companyName.isEmpty ? 90 : 96),
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
                // Dynamic row height: long client names wrap and notes can
                // span several lines — measure both so rows never overlap.
                let clientH = measureText(trip.clientName,
                                          font: .systemFont(ofSize: 10, weight: .medium),
                                          width: cols[3].1 - 4)
                let noteH: CGFloat = hasNotes
                    ? measureText("↳  \(trip.notes)",
                                  font: .italicSystemFont(ofSize: 8),
                                  width: contentW - 8)
                    : 0
                let bodyH = max(14, clientH)
                let rowH: CGFloat = 4 + bodyH + (hasNotes ? noteH + 4 : 0) + 4

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
                                 at: CGPoint(x: margin + 8, y: y + 6 + bodyH),
                                 font: .italicSystemFont(ofSize: 8), color: .gray, width: contentW - 8)
                }
                y += rowH
            }

            // ── Footer ─────────────────────────────────────────────────────
            let footerY: CGFloat = pageH - 20
            drawDivider(at: footerY - 6)
            _ = drawText("RunSheet  ·  Driver Timesheet System", in: ctx,
                         at: CGPoint(x: margin, y: footerY),
                         font: .systemFont(ofSize: 8), color: .lightGray, width: contentW / 2)
        }
    }
}

// MARK: - PDF Text Measurement
/// Height the given text needs when wrapped to `width` — used to size PDF
/// table rows dynamically so wrapped client names and multi-line notes
/// never overlap the next row.
private func measureText(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
    let para = NSMutableParagraphStyle()
    para.alignment = .left
    let astr = NSAttributedString(string: text, attributes: [
        .font: font, .paragraphStyle: para
    ])
    return ceil(astr.boundingRect(with: CGSize(width: width, height: 2000),
                                  options: .usesLineFragmentOrigin, context: nil).height)
}

// MARK: - CSV Export Helper
extension PayPeriod {
    var csvString: String {
        var rows: [String] = ["Date,Vehicle,Service,Client,PU Time,DO Time,Left Base,Back Base,Notes"]
        for t in trips {
            let row = [
                csvQuote(t.formattedDate),
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

// MARK: - Aggregate Trip Statistics
/// Single source of truth for the numbers shown on the Stats screen and in the
/// PDF export. `charterDuration` (drop-off − pickup, +1h travel) is the duty
/// span of a trip; charter hours sum that over charter trips, duty hours over all.
struct TripStats {
    let total:        Int
    let airport:      Int
    let charter:      Int
    let uniqueDays:   Int
    let charterSeconds: Double          // duty span summed over charter trips
    let dutySeconds:    Double          // duty span summed over ALL trips
    let longestCharterSeconds: Double?
    let weekdayCounts:  [Int]           // 7 entries, index 0 = Sunday … 6 = Saturday
    let serviceCounts:  [(ServiceType, Int)]
    let vehicleCounts:  [(Vehicle, Int)]
    /// Count of charter trips that actually have a measurable duration (≥2 times).
    let charterWithDuration: Int

    init(_ trips: [Trip]) {
        total      = trips.count
        airport    = trips.filter { $0.service == .airport }.count
        charter    = trips.filter { $0.service == .charter }.count
        uniqueDays = Set(trips.map { Calendar.current.startOfDay(for: $0.date) }).count

        let charterTrips     = trips.filter { $0.service == .charter }
        let charterDurations = charterTrips.compactMap(\.charterDuration)
        charterSeconds        = charterDurations.reduce(0, +)
        charterWithDuration   = charterDurations.count
        dutySeconds           = trips.compactMap(\.dutySpan).reduce(0, +)
        longestCharterSeconds = charterDurations.max()

        var wk = [Int](repeating: 0, count: 7)
        let cal = Calendar.current
        for t in trips { wk[(cal.component(.weekday, from: t.date) - 1) % 7] += 1 }
        weekdayCounts = wk

        serviceCounts = Self.tally(trips.map(\.service), builtInsFirst: ServiceType.builtIns)
        vehicleCounts = Self.tally(trips.map(\.vehicle), builtInsFirst: Vehicle.builtIns)
    }

    /// Counts occurrences of each value, listing the built-ins (in their canonical
    /// order) before any custom values, which follow in first-appearance order.
    private static func tally<T: Hashable>(_ values: [T], builtInsFirst order: [T]) -> [(T, Int)] {
        var counts: [T: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        var result: [(T, Int)] = []
        var seen = Set<T>()
        for o in order where counts[o] != nil {
            result.append((o, counts[o]!)); seen.insert(o)
        }
        for v in values where !seen.contains(v) {
            result.append((v, counts[v]!)); seen.insert(v)
        }
        return result
    }

    var avgTripsPerDay:   Double { uniqueDays > 0 ? Double(total) / Double(uniqueDays) : 0 }
    /// Average duty time per charter trip that has time data (excludes charter
    /// trips with no/insufficient times so they don't drag the average down).
    var avgCharterSeconds: Double { charterWithDuration > 0 ? charterSeconds / Double(charterWithDuration) : 0 }

    /// The weekday with the most trips (nil if there are no trips).
    var busiestWeekday: (name: String, count: Int)? {
        guard let maxCount = weekdayCounts.max(), maxCount > 0,
              let idx = weekdayCounts.firstIndex(of: maxCount) else { return nil }
        let names = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        return (names[idx], maxCount)
    }
}

/// Formats a duration in seconds as "Hh Mm" (or "Hh"), "--" when zero/negative.
func formatDurationHM(_ seconds: Double) -> String {
    guard seconds > 0 else { return "--" }
    let h = Int(seconds) / 3_600
    let m = (Int(seconds) % 3_600) / 60
    return m > 0 ? "\(h)h \(m)m" : "\(h)h"
}

// MARK: - Stats PDF Export Helper
/// Generates a multi-section PDF for Stats exports (All Time / Periods / Monthly).
/// Each element of `sections` is a (sectionTitle, trips) pair.
func makeStatsPDF(title: String, sections: [(String, [Trip])], driverName: String, companyName: String = "") -> Data {
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
    let overallStats = TripStats(allTrips)
    let airportCount = overallStats.airport
    let charterCount = overallStats.charter
    let charterHrsStr = formatDurationHM(overallStats.charterSeconds)

    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

    return renderer.pdfData { ctx in
        func drawDivider(cg: CGContext, at dy: CGFloat) {
            cg.setStrokeColor(UIColor.lightGray.cgColor)
            cg.setLineWidth(0.5)
            cg.move(to: CGPoint(x: margin, y: dy))
            cg.addLine(to: CGPoint(x: pageW - margin, y: dy))
            cg.strokePath()
        }

        // ── First page ───────────────────────────────────────────
        ctx.beginPage()
        var cg = ctx.cgContext

        // Header background
        cg.setFillColor(oceanDeep.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: pageW, height: 118))

        _ = drawText("RUNSHEET", in: ctx, at: CGPoint(x: margin, y: 14),
                     font: .systemFont(ofSize: 10, weight: .semibold),
                     color: UIColor.white.withAlphaComponent(0.55), width: contentW)

        let name = driverName.isEmpty ? "Driver Report" : driverName
        _ = drawText(name, in: ctx, at: CGPoint(x: margin, y: 30),
                     font: .systemFont(ofSize: 26, weight: .bold),
                     color: .white, width: contentW)

        // Company name — its own line under the driver
        if !companyName.isEmpty {
            _ = drawText(companyName, in: ctx, at: CGPoint(x: margin, y: 60),
                         font: .systemFont(ofSize: 13, weight: .semibold),
                         color: UIColor.white.withAlphaComponent(0.85), width: contentW)
        }

        _ = drawText(title, in: ctx, at: CGPoint(x: margin, y: companyName.isEmpty ? 68 : 78),
                     font: .systemFont(ofSize: 12, weight: .medium),
                     color: UIColor.white.withAlphaComponent(0.82), width: contentW)

        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        _ = drawText("Generated: \(df.string(from: Date()))", in: ctx,
                     at: CGPoint(x: margin, y: companyName.isEmpty ? 90 : 96),
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

        // ── Insights row ──────────────────────────────────────────
        let insights: [(String, String)] = [
            ("DUTY HRS",      formatDurationHM(overallStats.dutySeconds)),
            ("AVG TRIPS/DAY", overallStats.uniqueDays > 0 ? String(format: "%.1f", overallStats.avgTripsPerDay) : "--"),
            ("AVG CHARTER",   formatDurationHM(overallStats.avgCharterSeconds)),
            ("LONGEST",       formatDurationHM(overallStats.longestCharterSeconds ?? 0)),
            ("BUSIEST DAY",   overallStats.busiestWeekday.map { String($0.name.prefix(3)) } ?? "--"),
        ]
        let insW = contentW / CGFloat(insights.count)
        for (i, item) in insights.enumerated() {
            let sx = margin + CGFloat(i) * insW
            _ = drawText(item.0, in: ctx, at: CGPoint(x: sx, y: y),
                         font: .systemFont(ofSize: 8, weight: .semibold),
                         color: .gray, width: insW)
            _ = drawText(item.1, in: ctx, at: CGPoint(x: sx, y: y + 12),
                         font: .systemFont(ofSize: 15, weight: .bold),
                         color: oceanDeep, width: insW)
        }
        y += 40
        drawDivider(cg: ctx.cgContext, at: y)
        y += 8

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
                // Dynamic row height: long client names wrap and notes can
                // span several lines — measure both so rows never overlap.
                let clientH = measureText(trip.clientName,
                                          font: .systemFont(ofSize: 10, weight: .medium),
                                          width: cols[3].1 - 4)
                let noteH: CGFloat = hasNotes
                    ? measureText("↳  \(trip.notes)",
                                  font: .italicSystemFont(ofSize: 8),
                                  width: contentW - 8)
                    : 0
                let bodyH = max(14, clientH)
                let rowH: CGFloat = 4 + bodyH + (hasNotes ? noteH + 4 : 0) + 4

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
                                 at: CGPoint(x: margin + 8, y: y + 6 + bodyH),
                                 font: .italicSystemFont(ofSize: 8), color: .gray, width: contentW - 8)
                }
                y += rowH
            }
            y += 8
        }

        // Footer on last page
        let footerY: CGFloat = pageH - 20
        drawDivider(cg: ctx.cgContext, at: footerY - 6)
        _ = drawText("RunSheet  ·  Driver Timesheet System", in: ctx,
                     at: CGPoint(x: margin, y: footerY),
                     font: .systemFont(ofSize: 8), color: .lightGray, width: contentW / 2)
    }
}
