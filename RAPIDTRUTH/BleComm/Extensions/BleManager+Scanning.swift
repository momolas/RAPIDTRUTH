//
//  BleManager+Scanning.swift
//  SmartOBD2
//
//  Created by Jules the Agent on Refactor.
//

import Foundation
import CoreBluetooth
import OSLog

extension BLEManager {
    // MARK: - Scanning Logic

    func startScan(services: [CBUUID]) {
        let scanOption = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        centralManager.scanForPeripherals(withServices: services, options: scanOption)
        isSearching = true
    }

    func stopScan() {
        centralManager.stopScan()
        logger.debug("# Stop Scan")
        isSearching = false
    }

    // MARK: - CBCentralManagerDelegate - Discovery

    func didDiscover(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, advertisementData: [String : Any], rssi: NSNumber) {
        if rssi.intValue >= 0 { return }

        let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        var _name = "NoName"

        if let peripheralName {
            _name = peripheralName
        } else if let name = peripheral.name {
            _name = name
        }

        let foundPeripheral = Peripheral(_peripheral: peripheral, _name: _name, _advData: advertisementData, _rssi: rssi, _discoverCount: 0)

        Task { @MainActor in
            if let index = foundPeripherals.firstIndex(where: { $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }) {
                if foundPeripherals[index].discoverCount % 50 == 0 {
                    foundPeripherals[index].name = _name
                    foundPeripherals[index].rssi = rssi.intValue
                    foundPeripherals[index].discoverCount += 1
                } else {
                    foundPeripherals[index].discoverCount += 1
                }
            } else {
                foundPeripherals.append(foundPeripheral)
            }
        }
    }
}
