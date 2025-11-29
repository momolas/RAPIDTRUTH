//
//  SettingsScreenViewModel.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/31/23.
//

import Foundation
import CoreBluetooth
import Observation

//struct Vehicle: Codable {
//    let make: String
//    let model: String
//    let year: Int
//    let obdinfo: OBDInfo
//}

struct OBDInfo: Codable {
    var vin: String?
    var supportedPIDs: [OBDCommand]?
    var obdProtocol: OBDProtocol = .NONE
    var ecuMap: [UInt8: ECUID]?
}

struct Manufacturer: Codable {
    let make: String
    let models: [Model]
}

struct Model: Codable {
    let name: String
    let years: [Int]
}

struct VINResults: Codable {
    let Results: [VINInfo]
}

struct VINInfo: Codable, Hashable {
    let Make: String
    let Model: String
    let ModelYear: String
    let EngineCylinders: String
}

@Observable
class OBDService {
    let elm327: ELM327
    var bleManager: BLEManager

    var elmAdapter: Peripheral? {
        bleManager.connectedPeripheral
    }

    var statusMessage: String? {
        elm327.statusMessage
    }

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        self.elm327 = ELM327(bleManager: bleManager)
    }

    func setupAdapter(setupOrder: [OBDCommand.General]) async throws -> OBDInfo {
        return try await elm327.setupAdapter(setupOrder: setupOrder)
    }

    // connect to the adapter
    func connectToAdapter(peripheral: Peripheral) async throws {
        _ = try await self.bleManager.connectAsync(peripheral: peripheral)
    }

    func scanForTroubleCodes() async throws -> [TroubleCode]? {
        return try await elm327.scanForTroubleCodes()
    }

    func clearTroubleCodes() async throws {
        try await elm327.clearTroubleCodes()
    }
}
