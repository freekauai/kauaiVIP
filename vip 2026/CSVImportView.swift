// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — CSV Import                       ║
// ║           CSVImportView.swift                                ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @EnvironmentObject var store: TimesheetStore
    @Environment(\.dismiss) var dismiss

    @State private var parsedTrips:  [Trip]   = []
    @State private var parseError:   String?  = nil
    @State private var fileName:     String   = ""
    @State private var showPicker    = false
    @State private var startDate     = Calendar.current.startOfDay(for: Date())
    @State private var endDate       = Calendar.current.date(byAdding: .day, value: 13, to: Calendar.current.startOfDay(for: Date())) ?? Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {
                        fileCard
                        if !parsedTrips.isEmpty { datesCard }
                        if !parsedTrips.isEmpty && hasOverlap { overlapCard }
                        if !parsedTrips.isEmpty { previewCard }
                        if let err = parseError { errorCard(err) }
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                }
                if !parsedTrips.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Import") { doImport() }
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.coral)
                    }
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { handlePickerResult($0) }
        }
    }

    // MARK: - Cards

    private var fileCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("CSV FILE").labelStyle()

                if fileName.isEmpty {
                    Text("Pick a CSV exported from this app, or any file with columns: Date, Vehicle, Service, Client, PU Time, DO Time, Left Base, Back Base, Notes. A Period column at the start is also accepted.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Button(action: { showPicker = true }) {
                    Label(fileName.isEmpty ? "Choose CSV File" : fileName,
                          systemImage: "doc.text.fill")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(CoralButtonStyle())

                if !parsedTrips.isEmpty {
                    Label("\(parsedTrips.count) trips ready to import",
                          systemImage: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }

    private var datesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("PAY PERIOD DATES").labelStyle()
                DatePicker("Start Date", selection: $startDate,
                           displayedComponents: .date)
                    .foregroundColor(AppTheme.textPrimary)
                DatePicker("End Date", selection: $endDate,
                           in: startDate...,
                           displayedComponents: .date)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }

    private var previewCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("PREVIEW").labelStyle()
                ForEach(parsedTrips.prefix(5)) { trip in
                    HStack(spacing: 10) {
                        Text(trip.service.icon).font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.clientName.isEmpty ? "(no client)" : trip.clientName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("\(trip.formattedDate) · \(trip.vehicle.rawValue) · \(trip.service.rawValue)")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
                if parsedTrips.count > 5 {
                    Text("+ \(parsedTrips.count - 5) more trips…")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// Same warning NewPeriodView shows — non-blocking, the driver decides.
    private var hasOverlap: Bool {
        store.periods.contains { existing in
            !(endDate < existing.startDate || startDate > existing.endDate)
        }
    }

    private var overlapCard: some View {
        AppCard {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.warning)
                Text("This period overlaps with an existing period.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.warning)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        AppCard {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.error)
                .font(.system(size: 13))
        }
    }

    // MARK: - File Handling

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        parseError  = nil
        parsedTrips = []
        fileName    = ""

        switch result {
        case .failure(let err):
            parseError = "Could not open file: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            // Read the file off the main thread to avoid blocking the UI.
            Task {
                let secured = url.startAccessingSecurityScopedResource()
                // Bridge synchronous file I/O to the async world via a background queue.
                let rawText: String? = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let text = try? String(contentsOf: url, encoding: .utf8)
                        continuation.resume(returning: text)
                    }
                }
                if secured { url.stopAccessingSecurityScopedResource() }

                guard let rawText else {
                    parseError = "Could not read file — ensure it is a UTF-8 CSV."
                    return
                }

                let localName         = url.lastPathComponent
                let (trips, csvError) = parseCSV(rawText)
                // All state mutations happen on MainActor (Task inherits caller's actor context).
                fileName = localName
                if let csvError {
                    parseError = csvError
                } else {
                    parsedTrips = trips
                    if let minDate = trips.map(\.date).min(),
                       let maxDate = trips.map(\.date).max() {
                        startDate = Calendar.current.startOfDay(for: minDate)
                        endDate   = Calendar.current.startOfDay(for: maxDate)
                    }
                }
            }
        }
    }

    // MARK: - CSV Parser

    private func parseCSV(_ text: String) -> ([Trip], String?) {
        var lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return ([], "File is empty.") }

        // Drop header row if present (contains "date" in any column)
        if lines[0].lowercased().contains("date") { lines.removeFirst() }
        guard !lines.isEmpty else { return ([], "No trip rows found after header.") }

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US")

        let timeFmt = DateFormatter()
        timeFmt.locale    = Locale(identifier: "en_US")
        timeFmt.dateFormat = "h:mm a"

        // Parse a single date field against every supported format.
        func tryDate(_ s: String) -> Date? {
            let t = s.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return nil }
            for fmt in ["MMM d, yyyy", "M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "d MMM yyyy"] {
                dateFmt.dateFormat = fmt
                if let d = dateFmt.date(from: t) { return d }
            }
            return nil
        }

        var trips: [Trip] = []

        for line in lines {
            let raw = splitCSVLine(line)
            guard raw.count >= 9 else { continue }

            // Locate the date column and the 8 trip columns that follow it.
            // Tolerates an optional leading Period/Month column, and an
            // abbreviated date ("MMM d, yyyy") that an older, buggy export
            // wrote unquoted — its internal comma splits it across two fields.
            var tripDate: Date? = nil
            var cols: [String]  = []   // vehicle, service, client, pu, do, lb, bb, notes
            let candidates: [(Date?, Int)] = [
                (tryDate(raw[0]), 1),                                            // date @ 0
                raw.count > 1 ? (tryDate(raw[1]), 2)                : (nil, 0),  // Period prefix, date @ 1
                raw.count > 1 ? (tryDate(raw[0] + ", " + raw[1]), 2): (nil, 0),  // comma-split date @ 0+1
                raw.count > 2 ? (tryDate(raw[1] + ", " + raw[2]), 3): (nil, 0),  // prefix + comma-split date @ 1+2
            ]
            for (d, restStart) in candidates {
                // Need at least vehicle…back-base (7); notes is optional.
                if let d, raw.count - restStart >= 7 {
                    tripDate = d
                    cols = Array(raw[restStart...])
                    break
                }
            }
            guard let tripDate, cols.count >= 7 else { continue }

            let vehicleStr = cols[0]
            let serviceStr = cols[1]
            let clientStr  = cols[2]
            let puStr      = cols[3]
            let doStr      = cols[4]
            let lbStr      = cols[5]
            let bbStr      = cols[6]
            let notesStr   = cols.count > 7 ? cols[7] : ""

            // Match built-ins case-insensitively (so "charter" canonicalizes to
            // "Charter" and keeps its charter-hours semantics); otherwise import
            // the name verbatim as a custom vehicle/service.
            let vehicle = Vehicle.builtIns.first {
                $0.rawValue.lowercased() == vehicleStr.lowercased()
            } ?? (vehicleStr.isEmpty ? .suv : Vehicle(rawValue: vehicleStr))
            let service = ServiceType.builtIns.first {
                $0.rawValue.lowercased() == serviceStr.lowercased()
            } ?? (serviceStr.isEmpty ? .airport : ServiceType(rawValue: serviceStr))

            func parseTime(_ s: String) -> Date? {
                guard s != "--", !s.isEmpty else { return nil }
                // iOS `formatted()` separates the AM/PM marker with a narrow
                // no-break space (U+202F); normalize so DateFormatter can parse.
                let normalized = s
                    .replacingOccurrences(of: "\u{202F}", with: " ")
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                guard let t = timeFmt.date(from: normalized) else { return nil }
                let cal   = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: tripDate)
                comps.hour   = cal.component(.hour,   from: t)
                comps.minute = cal.component(.minute, from: t)
                return cal.date(from: comps)
            }

            let puTime = parseTime(puStr)
            let doTime = parseTime(doStr)
            let lbTime = parseTime(lbStr)
            let bbTime = parseTime(bbStr)

            trips.append(Trip(
                date:          tripDate,
                vehicle:       vehicle,
                service:       service,
                clientName:    clientStr,
                notes:         notesStr,
                hasPUTime:     puTime != nil, pickupTime:   puTime,
                hasDOTime:     doTime != nil, dropoffTime:  doTime,
                hasLeftBase:   lbTime != nil, timeLeftBase: lbTime,
                hasBackBase:   bbTime != nil, timeBackBase: bbTime
            ))
        }

        if trips.isEmpty {
            return ([], "No valid trip rows could be parsed. Check that the file uses the expected column order.")
        }
        return (trips, nil)
    }

    /// RFC 4180-compliant CSV field splitter.
    /// Handles `""` as an escaped literal quote inside a quoted field.
    private func splitCSVLine(_ line: String) -> [String] {
        var fields:  [String] = []
        var current  = ""
        var inQuotes = false
        var idx      = line.startIndex

        while idx < line.endIndex {
            let ch = line[idx]
            if ch == "\"" {
                if inQuotes {
                    let next = line.index(after: idx)
                    if next < line.endIndex && line[next] == "\"" {
                        // "" inside quoted field → single literal quote
                        current.append("\"")
                        idx = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false   // closing quote
                    }
                } else {
                    inQuotes = true        // opening quote
                }
            } else if ch == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
            idx = line.index(after: idx)
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // MARK: - Import

    private func doImport() {
        guard endDate >= startDate else {
            parseError = "End date must be on or after start date."
            return
        }
        // Use day + 1 (inclusive count) — same logic as NewPeriodView.
        let dayCount = (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        guard (14...16).contains(dayCount) else {
            parseError = "Pay periods should be 14–16 days (\(dayCount) days selected). Adjust the start or end date."
            return
        }
        var period   = PayPeriod(startDate: startDate, endDate: endDate)
        period.trips = parsedTrips
        // Register any custom vehicles/services the import introduced, so they
        // appear in the Add-Trip picker and Settings rather than being orphaned
        // on imported trips. addCustom* de-dupes built-ins and existing entries.
        for trip in parsedTrips {
            store.addCustomVehicle(trip.vehicle.rawValue)
            store.addCustomService(trip.service.rawValue)
        }
        store.addPeriod(period)
        dismiss()
    }
}
