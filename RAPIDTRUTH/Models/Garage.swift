//
//  Garage.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Observation
import SwiftData
import OSLog

// Typealias for easier migration
typealias Vehicle = VehicleModel

@Observable
@MainActor
class Garage {
    let logger = Logger(subsystem: "com.momolas.RAPIDTRUTH", category: "Garage")
    var garageVehicles: [Vehicle] = []
    private var modelContext: ModelContext

    // We persist the selected VIN string instead of an Int ID, as SwiftData persistentModelID is complex
    var currentVehicleVin: String? {
        didSet {
            if let vin = currentVehicleVin {
                UserDefaults.standard.set(vin, forKey: "currentCarVin")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentCarVin")
            }
        }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchAllVehicles()

        let storedVin = UserDefaults.standard.string(forKey: "currentCarVin")
        if let storedVin, garageVehicles.contains(where: { $0.vin == storedVin }) {
            self.currentVehicleVin = storedVin
        } else {
            self.currentVehicleVin = nil
        }
    }

    @MainActor
    convenience init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: VehicleModel.self, configurations: config)
            self.init(modelContext: container.mainContext)
        } catch {
            fatalError("Failed to create in-memory container for preview: \(error)")
        }
    }

    func fetchAllVehicles() {
        do {
            let descriptor = FetchDescriptor<Vehicle>(sortBy: [SortDescriptor(\.make)])
            self.garageVehicles = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch vehicles: \(error)")
        }
    }

    func addVehicle(make: String, model: String, year: String, vin: String = "", obdinfo: OBDInfo? = nil) {
        // VIN serves as ID for selection persistence
        let finalVin = vin.isEmpty ? UUID().uuidString : vin

        if !vin.isEmpty, garageVehicles.contains(where: { $0.vin == vin }) {
            logger.warning("Vehicle with VIN \(vin) already exists.")
            return
        }

        let vehicle = Vehicle(vin: finalVin, make: make, model: model, year: year, obdinfo: obdinfo)
        modelContext.insert(vehicle)
        do {
            try modelContext.save()
            logger.info("Added vehicle \(vehicle.make) \(vehicle.model)")
        } catch {
            logger.error("Failed to save vehicle: \(error)")
        }

        fetchAllVehicles()
        currentVehicleVin = finalVin
    }

    // set current vehicle by VIN (was id)
    func setCurrentVehicle(by vin: String) {
        currentVehicleVin = vin
    }

    func deleteVehicle(_ car: Vehicle) {
        let deletedVin = car.vin
        modelContext.delete(car)
        try? modelContext.save()
        fetchAllVehicles()

        if deletedVin == currentVehicleVin {
            currentVehicleVin = garageVehicles.first?.vin
        }
    }

    func getVehicle(vin: String) -> Vehicle? {
        return garageVehicles.first(where: { $0.vin == vin })
    }

    var currentVehicle: Vehicle? {
        guard let vin = currentVehicleVin else { return nil }
        return getVehicle(vin: vin)
    }
}
