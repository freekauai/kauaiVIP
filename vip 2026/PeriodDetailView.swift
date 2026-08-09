// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Period Detail Screen             ║
// ║           PeriodDetailView.swift                             ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI
import Combine

struct PeriodDetailView: View {
    let periodID: UUID
    @Binding var activeModal: ContentView.AppModal?

    @EnvironmentObject var store:          TimesheetStore
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var bridgeService:  BridgeService
    @Environment(\.dismiss) var dismiss

    @State private var showAddTrip  = false
    @State private var showPasteImport = false
    @State private var editingTrip: Trip? = nil
    @State private var tripToDelete: Trip? = nil
    @State private var showDeleteAlert = false
    @State private var showDeletePeriodAlert = false
    @State private var showSettings = false
    @State private var now = Date()

    // Undo toast for isActive toggle (issue #10)
    @State private var undoableTrip: Trip? = nil
    // Undo toast for a just-deleted trip
    @State private var deletedTrip: Trip? = nil
    @State private var deleteToastToken = UUID()
    @State private var toggleToastToken = UUID()

    // Global countdown on/off — shared across views via @AppStorage
    @AppStorage("countdownEnabled") private var countdownEnabled: Bool = true

    // 1-second timer drives both LIVE badge and countdown displays
    private let tripTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Derive period from store so updates are live
    private var period: PayPeriod? {
        store.periods.first { $0.id == periodID }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.oceanDeep.ignoresSafeArea()

            if let period = period {
                VStack(spacing: 0) {
                    TrafficBanner()

                    PeriodTopButtons(
                        onWeather: { activeModal = .weather },
                        onMap:     { activeModal = .map },
                        onTraffic: { activeModal = .traffic },
                        onStats:   { activeModal = .stats }
                    )
                    .environmentObject(weatherManager)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            driverHeader
                            summaryCard(period: period)
                            tripsSection(period: period)
                            AppFooter()
                        }
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        weatherManager.refresh()
                        bridgeService.refresh()
                    }
                }

