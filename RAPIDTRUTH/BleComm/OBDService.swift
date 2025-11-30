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
    var vinInfo: VINInfo?
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
        var info = try await elm327.setupAdapter(setupOrder: setupOrder)
        if let vin = info.vin {
            if let vinInfo = decodeVIN(vin) {
                info.vinInfo = vinInfo
            }
        }
        return info
    }

    func decodeVIN(_ vin: String) -> VINInfo? {
        // Local decoding for better European support and offline capability
        guard vin.count == 17 else { return nil }

        let wmi = String(vin.prefix(3))
        let make = WMIData.getMake(from: wmi) ?? "Unknown"

        let yearChar = vin[vin.index(vin.startIndex, offsetBy: 9)]
        let year = WMIData.getYear(from: yearChar)

        // VDS (Vehicle Descriptor Section) - chars 4-9
        // VDS decoding is complex and highly manufacturer specific.
        // We use the last 6 digits (VIS) as a cleaner identifier if VDS fails.
        let vds = String(vin.dropFirst(3).prefix(6))

        // Improve UX by not showing "Unknown (VDS:...)" unless debug
        // Ideally we would use a comprehensive database or API here.
        let model: String
        if make == "Unknown" {
            model = "Unknown Model"
        } else {
            // For now, just show the VDS code cleanly so the user can verify it against their papers
            model = "Model Code: \(vds)"
        }

        return VINInfo(Make: make, Model: model, ModelYear: year, EngineCylinders: "")
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

        return decodeToStatus(decodedValue)
    }
}
