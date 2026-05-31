// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Add / Edit Trip Form             ║
// ║           TripFormView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝

import SwiftUI

struct TripFormView: View {
    let periodID:     UUID
    let existingTrip: Trip?

    @EnvironmentObject var store:         TimesheetStore
    @EnvironmentObject var bridgeService: BridgeService
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
                        // Traffic Banner
                        TrafficBanner()

                        VStack(spacing: AppTheme.cardSpacing) {
                            // ── Date ──────────────────────────────────
                            AppCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TRIP DATE").labelStyle()
                                    DatePicker("Date", selection: $date, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .labelsHidden()
                                        .accentColor(AppTheme.coral)
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
                                            Text("Live countdown (HST) to this trip's first time")
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
            .toolbar {
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
            .onAppear { populateIfEditing() }
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
        dismiss()
    }
}
