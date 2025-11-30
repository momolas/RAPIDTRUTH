//
//  bleConnection.swift
//  Obd2Scanner
//
//  Created by kemo konteh on 8/3/23.
//

import Foundation
import CoreBluetooth
import OSLog
import Observation

enum ConnectionState {
	case notInitialized
	case connecting
	case connectedToAdapter
	case connectedToVehicle
	case failed
	case initialized
	
	var isConnected: Bool {
		switch self {
			case .notInitialized, .connecting, .failed:
				return false
			case  .connectedToAdapter, .connectedToVehicle, .initialized:
				return true
		}
	}
	
	var description: String {
		switch self {
			case .notInitialized:
				return "Not Initialized"
			case .connecting:
				return "Connecting"
			case .connectedToAdapter:
				return "Connected to Adapter"
			case .connectedToVehicle:
				return "Connected to Vehicle"
			case .failed:
				return "Failed"
			case .initialized:
				return "Initialized"
		}
	}
}

struct DeviceInfo {
	let DeviceName: String
	let serviceUUID: String
	let peripheralUUID: String
	let characteristicUUID: String
}

enum OBDDevices: CaseIterable {
	case carlyOBD
	case other
	
	var properties: DeviceInfo {
		switch self {
			case .carlyOBD:
				return DeviceInfo(DeviceName: "Carly",
								  serviceUUID: "FFE0",
								  peripheralUUID: "5B6EE3F4-2FCA-CE45-6AE7-8D7390E64D6D",
								  characteristicUUID: "FFE1"
				)
			case .other:
				return DeviceInfo(DeviceName: "Other",
								  serviceUUID: "Unknown",
								  peripheralUUID: "Mystery",
								  characteristicUUID: "Unknown"
				)
		}
	}
}

@Observable
class BLEManager: NSObject, CBPeripheralProtocolDelegate, CBCentralManagerProtocolDelegate {
	let logger = Logger.bleCom
	
	// MARK: Properties
	
	var isSearching: Bool = false
	var connectionState: ConnectionState = .notInitialized
	// Bluetooth
	var ecuCharacteristic: CBCharacteristic?
	var connectedPeripheral: Peripheral?
	var foundPeripherals: [Peripheral] = []
	var discoveredServicesAndCharacteristics: [(CBService, [CBCharacteristic])] = []
	
    @ObservationIgnored
    internal lazy var centralManager: CBCentralManagerProtocol = {
#if targetEnvironment(simulator)
		return CBCentralManagerMock(delegate: self, queue: nil)
#else
		return CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: BLEManager.RestoreIdentifierKey])
#endif
	}()
	
	static let RestoreIdentifierKey: String = "OBD2Adapter"
	
	var UserDevice: OBDDevices = .carlyOBD
	
	var debug = true
	
	var buffer = Data()
	
    internal var commandQueue: [CheckedContinuation<Void, Never>] = []
    internal var isProcessing = false
    internal let queueLock = NSLock()

	var sendMessageCompletion: (([String]?, Error?) -> Void)?
	var connectionCompletion: ((CBPeripheralProtocol) -> Void)?
	
	// MARK: Initialization
	
	override init() {
		super.init()
		// Initialize centralManager
		_ = centralManager
	}

	enum SendMessageError: Error {
		case missingPeripheralOrCharacteristic
		case timeout
		case stringConversionFailed
	}

    // MARK: - Delegate Forwarding
    // Note: The logic has been moved to Extensions/BleManager+*.swift files.
    // The delegate methods are implemented in extensions there.
}

extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		didDiscoverServices(peripheral, error: error)
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		didDiscoverCharacteristics(peripheral, service: service, error: error)
	}
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		didUpdateValue(peripheral, characteristic: characteristic, error: error)
	}
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
		didDiscover(central, peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
	}
	
	func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
		willRestoreState(central, dict: dict)
	}
	
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		didConnect(central, peripheral: peripheral)
	}
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		didUpdateState(central)
	}
	
	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
		didFailToConnect(central, peripheral: peripheral, error: error)
	}
	
	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		didDisconnect(central, peripheral: peripheral, error: error)
	}

    func connectionEventDidOccur(_ central: CBCentralManagerProtocol, event: CBConnectionEvent, peripheral: CBPeripheralProtocol) {
        // Required by CBCentralManagerProtocolDelegate but not yet implemented logic
        logger.info("Connection event did occur: \(event.rawValue) for \(peripheral.identifier)")
        if event == .peerDisconnected {
            didDisconnect(central, peripheral: peripheral, error: nil)
        }
    }
}
