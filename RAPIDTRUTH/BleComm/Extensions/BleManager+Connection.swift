//
//  BleManager+Connection.swift
//  SmartOBD2
//
//  Created by Jules the Agent on Refactor.
//

import Foundation
import CoreBluetooth
import OSLog

extension BLEManager {
    // MARK: - Connection Logic

    func connect(to selectPeripheral: Peripheral) {
        let connectPeripheral = selectPeripheral
        connectedPeripheral = selectPeripheral
        centralManager.connect(connectPeripheral.peripheral, options: nil)
        stopScan()
    }

    func disconnectPeripheral() {
        guard let connectedPeripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(connectedPeripheral.peripheral)
    }

    func connectAsync(peripheral: Peripheral) async throws -> CBPeripheralProtocol {
        peripheral.peripheral.delegate = self
        connect(to: peripheral)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CBPeripheralProtocol, Error>) in
            // Set up a timeout timer or handle completion
            self.connectionCompletion = { peripheral in
                continuation.resume(returning: peripheral)
            }
            // Note: Ideally, add a timeout logic here similar to sendMessageAsync
        }
    }

    // MARK: - CBCentralManagerDelegate - Connection Events

    func didConnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol) {
        logger.debug("Connected to peripheral: \(peripheral.name ?? "Unnamed")")
        discoverPeripheralServices(peripheral)
        connectedPeripheral?.peripheral.delegate = self
        connectionCompletion?(peripheral)
        Task { @MainActor in
            self.connectionState = .connectedToAdapter
        }
    }

    func didFailToConnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, error: Error?) {
        logger.error("Failed to connect to peripheral: \(peripheral.name ?? "Unnamed")")
        Task { @MainActor in
            connectedPeripheral = nil
        }
        disconnectPeripheral()
    }

    func didDisconnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, error: Error?) {
        logger.warning("Disconnected from peripheral: \(peripheral.name ?? "Unnamed")")
        Task { @MainActor in
            connectedPeripheral = nil
            connectionState = .notInitialized
        }
        resetConfigure()
    }

    func resetConfigure() {
        ecuCharacteristic = nil
        discoveredServicesAndCharacteristics = []
    }

    func didUpdateState(_ central: CBCentralManagerProtocol) {
        Task { @MainActor in
            switch central.state {
                case .poweredOn:
                    logger.debug("Bluetooth is On.")
                    guard let device = connectedPeripheral else {
                        // Assuming UserDevice is available or passed in some way
                        // For now accessing self.UserDevice
                        startScan(services: [CBUUID(string: UserDevice.properties.serviceUUID)])
                        return
                    }
                    connectionState = .connecting
                    connect(to: device)
                case .poweredOff:
                    logger.warning("Bluetooth is currently powered off.")
                    connectionState = .notInitialized
                case .unsupported:
                    logger.error("This device does not support Bluetooth Low Energy.")
                    connectionState = .failed
                case .unauthorized:
                    logger.error("This app is not authorized to use Bluetooth Low Energy.")
                    connectionState = .failed
                case .resetting:
                    logger.warning("Bluetooth is resetting.")
                default:
                    logger.error("Bluetooth is not powered on.")
                    connectionState = .failed
            }
        }
    }

    func willRestoreState(_ central: CBCentralManagerProtocol, dict: [String : Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            logger.debug("Restoring \(peripherals.count) peripherals")

            for peripheral in peripherals {
                logger.debug("Restoring peripheral: \(peripheral.name ?? "Unnamed")")

                if isDevicePeripheral(peripheral) {
                    peripheral.delegate = self

                    Task { @MainActor in
                        connectedPeripheral = Peripheral(_peripheral: peripheral,
                                                         _name: peripheral.name ?? "Unnamed",
                                                         _advData: nil,
                                                         _rssi: nil,
                                                         _discoverCount: 0)
                        connectionState = .connectedToAdapter
                    }
                }
            }
        }
    }

    internal func isDevicePeripheral(_ peripheral: CBPeripheral) -> Bool {
        return UserDevice.properties.peripheralUUID == peripheral.identifier.uuidString
    }
}
