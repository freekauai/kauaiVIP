// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Data Store (Persistence)         ║
// ║           TimesheetStore.swift                               ║
// ╚══════════════════════════════════════════════════════════════╝

import Foundation
import Combine

@MainActor
class TimesheetStore: ObservableObject {
    @Published var periods:       [PayPeriod] = []
    @Published var driverName:    String      = ""
    @Published var companyName:   String      = ""
    @Published var lastSaveError: String?     = nil

    /// User-added vehicles / services / places, appended after the built-ins.
    @Published var customVehicles: [Vehicle]     = []
    @Published var customServices: [ServiceType] = []
    @Published var customPlaces:   [Place]       = []

    /// Driver-chosen display order for ALL places (names). Drives the
    /// Add-Place menu, trip-card tag order, and the Settings list. Kept in
    /// sync by `syncPlaceOrder()` — new places append, deleted ones drop out.
    @Published private var placeOrder: [String] = []

    /// Full pick lists used by the trip form and breakdowns:
    /// built-ins first, then the driver's custom additions.
    var allVehicles: [Vehicle]     { Vehicle.builtIns + customVehicles }
    var allServices: [ServiceType] { ServiceType.builtIns + customServices }

    /// Every place, in the driver's chosen order (built-ins are reorderable
    /// too — only deletion is restricted to customs).
    var allPlaces: [Place] {
        let base = Place.builtIns + customPlaces
        guard !placeOrder.isEmpty else { return base }
        var byName = Dictionary(uniqueKeysWithValues: base.map { ($0.name, $0) })
        var ordered: [Place] = []
        for name in placeOrder {
            if let p = byName.removeValue(forKey: name) { ordered.append(p) }
        }
        ordered.append(contentsOf: base.filter { byName[$0.name] != nil })
        return ordered
    }

    /// Label shown on screen and in PDF exports: the company name when set,
    /// otherwise the driver's name.
    var displayName: String {
        companyName.isEmpty ? driverName : companyName
    }

    // Legacy UserDefaults keys — used only for one-time migration
    private let legacyPeriodsKey    = "kauai_vip_2026_periods"
    private let driverNameKey       = "kauai_vip_2026_driver_name"
    private let companyNameKey      = "kauai_vip_2026_company_name"
    private let customVehiclesKey   = "kauai_vip_2026_custom_vehicles"
    private let customServicesKey   = "kauai_vip_2026_custom_services"
    private let customPlacesKey     = "kauai_vip_2026_custom_places"
    private let placeOrderKey       = "kauai_vip_2026_place_order"

