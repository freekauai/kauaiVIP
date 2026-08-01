// ╔══════════════════════════════════════════════════════════════╗
// ║           RUNSHEET — Paste Trips from Dispatch Text          ║
// ║           PasteImportView.swift                              ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Parses the dispatch-text format trips arrive in ("7-31-26 / Run 1 /
// 930 am sprinter pickup at … / 11 pax / Name: Cellura / phone") into
// reviewable trips. The driver pastes, previews, unchecks anything
// wrong, and approves — no retyping.

import SwiftUI

// MARK: - Parsed Trip (preview model)
struct ParsedTrip: Identifiable {
    let id = UUID()
    var date:       Date
    var pickupTime: Date?
    var vehicle:    Vehicle
    var service:    ServiceType
    var clientName: String
    var notes:      String
    var include:    Bool = true
    var isDuplicate:    Bool = false   // matches an existing trip in this period
    var outsidePeriod:  Bool = false   // dated outside the period's range
}

// MARK: - Dispatch Text Parser
enum DispatchParser {

    /// Airline / airport hints → default the run to the Airport service.
    private static let airportHints = [
        "southwest", "delta", "united", "hawaiian", "alaska", "american",
        "flight", "lih", "airport", "#"
    ]
    /// Hourly/tour hints → the run is a Charter (drives charter-hours billing).
    private static let charterHints = [
        "charter", "tour", "luau", "wedding", "hourly", "as directed",
        "drive around", "wait and return"
    ]

    static func parse(_ text: String, vehicles: [Vehicle]) -> [ParsedTrip] {
        var results: [ParsedTrip] = []
        var currentDate: Date? = nil

        // Builder state for the run currently being read
        var puTime:  Date? = nil
        var vehicle: Vehicle = vehicles.first ?? .suv
        var service: ServiceType = .airport
        var client:  String = ""
        var route:   String = ""
        var pax:     String = ""
        var phone:   String = ""
        var hasContent = false

        func flush() {
            defer {
                puTime = nil; client = ""; route = ""; pax = ""; phone = ""
                vehicle = vehicles.first ?? .suv; service = .airport
                hasContent = false
            }
            guard hasContent, let date = currentDate else { return }
            var noteParts: [String] = []
            if !route.isEmpty { noteParts.append(route) }
            if !pax.isEmpty   { noteParts.append(pax) }
            if !phone.isEmpty { noteParts.append(phone) }
            results.append(ParsedTrip(
                date:       date,
                pickupTime: puTime,
                vehicle:    vehicle,
                service:    service,
                clientName: client,
                notes:      noteParts.joined(separator: " · ")
            ))
        }

        let cal = Calendar.current

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let lower = line.lowercased()

            // ── Date header: "7-31-26" / "7-30-26 Thursday" / "7/31/2026" ──
            if let m = line.range(of: #"^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})"#,
                                  options: .regularExpression) {
                let parts = line[m].split(whereSeparator: { "-/".contains($0) }).compactMap { Int($0) }
                if parts.count == 3 {
                    flush()
                    let year = parts[2] < 100 ? 2000 + parts[2] : parts[2]
                    currentDate = cal.date(from: DateComponents(
                        year: year, month: parts[0], day: parts[1], hour: 12))
                    continue
                }
            }

            // ── Run marker: "Run 1" ──
            if lower.range(of: #"^run\s*\d+"#, options: .regularExpression) != nil {
                flush()
                continue
            }

            // ── Time + route: "930 am …" / "11:00 am …" / "9 am …" ──
            if let m = line.range(of: #"^(\d{1,2})(?:[:.]?(\d{2}))?\s*(am|pm)"#,
                                  options: [.regularExpression, .caseInsensitive]) {
                // New time without a Run marker → treat as a new run
                if puTime != nil { flush() }

                let stamp = String(line[m]).lowercased()
                let digits = stamp.filter(\.isNumber)
                let isPM = stamp.contains("pm")
                var hour   = 0
                var minute = 0
                if digits.count >= 3 {
                    hour   = Int(digits.dropLast(2)) ?? 0
                    minute = Int(digits.suffix(2)) ?? 0
                } else {
                    hour = Int(digits) ?? 0
                }
                if isPM && hour != 12 { hour += 12 }
                if !isPM && hour == 12 { hour = 0 }
                if let date = currentDate {
                    puTime = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date)
                }

                // Route text = the line minus the time stamp, kept verbatim
                route = String(line[m.upperBound...]).trimmingCharacters(in: .whitespaces)
                hasContent = true

                // Vehicle: word-boundary match, full names first so
                // "sprinter b" hits Sprinter B; bare "sprinter" then falls
                // back to the first Sprinter. ("Bus" can't match "business".)
                let words = Set(lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                    .map(String.init))
                if let full = vehicles.first(where: { v in
                    let tokens = v.rawValue.lowercased().split(separator: " ").map(String.init)
                    return tokens.count > 1 && tokens.allSatisfy(words.contains)
                }) {
                    vehicle = full
                } else if let partial = vehicles.first(where: { v in
                    guard let first = v.rawValue.lowercased().split(separator: " ").first
                    else { return false }
                    return words.contains(String(first))
                }) {
                    vehicle = partial
                }
                // Service: charter hints win over the airport default —
                // charter-hours billing keys off service == .charter.
                if charterHints.contains(where: { lower.contains($0) }) {
                    service = .charter
                } else if airportHints.contains(where: { lower.contains($0) }) {
                    service = .airport
                }
                continue
            }

