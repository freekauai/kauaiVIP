// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Settings Screen                  ║
// ║           SettingsView.swift                                 ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Accessible via the ⚙️ gear icon in the TIMESHEET PERIODS header
// on the main screen. Theme choice is persisted via @AppStorage
// and applied at the WindowGroup level in KauaiVIP2026App.swift.

import SwiftUI
import UniformTypeIdentifiers   // UTType.text for place drag-reorder

struct SettingsView: View {
    @EnvironmentObject var store: TimesheetStore
    @Environment(\.dismiss) var dismiss

    // Shared with KauaiVIP2026App.swift and PeriodDetailView.swift
    @AppStorage("appTheme")          private var appTheme:          String = "blueLight"
    @AppStorage("countdownEnabled")  private var countdownEnabled:  Bool   = true
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool   = false

    @State private var driverNameInput:       String = ""
    @State private var companyInput:          String = ""
    @State private var newVehicleInput:       String = ""
    @State private var newServiceInput:       String = ""
    @State private var newPlaceInput:         String = ""

    // Place editing / reordering
    @State private var draggingPlace:   Place? = nil
    @State private var placeToRename:   Place? = nil
    @State private var showRenamePlace: Bool   = false
    @State private var renamePlaceInput: String = ""
    @State private var showClearConfirmation: Bool   = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    private var nameIsEmpty: Bool {
        driverNameInput.trimmingCharacters(in: .whitespaces).isEmpty
    }
    /// True when both fields already match what's stored (nothing to save).
    private var infoUnchanged: Bool {
        driverNameInput.trimmingCharacters(in: .whitespaces) == store.driverName &&
        companyInput.trimmingCharacters(in: .whitespaces)    == store.companyName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.cardSpacing) {
                        driverNameSection
                        vehiclesSection
                        servicesSection
                        placesSection
                        themeSection
                        countdownSection
                        biometricsSection
                        appInfoSection
                        dangerSection
                    }
                    .padding(AppTheme.screenPad)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.oceanDeep, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.coral)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                driverNameInput = store.driverName
                companyInput    = store.companyName
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Periods & Trips", role: .destructive) {
                    store.clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every pay period and trip. This action cannot be undone.")
            }
        }
    }

    // MARK: - Driver Name

    private var driverNameSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("DRIVER & COMPANY").labelStyle()

                TextField("Driver name", text: $driverNameInput)
                    .foregroundColor(AppTheme.textPrimary)
                    .font(.system(size: AppTheme.body))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.oceanLight.opacity(0.4))
                    .cornerRadius(AppTheme.fieldRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                            .stroke(AppTheme.oceanLight, lineWidth: 1)
                    )

                TextField("Company (optional)", text: $companyInput)
                    .foregroundColor(AppTheme.textPrimary)
                    .font(.system(size: AppTheme.body))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.oceanLight.opacity(0.4))
                    .cornerRadius(AppTheme.fieldRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                            .stroke(AppTheme.oceanLight, lineWidth: 1)
                    )
                    .onSubmit { saveName() }

                Text("If no company is set, your name is used on the app and PDF exports.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                CoralButton(
                    "Save",
                    disabled: nameIsEmpty || infoUnchanged,
                    action: saveName
                )
            }
        }
    }

    private func saveName() {
        let trimmed = driverNameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.saveDriverName(trimmed)
        store.saveCompanyName(companyInput)
    }

    // MARK: - Vehicles

    private var vehiclesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLES").labelStyle()
                Text("Pick lists for the Add Trip form. The three built-in vehicles can't be removed.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                VStack(spacing: 8) {
                    ForEach(store.allVehicles) { v in
                        itemRow(icon: v.icon, name: v.name,
                                isBuiltIn: Vehicle.builtIns.contains(v)) {
                            store.removeCustomVehicle(v)
                        }
                    }
                }

                addRow(placeholder: "Add a vehicle…", text: $newVehicleInput) {
                    store.addCustomVehicle(newVehicleInput)
                    newVehicleInput = ""
                }
            }
        }
    }

    // MARK: - Services

    private var servicesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SERVICES").labelStyle()
                Text("Add your own service types. “Charter” drives the charter-hours totals.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                VStack(spacing: 8) {
                    ForEach(store.allServices) { s in
                        itemRow(icon: s.icon, name: s.name,
                                isBuiltIn: ServiceType.builtIns.contains(s)) {
                            store.removeCustomService(s)
                        }
                    }
                }

                addRow(placeholder: "Add a service…", text: $newServiceInput) {
                    store.addCustomService(newServiceInput)
                    newServiceInput = ""
                }
            }
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("PLACES").labelStyle()
                Text("Matched in trip notes — “Hyatt to LIH” tags Hotel and Airport on the card and in Stats. Add your own spots, drag to reorder the Add-Place menu, tap ✏️ to rename.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                VStack(spacing: 8) {
                    ForEach(store.allPlaces) { p in
                        placeRow(p)
                            .onDrag {
                                draggingPlace = p
                                return NSItemProvider(object: p.name as NSString)
                            }
                            .onDrop(of: [.text],
                                    delegate: PlaceDropDelegate(item: p,
                                                                dragging: $draggingPlace,
                                                                store: store))
                    }
                }

                addRow(placeholder: "Add a place…", text: $newPlaceInput) {
                    store.addCustomPlace(newPlaceInput)
                    newPlaceInput = ""
                }
            }
        }
        .alert("Rename Place", isPresented: $showRenamePlace, presenting: placeToRename) { place in
            TextField("Place name", text: $renamePlaceInput)
                .autocorrectionDisabled()
            Button("Save") { store.renameCustomPlace(place, to: renamePlaceInput) }
            Button("Cancel", role: .cancel) {}
        } message: { place in
            Text("Rename “\(place.name)”. Existing trip notes keep their text — matching just follows the new name.")
        }
    }

    /// A place row: drag handle + icon + name, then rename/delete for customs
    /// or a "Built-in" tag. Every row (built-ins included) is draggable.
    private func placeRow(_ p: Place) -> some View {
        let isBuiltIn = Place.builtIns.contains(p)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textTertiary)
            Text(p.icon)
                .font(.system(size: 18))
                .frame(width: 26)
            Text(p.name)
                .font(.system(size: AppTheme.subhead, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if isBuiltIn {
                Text("Built-in")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            } else {
                Button {
                    placeToRename    = p
                    renamePlaceInput = p.name
                    showRenamePlace  = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.coral)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rename \(p.name)")
                Button { store.removeCustomPlace(p) } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.error)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(p.name)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.oceanLight.opacity(draggingPlace == p ? 0.5 : 0.25))
        .cornerRadius(AppTheme.fieldRadius)
    }

    // MARK: - Place drag-reorder delegate
    /// Live-reorders the list as the dragged row passes over others
    /// (classic DropDelegate pattern for reordering inside a VStack).
    private struct PlaceDropDelegate: DropDelegate {
        let item: Place
        @Binding var dragging: Place?
        let store: TimesheetStore

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func dropEntered(info: DropInfo) {
            // SwiftUI calls DropDelegate on the main thread.
            MainActor.assumeIsolated {
                guard let dragging = dragging, dragging != item,
                      let from = store.allPlaces.firstIndex(of: dragging),
                      let to   = store.allPlaces.firstIndex(of: item) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.movePlace(from: from, to: to)
                }
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            dragging = nil
            return true
        }
    }

    // MARK: - Shared list editor pieces

    /// One row in the vehicle/service list: icon + name, with a trash button for
    /// custom items or a "Built-in" tag for the ones that ship with the app.
    private func itemRow(icon: String, name: String,
                         isBuiltIn: Bool, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 26)
            Text(name)
                .font(.system(size: AppTheme.subhead, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if isBuiltIn {
                Text("Built-in")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            } else {
                Button(action: onRemove) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.error)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.oceanLight.opacity(0.25))
        .cornerRadius(AppTheme.fieldRadius)
    }

    /// Text field + add button, styled to match the driver-name form field.
    private func addRow(placeholder: String, text: Binding<String>,
                        onAdd: @escaping () -> Void) -> some View {
        let isEmpty = text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: 10) {
            TextField(placeholder, text: text)
                .foregroundColor(AppTheme.textPrimary)
                .font(.system(size: AppTheme.body))
                .autocorrectionDisabled()   // proper nouns ("Poipu" → "Poppy")
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.oceanLight.opacity(0.4))
                .cornerRadius(AppTheme.fieldRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.fieldRadius)
                        .stroke(AppTheme.oceanLight, lineWidth: 1)
                )
                .submitLabel(.done)
                .onSubmit { if !isEmpty { onAdd() } }

            Button(action: { if !isEmpty { onAdd() } }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(isEmpty ? AppTheme.textTertiary : AppTheme.coral)
            }
            .buttonStyle(.plain)
            .disabled(isEmpty)
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("APPEARANCE").labelStyle()
                Text("Changes take effect immediately across the whole app.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                Picker("Theme", selection: $appTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Blue Light").tag("blueLight")
                    Text("Blue Dark").tag("blueDark")
                }
                .pickerStyle(.menu)
                .tint(AppTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Countdown Toggle

    private var countdownSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("TRIP COUNTDOWN").labelStyle()

                Toggle(isOn: $countdownEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Show Countdowns")
                            .font(.system(size: AppTheme.subhead, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Display time-to-departure on the next upcoming trip card.")
                            .font(.system(size: AppTheme.footnote))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .tint(AppTheme.coral)
            }
        }
    }

    // MARK: - Biometrics

    private var biometricsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SECURITY").labelStyle()

                Toggle(isOn: $requireBiometrics) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "faceid")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.system(size: 15, weight: .medium))
                            Text("Require Face ID")
                                .font(.system(size: AppTheme.subhead, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        Text("Lock the app when it moves to the background.")
                            .font(.system(size: AppTheme.footnote))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                .tint(AppTheme.coral)
            }
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("APP INFO").labelStyle()

                HStack {
                    Text("Version")
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(AppTheme.textPrimary)
                        .fontWeight(.semibold)
                }
                .font(.system(size: AppTheme.subhead))

                Divider().background(AppTheme.oceanLight)

                if let mailURL = AppConstants.mailtoURL {
                    Link(destination: mailURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.coral)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contact Support")
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(AppConstants.supportEmail)
                                    .foregroundColor(AppTheme.coral)
                                    .font(.system(size: AppTheme.footnote))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .font(.system(size: AppTheme.subhead))
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("DANGER ZONE").labelStyle()
                Text("These actions are permanent and cannot be undone.")
                    .font(.system(size: AppTheme.footnote))
                    .foregroundColor(AppTheme.textTertiary)

                Button(action: { showClearConfirmation = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("Clear All Data")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppTheme.error)
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.error.opacity(0.4), lineWidth: 1.5)
        )
    }
}
