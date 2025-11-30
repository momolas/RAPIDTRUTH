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