            // ── Passenger count: "11 pax" ──
            if lower.range(of: #"^\d+\s*pax"#, options: .regularExpression) != nil {
                pax = line
                hasContent = true
                continue
            }

            // ── Client: "Name: Cellura" ──
            if lower.hasPrefix("name") {
                client = line.drop(while: { !":".contains($0) })
                    .dropFirst()
                    .trimmingCharacters(in: .whitespaces)
                if client.isEmpty {
                    client = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                }
                hasContent = true
                continue
            }

            // ── Phone number line ──
            if line.count >= 7,
               line.allSatisfy({ $0.isNumber || " -()+.".contains($0) }) {
                phone = line
                hasContent = true
                continue
            }
        }
        flush()
        return results
    }
}

// MARK: - Paste Import Sheet
struct PasteImportView: View {
    let periodID: UUID

    @EnvironmentObject var store: TimesheetStore
    @Environment(\.dismiss) var dismiss

    @State private var rawText = ""
    @State private var parsed: [ParsedTrip] = []
    @State private var didParse = false
    @State private var lastParsedText = ""
    @State private var didApprove = false

    private var includedCount: Int { parsed.filter(\.include).count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {
                        inputCard
                        if didParse {
                            if parsed.isEmpty {
                                AppCard {
                                    Label(emptyResultMessage,
                                          systemImage: "questionmark.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            } else {
                                previewList
                            }
                        }
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.bottom, 90)
                }
            }
            .onChange(of: rawText) { _, newText in
                // Text edited after Preview → the parse is stale; force re-preview
                if didParse && newText != lastParsedText {
                    didParse = false
                    parsed = []
                }
            }
            .navigationTitle("📋 Paste Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if includedCount > 0 {
                        Button("Add \(includedCount)") { approve() }
                            .foregroundColor(AppTheme.coral)
                            .fontWeight(.bold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if includedCount > 0 {
                    CoralButton("✅ Add \(includedCount) Trip\(includedCount == 1 ? "" : "s")") {
                        approve()
                    }
                    .padding(.horizontal, AppTheme.screenPad)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: Input

    private var inputCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("DISPATCH TEXT").labelStyle()
                Text("Paste the trips exactly as you received them — dates, Run 1/2/3, times, pax, and names are picked up automatically.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)

                TextEditor(text: $rawText)
                    .frame(minHeight: 120, maxHeight: 200)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AppTheme.oceanLight.opacity(0.4))
                    .cornerRadius(AppTheme.fieldRadius)

                HStack(spacing: 10) {
                    Button {
                        if let clip = UIPasteboard.general.string, !clip.isEmpty {
                            rawText = clip
                            runParse()
                        } else if let provider = UIPasteboard.general.itemProviders.first,
                                  provider.canLoadObject(ofClass: NSString.self) {
                            // The synchronous string can be nil right after the
                            // permission grant (promised items) — load async.
                            _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
                                if let str = obj as? String, !str.isEmpty {
                                    DispatchQueue.main.async {
                                        rawText = str
                                        runParse()
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.coral)

                    Button {
                        runParse()
                    } label: {
                        Label("Preview", systemImage: "eye")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.coral)
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: Preview

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FOUND \(parsed.count) RUN\(parsed.count == 1 ? "" : "S") — TAP ✓ TO INCLUDE · FIELDS ARE EDITABLE")
                .labelStyle()

            ForEach($parsed) { $trip in
                AppCard {
                    HStack(alignment: .top, spacing: 12) {
                        // Include/exclude lives on the checkmark only — the
                        // rest of the card is editable fields.
                        Button {
                            trip.include.toggle()
                        } label: {
                            Image(systemName: trip.include ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(trip.include ? AppTheme.success : AppTheme.textTertiary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(trip.include ? "Exclude this run" : "Include this run")

                        VStack(alignment: .leading, spacing: 6) {
                            // ── Date · pickup time · service — all editable ──
                            HStack(spacing: 6) {
                                DatePicker("", selection: $trip.date, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)

                                if trip.pickupTime != nil {
                                    DatePicker("", selection: Binding(
                                        get: { trip.pickupTime ?? trip.date },
                                        set: { trip.pickupTime = $0 }
                                    ), displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                } else {
                                    Button {
                                        trip.pickupTime = Calendar.current.date(
                                            bySettingHour: 9, minute: 0, second: 0, of: trip.date)
                                    } label: {
                                        Label("Time", systemImage: "plus.circle")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppTheme.coral)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer(minLength: 0)
                                Menu {
                                    ForEach(store.allServices) { svc in
                                        Button(svc.rawValue) { trip.service = svc }
                                    }
                                } label: {
                                    Text("\(trip.service.icon) \(trip.service.rawValue) ⌄")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.info)
                                }
                            }

                            // ── Client name — editable ──
                            TextField("Client name", text: $trip.clientName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .textInputAutocapitalization(.words)

                            // ── Vehicle — tappable to correct ──
                            Menu {
                                ForEach(store.allVehicles) { v in
                                    Button("\(v.icon) \(v.rawValue)") { trip.vehicle = v }
                                }
                            } label: {
                                Text("\(trip.vehicle.icon) \(trip.vehicle.rawValue) ⌄")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            if trip.isDuplicate {
                                Label("Possible duplicate — already in this period",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.warning)
                            }
                            if trip.outsidePeriod {
                                Label("Dated outside this pay period",
                                      systemImage: "calendar.badge.exclamationmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.warning)
                            }

                            // ── Notes — editable ──
                            TextField("Notes", text: $trip.notes, axis: .vertical)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1...4)
                        }
                    }
                }
                .opacity(trip.include ? 1.0 : 0.45)
            }
        }
    }

    // MARK: Actions

    private func runParse() {
        var trips = DispatchParser.parse(rawText, vehicles: store.allVehicles)

        let cal = Calendar.current
        let period   = store.periods.first(where: { $0.id == periodID })
        let existing = period?.trips ?? []

        for i in trips.indices {
            let t = trips[i]
            // Duplicate: same day + same client (+ same pickup time when both
            // have one) as a trip already in this period → excluded by default
            // so re-pasting a dispatch text can't silently double-add.
            trips[i].isDuplicate = existing.contains { e in
                !t.clientName.isEmpty   // unnamed runs never count as duplicates
                && cal.isDate(e.date, inSameDayAs: t.date)
                && e.clientName.caseInsensitiveCompare(t.clientName) == .orderedSame
                && (t.pickupTime == nil || !e.hasPUTime || e.pickupTime.map {
                        cal.dateComponents([.hour, .minute], from: $0)
                        == cal.dateComponents([.hour, .minute], from: t.pickupTime!)
                    } ?? false)
            }
            if trips[i].isDuplicate { trips[i].include = false }

            // Dated outside this pay period → flag, but let the driver decide
            if let period {
                let range = min(period.startDate, period.endDate)...max(period.startDate, period.endDate)
                trips[i].outsidePeriod = !range.contains(t.date)
                    && !cal.isDate(t.date, inSameDayAs: period.startDate)
                    && !cal.isDate(t.date, inSameDayAs: period.endDate)
            }
        }

        parsed = trips
        didParse = true
        lastParsedText = rawText
    }

    private var emptyResultMessage: String {
        let hasDate = rawText.range(of: #"\d{1,2}[-/]\d{1,2}[-/]\d{2,4}"#,
                                    options: .regularExpression) != nil
        return hasDate
            ? "No runs found — check the pasted text."
            : "No date line found — the text needs a date like 7-31-26 above the runs."
    }

    private func approve() {
        guard !didApprove else { return }   // double-tap → double-add guard
        didApprove = true
        for p in parsed where p.include {
            var trip = Trip()
            trip.date        = p.date
            trip.vehicle     = p.vehicle
            trip.service     = p.service
            trip.clientName  = p.clientName
            trip.notes       = p.notes
            if let pu = p.pickupTime {
                trip.hasPUTime  = true
                trip.pickupTime = pu
            }
            store.addTrip(trip, toPeriod: periodID)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
