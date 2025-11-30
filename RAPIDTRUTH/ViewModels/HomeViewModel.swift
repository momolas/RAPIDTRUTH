//
//  HomeViewModel.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Observation
import CoreBluetooth

@Observable
class HomeViewModel {
    var obdInfo = OBDInfo()

    var vinInput = ""
    var vinInfo: VINInfo?
    var selectedProtocol: OBDProtocol = .NONE
    var garage: Garage

    // Dashboard Live Data
    var dashboardBatteryVoltage: String = "-- V"
    var dashboardDTCCount: Int = 0
    var isConnected: Bool {
        obdService.elmAdapter?.peripheral.state == .connected
    }

    var currentVehicle: Vehicle? {
        garage.currentVehicle
    }

    let obdService: OBDService

    init(obdService: OBDService, garage: Garage) {
        self.obdService = obdService
        self.garage = garage
    }

    @MainActor
    func identifyVehicle() async {
        guard isConnected else { return }
        // Standard setup order for ELM327
        let setupOrder: [OBDCommand.General] = [.ATZ, .ATE0, .ATL0, .ATH1, .ATAT1, .ATSTFF, .ATDPN]

        do {
            let info = try await obdService.setupAdapter(setupOrder: setupOrder)
            self.obdInfo = info

            if let vin = info.vin, !vin.isEmpty {
                // Check if vehicle exists in Garage
                if let existingVehicle = garage.getVehicle(vin: vin) {
                    garage.setCurrentVehicle(by: existingVehicle.vin)
                    print("Identified existing vehicle: \(existingVehicle.make) \(existingVehicle.model)")
                } else {
                    // Add new vehicle
                    let vinInfo = obdService.decodeVIN(vin)
                    let make = vinInfo?.Make ?? "Unknown"
                    let model = vinInfo?.Model ?? "Unknown Model"
                    let year = vinInfo?.ModelYear ?? "Unknown Year"

                    garage.addVehicle(make: make, model: model, year: year, vin: vin, obdinfo: info)
                    print("Added and selected new vehicle: \(make) \(model) - \(vin)")
                }
            } else {
                print("Could not retrieve VIN from vehicle.")
            }
        } catch {
            print("Error identifying vehicle: \(error)")
        }
    }

    @MainActor
    func refreshDashboardData() async {
        guard isConnected else { return }

        do {
            // Fetch Battery Voltage
            // ATRV is the ELM327 command for reading voltage
            let voltageResponse = try await obdService.sendRawCommand("ATRV")
            // Response is typically "12.5V"
            let voltage = voltageResponse.first?.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? "-- V"
            self.dashboardBatteryVoltage = voltage

            // Fetch DTC Count (Mode 01 01)
            // returns 41 00 xx xx ... first byte A, high bit is MIL status, low 7 bits is DTC count
            // We can reuse ELM327.requestDTC logic but it logs instead of returning
            // Let's implement a specific call or interpret it here.
            // Actually, ELM327 has requestDTC() which decodes it. We might need to expose it.
            // For now, let's just use a simple check if possible, or leave DTC as 0 until user scans.
            // A full DTC scan (Mode 03) is slow. Mode 01 01 is fast and gives the count.

            // We will use a helper in OBDService to get this status info.
            if let status = try await obdService.getMILStatus() {
                self.dashboardDTCCount = Int(status.dtcCount)
            }

        } catch {
            print("Failed to refresh dashboard: \(error)")
        }
    }
}