                // Floating Add Trip
                VStack {
                    Spacer()
                    CoralButton("+ Add Trip", action: { showAddTrip = true })
                        .padding(.horizontal, AppTheme.screenPad)
                        .padding(.bottom, 28)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.oceanDeep.opacity(0), AppTheme.oceanDeep],
                                startPoint: .top, endPoint: .bottom
                            )
                            .allowsHitTesting(false)   // fade is decor — don't eat taps
                        )
                }
            } else {
                Text("Period not found").foregroundColor(AppTheme.textTertiary)
            }
        }
        .navigationTitle(period?.label ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(AppTheme.coral)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showPasteImport = true }) {
                        Label("Paste Trips from Text", systemImage: "doc.on.clipboard")
                    }
                    Divider()
                    Button(action: exportPDF) {
                        Label("Export PDF", systemImage: "doc.fill")
                    }
                    Button(action: exportCSV) {
                        Label("Export CSV", systemImage: "tablecells")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeletePeriodAlert = true
                    } label: {
                        Label("Delete Period", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.coral)
                }
            }
        }
        // `tripTimer` is an .autoconnect() publisher: Combine connects it when
        // this view subscribes and tears it down when the subscription ends.
        // Do NOT manually connect/cancel the upstream — doing so permanently
        // kills the timer so it never resumes when the view reappears.
        .onReceive(tripTimer) { now = $0 }
        // Undo toast overlay (delete)
        .overlay(alignment: .bottom) {
            if let dt = deletedTrip {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.error)
                    Text("Trip deleted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Button("Undo") {
                        store.addTrip(dt, toPeriod: periodID)
                        withAnimation { deletedTrip = nil }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.coral)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.oceanMedium)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                .padding(.horizontal, AppTheme.screenPad)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: deletedTrip?.id)
        // Undo toast overlay
        .overlay(alignment: .bottom) {
            if let ut = undoableTrip {
                HStack(spacing: 12) {
                    Image(systemName: ut.isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(ut.isActive ? AppTheme.success : AppTheme.textTertiary)
                    Text(ut.isActive ? "Trip activated" : "Trip deactivated")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Button("Undo") {
                        withAnimation { undoableTrip = nil }
                        store.updateTrip(ut, inPeriod: periodID)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.coral)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.oceanMedium)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                .padding(.horizontal, AppTheme.screenPad)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: undoableTrip?.id)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showPasteImport) {
            PasteImportView(periodID: periodID)
                .environmentObject(store)   // sheets don't inherit env objects
        }
        .sheet(isPresented: $showAddTrip) {
            TripFormView(periodID: periodID, existingTrip: nil)
                .environmentObject(store)            // sheets don't inherit env objects
                .environmentObject(bridgeService)    // TripFormView embeds TrafficBanner
                .environmentObject(weatherManager)
        }
        .sheet(item: $editingTrip) { trip in
            TripFormView(periodID: periodID, existingTrip: trip)
                .environmentObject(store)
                .environmentObject(bridgeService)
                .environmentObject(weatherManager)
        }
        .alert("Delete Trip?", isPresented: $showDeleteAlert, presenting: tripToDelete) { trip in
            Button("Delete", role: .destructive) {
                store.deleteTrip(trip, fromPeriod: periodID)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                // Same undo toast used for activate/deactivate — restores the trip.
                let token = UUID()
                deleteToastToken = token
                withAnimation {
                    undoableTrip = nil          // one toast slot — don't stack
                    deletedTrip  = trip
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation { if deleteToastToken == token { deletedTrip = nil } }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { trip in
            // No "cannot be undone" here — deleting shows an Undo toast.
            Text("Remove \(trip.service.rawValue) trip for \(trip.clientName)?")
        }
        .alert("Delete Period?", isPresented: $showDeletePeriodAlert) {
            Button("Delete", role: .destructive) {
                if let p = period { store.deletePeriod(p) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove “\(period?.label ?? "this period")” and all \(period?.trips.count ?? 0) trips? This cannot be undone.")
        }
    }

    // MARK: - Driver Header
    private var driverHeader: some View {
        // One chip per countdown-enabled trip, soonest first, each counting
        // to that trip's next upcoming time point.
        let enabled = (countdownEnabled ? (period?.trips ?? []) : [])
            .filter { $0.isActive && $0.showCountdown }
            .compactMap { trip -> (String, Date)? in
                guard let t = trip.nextUpcomingTime(after: now) else { return nil }
                let label = trip.clientName.isEmpty ? trip.service.rawValue : trip.clientName
                return (label, t)
            }
            .sorted { $0.1 < $1.1 }
        let chips = enabled.map { (label: $0.0, value: countdownLabel(now: now, target: $0.1)) }

        // Fall back to the single "Next:" line when no trips opted in
        let cd: String? = {
            guard chips.isEmpty, countdownEnabled,
                  let t = nextUpTripTime, t > now else { return nil }
            return countdownLabel(now: now, target: t)
        }()
        return DriverBand(
            name: store.driverName,
            company: store.companyName.isEmpty ? nil : store.companyName,
            countdown: cd,
            countdowns: chips
        )
    }

    // MARK: - Summary Card
    private func summaryCard(period: PayPeriod) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("PERIOD SUMMARY")
                    .labelStyle()

                HStack(spacing: 0) {
                    SummaryMetric(label: "Trips",        value: "\(period.trips.count)",                                   color: AppTheme.textPrimary)
                    Divider().frame(height: 40).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SummaryMetric(label: "Airport",      value: "\(period.trips.filter { $0.service == .airport }.count)", color: AppTheme.info)
                    Divider().frame(height: 40).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SummaryMetric(label: "Charter",      value: "\(period.trips.filter { $0.service == .charter }.count)", color: AppTheme.success)
                    Divider().frame(height: 40).background(AppTheme.oceanLight).padding(.horizontal, 10)
                    SummaryMetric(label: "Charter Hrs",  value: period.formattedCharterHours,                              color: AppTheme.warning)
                }
            }
        }
        .padding(.horizontal, AppTheme.screenPad)
        .padding(.top, AppTheme.cardSpacing)
    }

    // MARK: - Next-Up Trip ID
    /// The ID of the soonest future *active* trip that isn't currently live.
    private var nextUpTripID: UUID? {
        guard let period = period else { return nil }
        let cal   = Calendar.current
        let today = cal.startOfDay(for: now)
        // Only consider user-enabled trips that aren't currently live
        let candidates = period.trips.filter { $0.isActive && !$0.isLive(at: now) }

        // 1. Prefer explicit future start times — earliestEnteredTime anchors the
        // entered clock time onto the trip's date, so the badge agrees with the
        // header countdown and trips dated tomorrow aren't skipped after today's
        // clock time passes.
        let timed = candidates.compactMap { trip -> (UUID, Date)? in
            guard let t = trip.earliestEnteredTime, t > now else { return nil }
            return (trip.id, t)
        }
        if let soonest = timed.min(by: { $0.1 < $1.1 }) { return soonest.0 }

        // 2. Fall back: trips on today or a future date (no explicit time logged)
        let byDate = candidates.compactMap { trip -> (UUID, Date)? in
            let day = cal.startOfDay(for: trip.date)
            return day >= today ? (trip.id, day) : nil
        }
        return byDate.min(by: { $0.1 < $1.1 })?.0
    }

    /// The earliest departure time of the soonest upcoming active trip (for the header countdown).
    private var nextUpTripTime: Date? {
        guard let period = period else { return nil }
        return period.trips
            .filter { $0.isActive && !$0.isLive(at: now) }
            .compactMap { $0.earliestEnteredTime }
            .filter { $0 > now }
            .min()
    }

    // MARK: - Countdown Formatter
    private func countdownLabel(now: Date, target: Date) -> String {
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else { return "Departed" }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    // MARK: - Trips Section
    private func tripsSection(period: PayPeriod) -> some View {
        VStack(spacing: 0) {
            SectionLabel(text: "Trips (\(period.trips.count))")

            if period.trips.isEmpty {
                EmptyStateView(
                    icon: "🚗",
                    message: "No Trips Yet",
                    sub: "Tap '+ Add Trip' below to log your first trip for this period."
                )
            } else {
                let nextUp = nextUpTripID
                // This body re-evaluates every second (countdown tick), so keep the
                // sort cheap: compute each trip's key once (O(n) calendar calls)
                // instead of inside every comparison.
                let sorted = period.trips
                    .map { (trip: $0,
                            day:  Calendar.current.startOfDay(for: $0.date),
                            time: $0.earliestEnteredTime ?? $0.date) }   // anchored to trip date
                    .sorted { a, b in
                        if a.day != b.day { return a.day > b.day }
                        return a.time > b.time   // within the same day, latest start on top
                    }
                    .map(\.trip)
                ForEach(sorted) { trip in
                    TripCard(
                        trip:             trip,
                        isLive:           trip.isLive(at: now),
                        isNextUp:         trip.id == nextUp,
                        countdownEnabled: countdownEnabled,
                        now:              now,
                        onEdit:           { editingTrip = trip },
                        onDelete:         { tripToDelete = trip; showDeleteAlert = true },
                        onToggleActive:   {
                            let prevState = trip   // capture pre-toggle version for undo
                            var updated   = trip
                            updated.isActive.toggle()
                            store.updateTrip(updated, inPeriod: periodID)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Show undo toast; prevState carries the original isActive value.
                            let token = UUID()
                            toggleToastToken = token
                            withAnimation {
                                deletedTrip  = nil   // one toast slot — don't stack
                                undoableTrip = prevState
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    if toggleToastToken == token { undoableTrip = nil }
                                }
                            }
                        }
                    )
                    .padding(.horizontal, AppTheme.screenPad)
                    .padding(.bottom, AppTheme.elemSpacing)
                }
            }
        }
    }

    // MARK: - Export
    private func exportPDF() {
        guard let period = period else { return }
        let safe = period.label.replacingOccurrences(of: " ", with: "_")
        shareFile(data: period.pdfData(driverName: store.driverName,
                                       companyName: store.companyName),
                  filename: "RunSheet_\(safe).pdf")
    }

    private func exportCSV() {
        guard let period = period else { return }
        let safe = period.label.replacingOccurrences(of: " ", with: "_")
        let data = Data(period.csvString.utf8)
        shareFile(data: data, filename: "RunSheet_\(safe).csv")
    }
}

// MARK: - Summary Metric
private struct SummaryMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.6)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip:             Trip
    var isLive:           Bool      = false   // currently in-progress window
    var isNextUp:         Bool      = false
    var countdownEnabled: Bool      = false
    var now:              Date      = Date()
    let onEdit:           () -> Void
    let onDelete:         () -> Void
    let onToggleActive:   () -> Void

    /// Gold highlight (border + star) shows whenever the user enables the
    /// per-trip Highlight toggle in the edit form. This gold border is the
    /// only card emphasis — there is no green border.
    private var isHighlightedNow: Bool { trip.isHighlighted }

    /// Countdown string to the trip's earliest entered time. Shown whenever the
    /// user enables the per-trip Countdown toggle and the trip has a future
    /// time. Past trips show nothing.
    private var countdownText: String? {
        guard countdownEnabled, trip.showCountdown,
              let target = trip.nextUpcomingTime(after: now) else { return nil }
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else { return nil }       // past trips: no "Departed" noise
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    var body: some View {
        AppCard(padding: 10) {
            HStack(alignment: .top, spacing: 10) {
                // Date column
                VStack(spacing: 1) {
                    Text(trip.date.formatted(.dateTime.day()))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(trip.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .frame(width: 46)

                Divider().frame(height: 52).background(AppTheme.oceanLight)

                // Main info
                VStack(alignment: .leading, spacing: 6) {
                    // Service / vehicle row
                    HStack(spacing: 4) {
                        Text(trip.vehicle.icon).font(.system(size: 16))
                        Text(trip.service.icon).font(.system(size: 16))
                        Text(trip.service.rawValue)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        if isHighlightedNow {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.warning)
                                .accessibilityLabel("Highlighted")
                        }
                        if isLive {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.success)
                                .cornerRadius(4)
                        }
                        if !trip.isActive {
                            Text("INACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.textTertiary)
                                .cornerRadius(4)
                        }
                    }
                    // Client — the card's headline
                    Text(trip.clientName)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // Times — one row when they fit, else a 2×2 grid so the
                    // bigger chips never wrap their values.
                    if trip.hasPUTime || trip.hasDOTime || trip.hasLeftBase || trip.hasBackBase {
                        let chips: [(String, String)] = [
                            trip.hasPUTime   ? ("PU", trip.formattedPickup)   : nil,
                            trip.hasDOTime   ? ("DO", trip.formattedDropoff)  : nil,
                            trip.hasLeftBase ? ("LB", trip.formattedLeftBase) : nil,
                            trip.hasBackBase ? ("BB", trip.formattedBackBase) : nil,
                        ].compactMap { $0 }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                ForEach(chips, id: \.0) { TimeChip(label: $0.0, value: $0.1) }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    ForEach(Array(chips.prefix(2)), id: \.0) { TimeChip(label: $0.0, value: $0.1) }
                                }
                                HStack(spacing: 8) {
                                    ForEach(Array(chips.dropFirst(2)), id: \.0) { TimeChip(label: $0.0, value: $0.1) }
                                }
                            }
                        }
                    }
                    // Notes
                    if !trip.notes.isEmpty {
                        Text(trip.notes)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textTertiary)
                            .italic()
                            .lineLimit(3)
                    }
                }

                Spacer()

                // Countdown clock + action buttons (top-right).
                // spacing 0: the 36pt button frames already provide the touch
                // separation — extra spacing spread the column and grew the card.
                VStack(alignment: .trailing, spacing: 0) {
                    // Live countdown to this trip's first time
                    if let cd = countdownText {
                        HStack(spacing: 3) {
                            Image(systemName: "timer").font(.system(size: 11))
                            Text(cd)
                                .font(.system(size: 14, weight: .bold))
                                .monospacedDigit()
                        }
                        .foregroundColor(AppTheme.coral)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.coral.opacity(0.15))
                        .cornerRadius(6)
                    }

                    // Active/Inactive toggle
                    // 36pt frames + contentShape give near-44pt tap targets so
                    // toggle/edit/delete can't be fat-fingered from a moving seat.
                    Button(action: onToggleActive) {
                        Image(systemName: trip.isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(trip.isActive ? AppTheme.success : AppTheme.textTertiary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(trip.isActive ? "Deactivate trip" : "Activate trip")

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.coral)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Edit trip for \(trip.clientName)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.error)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Delete trip for \(trip.clientName)")
                }
            }
        }
        .opacity(trip.isActive ? 1.0 : 0.4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.warning, lineWidth: isHighlightedNow ? 1.5 : 0)
        )
        .shadow(color: isHighlightedNow ? AppTheme.warning.opacity(0.35) : .clear, radius: 8, x: 0, y: 0)
        .animation(.easeInOut(duration: 0.4), value: isLive)
        .animation(.easeInOut(duration: 0.4), value: isNextUp)
        .animation(.easeInOut(duration: 0.3), value: trip.isActive)
        .animation(.easeInOut(duration: 0.3), value: trip.isHighlighted)
    }
}

// MARK: - Time Chip
private struct TimeChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textTertiary)
                .tracking(0.5)
                .lineLimit(1)
                .fixedSize()
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(AppTheme.oceanLight.opacity(0.5))
        .cornerRadius(6)
    }
}
