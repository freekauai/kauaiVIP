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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                    .colorScheme(.dark)
                DatePicker("End Date", selection: $endDate,
                           in: startDate...,
                           displayedComponents: .date)
                    .foregroundColor(AppTheme.textPrimary)
                    .colorScheme(.dark)
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
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                parseError = "Could not read file — ensure it is a UTF-8 CSV."
                return
            }

            fileName = url.lastPathComponent
            let (trips, error) = parseCSV(text)
            if let error {
                parseError = error
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

        var trips: [Trip] = []

        for line in lines {
            let raw = splitCSVLine(line)
            // Support 9-column (no Period) and 10-column (with Period prefix) exports
            let off = raw.count >= 10 ? 1 : 0
            guard raw.count >= 9 + off else { continue }

            let dateStr    = raw[0 + off]
            let vehicleStr = raw[1 + off]
            let serviceStr = raw[2 + off]
            let clientStr  = raw[3 + off]
            let puStr      = raw[4 + off]
            let doStr      = raw[5 + off]
            let lbStr      = raw[6 + off]
            let bbStr      = raw[7 + off]
            let notesStr   = raw.count > 8 + off ? raw[8 + off] : ""

            var tripDate: Date? = nil
            for fmt in ["MMM d, yyyy", "M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "d MMM yyyy"] {
                dateFmt.dateFormat = fmt
                if let d = dateFmt.date(from: dateStr) { tripDate = d; break }
            }
            guard let tripDate else { continue }

            let vehicle = Vehicle.allCases.first {
                $0.rawValue.lowercased() == vehicleStr.lowercased()
            } ?? .suv
            let service = ServiceType.allCases.first {
                $0.rawValue.lowercased() == serviceStr.lowercased()
            } ?? .airport

            func parseTime(_ s: String) -> Date? {
                guard s != "--", !s.isEmpty else { return nil }
                guard let t = timeFmt.date(from: s) else { return nil }
                let cal   = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: tripDate)
                comps.hour   = cal.component(.hour,   from: t)
                comps.minute = cal.component(.minute, from: t)
                return cal.date(from: comps)
            }

            let pu = parseTime(puStr)
            let dо = parseTime(doStr)
            let lb = parseTime(lbStr)
            let bb = parseTime(bbStr)

            trips.append(Trip(
                date:          tripDate,
                vehicle:       vehicle,
                service:       service,
                clientName:    clientStr,
                notes:         notesStr,
                hasPUTime:     pu != nil, pickupTime:   pu,
                hasDOTime:     dо != nil, dropoffTime:  dо,
                hasLeftBase:   lb != nil, timeLeftBase: lb,
                hasBackBase:   bb != nil, timeBackBase: bb
            ))
        }

        if trips.isEmpty {
            return ([], "No valid trip rows could be parsed. Check that the file uses the expected column order.")
        }
        return (trips, nil)
    }

    private func splitCSVLine(_ line: String) -> [String] {
        var fields:   [String] = []
        var current   = ""
        var inQuotes  = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // MARK: - Import

    private func doImport() {
        var period       = PayPeriod(startDate: startDate, endDate: endDate)
        period.trips     = parsedTrips
        store.addPeriod(period)
        dismiss()
    }
}
