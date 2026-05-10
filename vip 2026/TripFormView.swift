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

    @State private var showValidationAlert = false
    @State private var validationMsg       = ""

    private var isEditing: Bool { existingTrip != nil }
    private var navTitle:  String { isEditing ? "Edit Trip" : "Add Trip" }

    // MARK: - Picker helpers (extracted to avoid type-checker timeout)
    private var vehiclePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vehicle").font(.system(size: 12)).foregroundColor(AppTheme.textTertiary)
            Picker("Vehicle", selection: $vehicle) {
                ForEach(Vehicle.allCases) { v in
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
                ForEach(ServiceType.allCases) { s in
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
                                        .colorScheme(.dark)
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
                                        .colorScheme(.dark)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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

        if isEditing {
            store.updateTrip(trip, inPeriod: periodID)
        } else {
            store.addTrip(trip, toPeriod: periodID)
        }
        dismiss()
    }
}
