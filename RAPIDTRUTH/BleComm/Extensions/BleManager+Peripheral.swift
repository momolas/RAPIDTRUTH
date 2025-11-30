//
//  BleManager+Peripheral.swift
//  SmartOBD2
//
//  Created by Jules the Agent on Refactor.
//

import Foundation
import CoreBluetooth
import OSLog

extension BLEManager {

    // MARK: - Services & Characteristics

    func discoverPeripheralServices(_ peripheral: CBPeripheralProtocol) {
        peripheral.discoverServices(nil)
    }

    func didDiscoverServices(_ peripheral: CBPeripheralProtocol, error: Error?) {
        if let error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            return
        }
        if let services = peripheral.services {
            for service in services {
                logger.info("Found Service: \(service)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func didDiscoverCharacteristics(_ peripheral: CBPeripheralProtocol, service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            logger.error("No characteristics found")
            return
        }

        Task { @MainActor in
            self.discoveredServicesAndCharacteristics.append((service, characteristics))

            for characteristic in characteristics {
                switch characteristic.uuid.uuidString {
                    case UserDevice.properties.characteristicUUID:
                        logger.info("ecu \(characteristic)")
                        ecuCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                        logger.info("Adapter Ready")
                    default:
                        if debug {
                            logger.info("Unhandled Characteristic UUID: \(characteristic)")
                        }

                        if characteristic.properties.contains(.notify) {
                            peripheral.setNotifyValue(true, for: characteristic)
                        }
                }
            }
        }
    }

    // MARK: - Data Transfer

    func didUpdateValue(_ peripheral: CBPeripheralProtocol, characteristic: CBCharacteristic, error: Error?) {
        if let error {
            logger.error("Error reading characteristic value: \(error.localizedDescription)")
            return
        }

        guard let characteristicValue = characteristic.value else {
            return
        }

        switch characteristic.uuid.uuidString {
            case UserDevice.properties.characteristicUUID:
                processReceivedData(characteristicValue, completion: sendMessageCompletion)
            default:
                logger.info("Unknown characteristic: \(characteristic.uuid.uuidString)")
                if let responseString = String(data: characteristicValue, encoding: .utf8) {
                    logger.info("\(responseString)")
                } else {
                    logger.warning("Invalid data format for characteristic: \(characteristic.uuid.uuidString)")
                }
        }
    }

    func processReceivedData(_ data: Data, completion: (([String]?, Error?) -> Void)?) {
        buffer.append(data)

        guard var string = String(data: buffer, encoding: .utf8) else {
            logger.warning("Failed to convert data to a string")
            buffer.removeAll()
            return
        }

        if string.contains(">") {
            string = string
                .replacingOccurrences(of: "\u{00}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Split into lines while removing empty lines
            var lines = string
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }

            // remove the last line
            lines.removeLast()

            if debug {
                logger.info("Response: \(lines)")
            }

            completion?(lines, nil)
            buffer.removeAll()
        }
    }
}
