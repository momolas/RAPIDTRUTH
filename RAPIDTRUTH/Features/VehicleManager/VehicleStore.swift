import Foundation
import Observation
import SwiftData

/// Persists `Vehicle` records using SwiftData. Holds an in-memory cache for the UI.
@MainActor
@Observable
final class VehicleStore {

    private(set) var vehicles: [Vehicle] = []
    private(set) var loadError: String?

    static let shared = VehicleStore()

    let container: ModelContainer
    let context: ModelContext

    private init() {
        do {
            let schema = Schema([
                Vehicle.self,
                DTCScanRecord.self,
                AuditRecord.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: config)
            self.context = ModelContext(container)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    /// Load every vehicle for `owner`. Replaces the in-memory cache.
    func reload(owner: String) {
        loadError = nil
        do {
            let descriptor = FetchDescriptor<Vehicle>(
                predicate: #Predicate<Vehicle> { $0.owner == owner }
            )
            var loaded = try context.fetch(descriptor)
            
            // Sort by lastUsedUTC or createdAtUTC descending
            loaded.sort { (a, b) in
                let aKey = a.lastUsedUTC ?? a.createdAtUTC
                let bKey = b.lastUsedUTC ?? b.createdAtUTC
                return aKey > bKey
            }
            vehicles = loaded
        } catch {
            loadError = "Could not fetch vehicles: \(error.localizedDescription)"
        }
    }

    func save(_ vehicle: Vehicle) throws {
        if vehicle.modelContext == nil {
            context.insert(vehicle)
        }
        try context.save()
        reload(owner: vehicle.owner)
    }

    /// Wipe the cached supported-PID lists on a vehicle so the next logging
    /// session re-runs standard discovery + profile probe. Use when the
    /// existing cache is suspected stale (e.g. populated by an earlier
    /// version with buggy ECU addressing).
    func clearPIDCaches(slug: String, owner: String) throws {
        guard let vehicle = vehicles.first(where: { $0.slug == slug && $0.owner == owner }) else {
            return
        }
        vehicle.supportedStandardPIDs = []
        vehicle.supportedProfilePIDs = []
        try save(vehicle)
    }

    func delete(slug: String, owner: String) throws {
        let descriptor = FetchDescriptor<Vehicle>(
            predicate: #Predicate<Vehicle> { $0.slug == slug && $0.owner == owner }
        )
        if let vehicle = try context.fetch(descriptor).first {
            context.delete(vehicle)
            try context.save()
        }
        // Also remove the filesystem directory where CSV files are saved
        try? AppStorage.shared.remove(AppPath.vehicleDir(owner, slug))
        reload(owner: owner)
    }
    
    func saveDTCScan(vehicleSlug: String, codes: [String], ecus: [String]) throws {
        let scan = DTCScanRecord(vehicleSlug: vehicleSlug, codes: codes, ecus: ecus)
        context.insert(scan)
        try context.save()
    }
    
    func fetchDTCScans(for vehicleSlug: String) -> [DTCScanRecord] {
        let descriptor = FetchDescriptor<DTCScanRecord>(
            predicate: #Predicate<DTCScanRecord> { $0.vehicleSlug == vehicleSlug }
        )
        let loaded = (try? context.fetch(descriptor)) ?? []
        return loaded.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    func saveAuditRecord(_ record: AuditRecord) throws {
        context.insert(record)
        try context.save()
    }
    
    func fetchAuditRecords(for vehicleSlug: String) -> [AuditRecord] {
        let descriptor = FetchDescriptor<AuditRecord>(
            predicate: #Predicate<AuditRecord> { $0.vehicleSlug == vehicleSlug }
        )
        let loaded = (try? context.fetch(descriptor)) ?? []
        return loaded.sorted(by: { $0.timestamp > $1.timestamp })
    }
}
