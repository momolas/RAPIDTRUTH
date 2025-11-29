//
//  SettingsScreenViewModel.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/31/23.
//

import Foundation
import CoreBluetooth
import Observation

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

extension OBDService {
    func sendRawCommand(_ command: String) async throws -> [String] {
        return try await elm327.sendMessageAsync(command)
    }

    func getMILStatus() async throws -> Status? {
        // Mode 01 PID 01 returns Monitor status since DTCs cleared
        // It includes MIL status and DTC count
        let response = try await elm327.sendMessageAsync("0101")

        let messages = try OBDParser(response, idBits: elm327.obdProtocol.idBits).messages
        guard let data = messages.first?.data else { return nil }

        let command: OBDCommand.Mode1 = .status
        guard let decodedValue = command.properties.decoder.decode(data: data) else { return nil }

        if case .statusResult(let status) = decodeToStatus(decodedValue) {
            return status
        }
        return nil
    }
}
