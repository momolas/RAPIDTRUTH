//
//  Garage.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Observation
import SwiftData

// Typealias for easier migration
typealias Vehicle = VehicleModel

@Observable
class Garage {
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
        self.currentVehicleVin = storedVin
    }

    func fetchAllVehicles() {
        do {
            let descriptor = FetchDescriptor<Vehicle>(sortBy: [SortDescriptor(\.make)])
            self.garageVehicles = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch vehicles: \(error)")
        }
    }

    func addVehicle(make: String, model: String, year: String, vin: String = "", obdinfo: OBDInfo? = nil) {
        // VIN serves as ID for selection persistence
        let finalVin = vin.isEmpty ? UUID().uuidString : vin

        let vehicle = Vehicle(vin: finalVin, make: make, model: model, year: year, obdinfo: obdinfo)
        modelContext.insert(vehicle)
        try? modelContext.save()

        fetchAllVehicles()
        currentVehicleVin = finalVin
        print("Added vehicle \(vehicle.make) \(vehicle.model)")
    }

    // set current vehicle by VIN (was id)
    func setCurrentVehicle(by vin: String) {
        currentVehicleVin = vin
    }

    func deleteVehicle(_ car: Vehicle) {
        modelContext.delete(car)
        try? modelContext.save()
        fetchAllVehicles()

        if car.vin == currentVehicleVin {
            currentVehicleVin = garageVehicles.first?.vin
        }
    }

    func getVehicle(vin: String) -> Vehicle? {
        return garageVehicles.first(where: { $0.vin == vin })
    }
}
