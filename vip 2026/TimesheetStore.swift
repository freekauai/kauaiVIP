// ╔══════════════════════════════════════════════════════════════╗
// ║           KAUAI VIP 2026 — Data Store (Persistence)         ║
// ║           TimesheetStore.swift                               ║
// ╚══════════════════════════════════════════════════════════════╝

import Foundation
import Combine

class TimesheetStore: ObservableObject {
    @Published var periods:    [PayPeriod] = []
    @Published var driverName: String      = ""

    // Legacy UserDefaults keys — used only for one-time migration
    private let legacyPeriodsKey    = "kauai_vip_2026_periods"
    private let driverNameKey       = "kauai_vip_2026_driver_name"

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

    // MARK: - Driver Name
    func saveDriverName(_ name: String) {
        driverName = name
        UserDefaults.standard.set(name, forKey: driverNameKey)
    }

    // MARK: - Period CRUD
    func addPeriod(_ period: PayPeriod) {
        periods.insert(period, at: 0)
        save()
    }

    func deletePeriod(_ period: PayPeriod) {
        periods.removeAll { $0.id == period.id }
        save()
    }

    func updatePeriod(_ period: PayPeriod) {
        guard let idx = periods.firstIndex(where: { $0.id == period.id }) else { return }
        periods[idx] = period
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

    // MARK: - Persistence
    private func save() {
        guard let data = try? JSONEncoder().encode(periods) else { return }
        try? data.write(to: periodsFileURL, options: .atomic)
    }

    private func load() {
        // 1. Try Documents file (primary storage)
        if let data    = try? Data(contentsOf: periodsFileURL),
           let decoded = try? JSONDecoder().decode([PayPeriod].self, from: data) {
            periods = decoded
        }
        // 2. Fall back to UserDefaults and migrate to Documents (runs once on upgrade)
        else if let data    = UserDefaults.standard.data(forKey: legacyPeriodsKey),
                let decoded = try? JSONDecoder().decode([PayPeriod].self, from: data) {
            periods = decoded
            save()  // write to Documents so future reads use the new location
            UserDefaults.standard.removeObject(forKey: legacyPeriodsKey)
        }

        driverName = UserDefaults.standard.string(forKey: driverNameKey) ?? ""
    }

}