    // Documents-directory file URL — survives reinstall via iCloud/iTunes backup
    private var periodsFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("kauai_vip_periods.json")
    }

    // MARK: - Init
    init() {
        load()
    }

    // MARK: - Driver Name / Company
    func saveDriverName(_ name: String) {
        driverName = name
        UserDefaults.standard.set(name, forKey: driverNameKey)
    }

    func saveCompanyName(_ name: String) {
        companyName = name.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(companyName, forKey: companyNameKey)
    }

    // MARK: - Custom Vehicles / Services
    /// Adds a custom vehicle. No-ops on blank input or a case-insensitive
    /// duplicate of any built-in or existing custom vehicle.
    func addCustomVehicle(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !allVehicles.contains(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        customVehicles.append(Vehicle(rawValue: name))
        UserDefaults.standard.set(customVehicles.map(\.rawValue), forKey: customVehiclesKey)
    }

    /// Removes a custom vehicle. Built-ins are never in `customVehicles`, so they
    /// are inherently safe. Existing trips keep their stored vehicle either way.
    func removeCustomVehicle(_ vehicle: Vehicle) {
        customVehicles.removeAll { $0 == vehicle }
        UserDefaults.standard.set(customVehicles.map(\.rawValue), forKey: customVehiclesKey)
    }

    func addCustomService(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !allServices.contains(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        customServices.append(ServiceType(rawValue: name))
        UserDefaults.standard.set(customServices.map(\.rawValue), forKey: customServicesKey)
    }

    func removeCustomService(_ service: ServiceType) {
        customServices.removeAll { $0 == service }
        UserDefaults.standard.set(customServices.map(\.rawValue), forKey: customServicesKey)
    }

    /// Adds a custom place. No-ops on blank input or a case-insensitive
    /// collision with any built-in place's name OR alias (adding "Hyatt"
    /// would double-tag every Grand Hyatt trip).
    func addCustomPlace(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        let key  = name.lowercased()
        guard !name.isEmpty,
              !allPlaces.contains(where: { $0.aliases.contains(key) || $0.name.lowercased() == key })
        else { return }
        customPlaces.append(Place(name: name))
        UserDefaults.standard.set(customPlaces.map(\.name), forKey: customPlacesKey)
        syncPlaceOrder()
    }

    func removeCustomPlace(_ place: Place) {
        customPlaces.removeAll { $0 == place }
        UserDefaults.standard.set(customPlaces.map(\.name), forKey: customPlacesKey)
        syncPlaceOrder()
    }

    /// Renames a custom place (built-ins keep their names + aliases). Same
    /// collision guard as adding; the saved order entry follows the rename.
    /// Existing trip notes keep their original text — a renamed place simply
    /// matches its new name from now on.
    func renameCustomPlace(_ place: Place, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        let key  = name.lowercased()
        guard !name.isEmpty,
              let idx = customPlaces.firstIndex(of: place),
              !allPlaces.contains(where: { $0 != place && ($0.aliases.contains(key) || $0.name.lowercased() == key) })
        else { return }
        customPlaces[idx] = Place(name: name)
        UserDefaults.standard.set(customPlaces.map(\.name), forKey: customPlacesKey)
        if let oIdx = placeOrder.firstIndex(of: place.name) { placeOrder[oIdx] = name }
        UserDefaults.standard.set(placeOrder, forKey: placeOrderKey)
    }

    /// Moves one place within the driver's display order: remove at `from`,
    /// insert at `to` (both indices into the current `allPlaces`).
    func movePlace(from: Int, to: Int) {
        var order = allPlaces.map(\.name)
        guard order.indices.contains(from), order.indices.contains(to), from != to else { return }
        let name = order.remove(at: from)
        order.insert(name, at: to)
        placeOrder = order
        UserDefaults.standard.set(order, forKey: placeOrderKey)
    }

    /// Reconciles the saved order with the current place set: known names
    /// keep their position, deleted ones drop out, new ones append.
    private func syncPlaceOrder() {
        let names = (Place.builtIns + customPlaces).map(\.name)
        var order = placeOrder.filter { names.contains($0) }
        for n in names where !order.contains(n) { order.append(n) }
        placeOrder = order
        UserDefaults.standard.set(order, forKey: placeOrderKey)
    }

    // MARK: - Sorting (newest startDate first)
    private func sortPeriods() {
        periods.sort { $0.startDate > $1.startDate }
    }

    // MARK: - Period CRUD
    func addPeriod(_ period: PayPeriod) {
        periods.append(period)
        sortPeriods()
        save()
    }

    func deletePeriod(_ period: PayPeriod) {
        periods.removeAll { $0.id == period.id }
        save()
    }

    /// Removes all pay periods and trips — used by the Settings "Clear All Data" action.
    func clearAllData() {
        periods = []
        save()
    }

    func updatePeriod(_ period: PayPeriod) {
        guard let idx = periods.firstIndex(where: { $0.id == period.id }) else { return }
        periods[idx] = period
        sortPeriods()
        save()
    }

    // MARK: - Trip CRUD
    func addTrip(_ trip: Trip, toPeriod periodID: UUID) {
        guard let idx = periods.firstIndex(where: { $0.id == periodID }) else { return }
        periods[idx].trips.append(trip)
        save()
    }

    func updateTrip(_ trip: Trip, inPeriod periodID: UUID) {
        guard let pIdx = periods.firstIndex(where: { $0.id == periodID }),
              let tIdx = periods[pIdx].trips.firstIndex(where: { $0.id == trip.id }) else { return }
        periods[pIdx].trips[tIdx] = trip
        save()
    }

    func deleteTrip(_ trip: Trip, fromPeriod periodID: UUID) {
        guard let pIdx = periods.firstIndex(where: { $0.id == periodID }) else { return }
        periods[pIdx].trips.removeAll { $0.id == trip.id }
        save()
    }

    // MARK: - All-Trips CSV Export
    var allTripsCsvString: String {
        var rows = ["Period,Date,Vehicle,Service,Client,PU Time,DO Time,Left Base,Back Base,Notes"]
        for period in periods {
            for t in period.trips.sorted(by: { $0.date < $1.date }) {
                let row = [
                    csvQuote(period.label),
                    csvQuote(t.formattedDate),
                    csvQuote(t.vehicle.rawValue),   // custom names may contain commas
                    csvQuote(t.service.rawValue),
                    csvQuote(t.clientName),
                    t.formattedPickup,
                    t.formattedDropoff,
                    t.formattedLeftBase,
                    t.formattedBackBase,
                    csvQuote(t.notes)
                ].joined(separator: ",")
                rows.append(row)
            }
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Persistence
    private func save() {
        do {
            let data = try JSONEncoder().encode(periods)
            try data.write(to: periodsFileURL, options: .atomic)
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
            #if DEBUG
            print("⚠️ RunSheet: Failed to save periods: \(error)")
            #endif
        }
    }

    private func load() {
        // 1. Try Documents file (primary storage)
        if let data = try? Data(contentsOf: periodsFileURL) {
            if let decoded = try? JSONDecoder().decode([PayPeriod].self, from: data) {
                periods = decoded
            } else {
                // File exists but won't decode (partial write / future schema).
                // Preserve it before any save() can overwrite the user's history.
                let backup = periodsFileURL.deletingPathExtension()
                    .appendingPathExtension("corrupt.bak.json")
                try? data.write(to: backup, options: .atomic)
                lastSaveError = "Couldn't read saved timesheets — a backup was kept as \(backup.lastPathComponent)."
            }
        }
        // 2. Fall back to UserDefaults and migrate to Documents (runs once on upgrade)
        else if let data    = UserDefaults.standard.data(forKey: legacyPeriodsKey),
                let decoded = try? JSONDecoder().decode([PayPeriod].self, from: data) {
            periods = decoded
            save()  // write to Documents so future reads use the new location
            UserDefaults.standard.removeObject(forKey: legacyPeriodsKey)
        }

        // Always ensure newest period is first regardless of on-disk order
        sortPeriods()

        driverName  = UserDefaults.standard.string(forKey: driverNameKey)  ?? ""
        companyName = UserDefaults.standard.string(forKey: companyNameKey) ?? ""

        customVehicles = Self.sanitize(
            UserDefaults.standard.array(forKey: customVehiclesKey) as? [String] ?? [],
            against: Vehicle.builtIns.map(\.rawValue)
        ).map { Vehicle(rawValue: $0) }
        customServices = Self.sanitize(
            UserDefaults.standard.array(forKey: customServicesKey) as? [String] ?? [],
            against: ServiceType.builtIns.map(\.rawValue)
        ).map { ServiceType(rawValue: $0) }
        customPlaces = Self.sanitize(
            UserDefaults.standard.array(forKey: customPlacesKey) as? [String] ?? [],
            against: Place.builtIns.flatMap { [$0.name] + $0.aliases }
        ).map { Place(name: $0) }
        placeOrder = UserDefaults.standard.array(forKey: placeOrderKey) as? [String] ?? []
        syncPlaceOrder()
    }

    /// Drops blanks, built-in collisions, and case-insensitive duplicates from a
    /// persisted custom list, so the merged `allVehicles`/`allServices` can never
    /// produce duplicate `Identifiable` IDs (which break SwiftUI `ForEach`).
    private static func sanitize(_ names: [String], against builtIns: [String]) -> [String] {
        var seen = Set(builtIns.map { $0.lowercased() })
        var result: [String] = []
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespaces)
            let key  = name.lowercased()
            guard !name.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(name)
        }
        return result
    }

}
