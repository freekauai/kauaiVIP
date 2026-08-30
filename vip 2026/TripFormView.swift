// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Add / Edit Trip Form             ║
// ║           TripFormView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct TripFormView: View {
    let periodID:     UUID
    let existingTrip: Trip?

    @EnvironmentObject var store:         TimesheetStore

    /// Keep the trip date inside its pay period so a trip can't silently
    /// land outside the period it belongs to.
    private var dateRange: ClosedRange<Date> {
        guard let period = store.periods.first(where: { $0.id == periodID }) else {
            return Date.distantPast...Date.distantFuture
        }
        return min(period.startDate, period.endDate)...max(period.startDate, period.endDate)
    }
    @Environment(\.dismiss) var dismiss

    // Form state
    @State private var date:         Date        = Date()
    @State private var vehicle:      Vehicle     = .suv
    @State private var service:      ServiceType = .airport
    @State private var clientName:   String      = ""
    @State private var notes:        String      = ""

    // Time toggles
    @State private var hasPUTime:    Bool = false
    @State private var pickupTime:   Date = Date()
    @State private var hasDOTime:    Bool = false
    @State private var dropoffTime:  Date = Date()
    @State private var hasLeftBase:  Bool = false
    @State private var timeLeftBase: Date = Date()
    @State private var hasBackBase:  Bool = false
    @State private var timeBackBase: Date = Date()

    // Display options
    @State private var isHighlighted: Bool = false
    @State private var showCountdown: Bool = false

    @State private var showValidationAlert = false
    @State private var validationMsg       = ""

    private var isEditing: Bool { existingTrip != nil }
    private var navTitle:  String { isEditing ? "Edit Trip" : "Add Trip" }

    // Pick lists from the store, guaranteeing the trip's current value is shown
    // even if it was a custom entry that has since been deleted in Settings.
    private var vehicleOptions: [Vehicle] {
        store.allVehicles.contains(vehicle) ? store.allVehicles : store.allVehicles + [vehicle]
    }
    private var serviceOptions: [ServiceType] {
        store.allServices.contains(service) ? store.allServices : store.allServices + [service]
    }

    // MARK: - Picker helpers (extracted to avoid type-checker timeout)
    private var vehiclePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vehicle").font(.system(size: 12)).foregroundColor(AppTheme.textTertiary)
            Picker("Vehicle", selection: $vehicle) {
                ForEach(vehicleOptions) { v in
                    Text("\(v.icon) \(v.rawValue)").tag(v)
                }
            }
            .pickerStyle(.menu)
            .foregroundColor(AppTheme.coral)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.oceanLight.opacity(0.4))
            .cornerRadius(AppTheme.fieldRadius)
        }
    }

    private var servicePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Service").font(.system(size: 12)).foregroundColor(AppTheme.textTertiary)
            Picker("Service", selection: $service) {
                ForEach(serviceOptions) { s in
                    Text("\(s.icon) \(s.rawValue)").tag(s)
                }
            }
            .pickerStyle(.menu)
            .foregroundColor(AppTheme.coral)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.oceanLight.opacity(0.4))
            .cornerRadius(AppTheme.fieldRadius)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // No TrafficBanner here — a data-entry sheet doesn't
                        // need live traffic, and it pushed Times/Notes two
                        // screens down.
                        VStack(spacing: AppTheme.cardSpacing) {
                            // ── Date ──────────────────────────────────
                            // Compact pill (expands to a calendar on tap)
                            // instead of the always-open graphical calendar.
                            AppCard {
                                HStack {
                                    Text("TRIP DATE").labelStyle()
                                    Spacer()
                                    DatePicker("Date", selection: $date,
                                               in: dateRange,
                                               displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(AppTheme.coral)
                                }
                            }

                            // ── Vehicle & Service ──────────────────────
                            AppCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("VEHICLE & SERVICE").labelStyle()
                                    HStack(spacing: 12) {
                                        vehiclePicker
                                        servicePicker
                                    }
                                }
                            }

                            // ── Client ─────────────────────────────────
                            AppCard {
                                AppTextField(label: "👤 Client Name", placeholder: "Enter client name…", text: $clientName)
                                    .autocorrectionDisabled()   // proper nouns — don't "fix" them
                            }

                            // ── Times ──────────────────────────────────
                            AppCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("⏰ TIMES").labelStyle()
                                    ToggleTimeRow(label: "PU Time (Pickup)",   isOn: $hasPUTime,   time: $pickupTime)
                                    AppDivider()
                                    ToggleTimeRow(label: "DO Time (Drop-off)", isOn: $hasDOTime,   time: $dropoffTime)
                                    AppDivider()
                                    ToggleTimeRow(label: "Time Left Base",     isOn: $hasLeftBase, time: $timeLeftBase)
                                    AppDivider()
                                    ToggleTimeRow(label: "Time Back Base",     isOn: $hasBackBase, time: $timeBackBase)
                                }
                            }

                            // ── Display Options ────────────────────────
                            AppCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("⭐️ DISPLAY OPTIONS").labelStyle()
                                    Toggle(isOn: $isHighlighted) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Highlight Trip")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Text("Gold border + star to make this trip stand out")
                                                .font(.system(size: 12))
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                    }
                                    .tint(AppTheme.coral)
                                    AppDivider()
                                    Toggle(isOn: $showCountdown) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Countdown Timer")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Text("Live countdown (HST) to this trip's next time")
                                                .font(.system(size: 12))
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                    }
                                    .tint(AppTheme.coral)
                                }
                            }

                            // ── Notes ──────────────────────────────────
                            AppCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("📝 NOTES").labelStyle()
                                    TextEditor(text: $notes)
                                        .frame(minHeight: 80)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .background(AppTheme.oceanLight.opacity(0.3))
                                        .cornerRadius(AppTheme.fieldRadius)
                                        // Ghost hint — the empty box didn't read
                                        // as typeable next to the place button.
                                        .overlay(alignment: .topLeading) {
                                            if notes.isEmpty {
                                                Text("Type anything — pax, phone, details — or build a route below…")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(AppTheme.textTertiary.opacity(0.6))
                                                    .padding(.top, 8)
                                                    .padding(.leading, 5)
                                                    .allowsHitTesting(false)
                                            }
                                        }

                                    // ── Route builder ──────────────────
                                    // Each pick appends to the notes: the
                                    // first inserts the place, every next
                                    // one adds " to <place>" — so tapping
                                    // builds "Hyatt to LIH to Poipu".
                                    Menu {
                                        ForEach(store.allPlaces) { p in
                                            Button("\(p.icon) \(p.name)") { appendPlace(p) }
                                        }
                                    } label: {
                                        Label(notesIsEmpty ? "Add place" : "to — add next place",
                                              systemImage: "mappin.and.ellipse")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(AppTheme.coral)

                                    // Live preview of the places this trip
                                    // will be tagged with (card + Stats).
                                    let matched = Place.matches(in: notes, from: store.allPlaces)
                                    if !matched.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(matched) { place in
                                                Text("\(place.icon) \(place.name)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(AppTheme.info)
                                                    .lineLimit(1)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(AppTheme.info.opacity(0.12))
                                                    .cornerRadius(5)
                                            }
                                        }
                                    }
                                }
                            }

                            // Save button
                            CoralButton(isEditing ? "💾 Save Changes" : "✅ Add Trip", action: saveTrip)
                                .padding(.bottom, 32)
                        }
                        .padding(AppTheme.screenPad)
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            // Scroll dismisses the keyboard; .immediately (not .interactively)
            // so the keyboard toolbar's "Done" pill can't linger on screen
            // half-detached after an interactive drag.
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveTrip() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMsg)
            }
            .onAppear {
                populateIfEditing()
                // New trip in a past/future period: Date() sits outside the
                // pay period — clamp so the picker and the saved trip agree.
                // ONLY for new trips: an existing trip dated outside the period
                // (e.g. paste-imported) must keep its real date when edited.
                if !isEditing, !dateRange.contains(date) {
                    date = min(max(date, dateRange.lowerBound), dateRange.upperBound)
                }
            }
        }
    }

    // MARK: - Route builder
    private var notesIsEmpty: Bool {
        notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// First pick inserts the place name; every later pick appends
    /// " to <place>", building a route like "Grand Hyatt to Lihue Airport".
    private func appendPlace(_ place: Place) {
        if notesIsEmpty {
            notes = place.name
        } else {
            notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                + " to " + place.name
        }
    }

    // MARK: - Populate for edit
    private func populateIfEditing() {
        guard let t = existingTrip else { return }
        date         = t.date
        vehicle      = t.vehicle
        service      = t.service
        clientName   = t.clientName
        notes        = t.notes
        hasPUTime    = t.hasPUTime;    if let v = t.pickupTime   { pickupTime   = v }
        hasDOTime    = t.hasDOTime;    if let v = t.dropoffTime  { dropoffTime  = v }
        hasLeftBase  = t.hasLeftBase;  if let v = t.timeLeftBase { timeLeftBase = v }
        hasBackBase  = t.hasBackBase;  if let v = t.timeBackBase { timeBackBase = v }
        isHighlighted = t.isHighlighted
        showCountdown = t.showCountdown
    }

    // MARK: - Save
    private func saveTrip() {
        // Validate
        guard !clientName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMsg = "Please enter a client name."; showValidationAlert = true; return
        }
        var trip = existingTrip ?? Trip()
        trip.date         = date
        trip.vehicle      = vehicle
        trip.service      = service
        trip.clientName   = clientName.trimmingCharacters(in: .whitespaces)
        trip.notes        = notes
        trip.hasPUTime    = hasPUTime;   trip.pickupTime   = hasPUTime   ? pickupTime   : nil
        trip.hasDOTime    = hasDOTime;   trip.dropoffTime  = hasDOTime   ? dropoffTime  : nil
        trip.hasLeftBase  = hasLeftBase; trip.timeLeftBase = hasLeftBase  ? timeLeftBase : nil
        trip.hasBackBase  = hasBackBase; trip.timeBackBase = hasBackBase  ? timeBackBase : nil
        trip.isHighlighted = isHighlighted
        trip.showCountdown = showCountdown

        if isEditing {
            store.updateTrip(trip, inPeriod: periodID)
        } else {
            store.addTrip(trip, toPeriod: periodID)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
