//
//  GarageViewModel.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/5/23.
//

import Foundation
import Combine
import Observation

@Observable
class GarageViewModel {
    var garage: Garage

    var currentVehicle: Vehicle? {
        if let vin = garage.currentVehicleVin {
             return garage.garageVehicles.first(where: { $0.vin == vin })
        }
        return nil
    }

    var garageVehicles: [Vehicle] {
        garage.garageVehicles
    }

    init(garage: Garage) {
        self.garage = garage
    }

    func deleteVehicle(_ vehicle: Vehicle) {
        garage.deleteVehicle(vehicle)
    }
}
