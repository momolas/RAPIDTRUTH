//
//  HomeViewModel.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Observation

@Observable
class HomeViewModel {
    var obdInfo = OBDInfo()

    var vinInput = ""
    var vinInfo: VINInfo?
    var selectedProtocol: OBDProtocol = .NONE
    var garage: Garage

    var garageVehicles: [Vehicle] {
        garage.garageVehicles
    }

    var currentVehicle: Vehicle? {
        if let vin = garage.currentVehicleVin {
             return garage.garageVehicles.first(where: { $0.vin == vin })
        }
        return nil
    }

    let obdService: OBDService

    init(obdService: OBDService, garage: Garage) {
        self.obdService = obdService
        self.garage = garage
    }
}
