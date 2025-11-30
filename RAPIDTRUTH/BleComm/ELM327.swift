//
//  ELM327.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/5/23.
//

import Foundation
import CoreBluetooth
import OSLog
import Observation

struct ECUHeader {
    static let ENGINE = "7E0"
}

// Possible setup errors
enum SetupError: Error {
    case invalidResponse
    case noProtocolFound
    case adapterInitFailed
    case timeout
    case peripheralNotFound
    case ignitionOff
    case invalidProtocol
}

enum DataValidationError: Error {
    case oddDataLength
    case invalidDataFormat
    case insufficientDataLength
}

// MARK: - ELM327 Class

func decodeToStatus(_ result: OBDDecodeResult) -> Status? {
    switch result {
    case .statusResult(let value):
        return value
    default:
        return nil
    }
}

@Observable
class ELM327 {

    // MARK: - Properties
    var statusMessage: String = ""

    let logger = Logger.elmCom

    // Bluetooth UUIDs
    var elmServiceUUID = CBUUID(string: CarlyObd.elmServiceUUID)
    var elmCharactericUUID = CBUUID(string: CarlyObd.elmCharactericUUID)
    // Bluetooth manager
    var bleManager: BLEManager

    // MARK: - Initialization

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    var obdProtocol: OBDProtocol = .NONE

    // MARK: - Message Sending

    func sendMessageAsync(_ message: String, withTimeoutSecs: TimeInterval = 2) async throws -> [String] {
        do {
            let response: [String] = try await withTimeout(seconds: withTimeoutSecs) {
                let res = try await self.bleManager.sendMessageAsync(message)
                return res
            }
            return response
        } catch {
            logger.error("Error: \(error.localizedDescription)")
            throw SetupError.timeout
        }
    }

    // MARK: - Setup Steps

    func okResponse(message: String) async throws -> [String] {
        let response = try await self.bleManager.sendMessageAsync(message)
        if response.contains("OK") {
            return response
        } else {
            logger.error("Invalid response: \(response)")
            throw SetupError.invalidResponse
        }
    }

    func scanForTroubleCodes() async throws -> [TroubleCode]? {
        do {
            let command = OBDCommand.Mode3.GET_DTC
            let response = try await sendMessageAsync(command.properties.command)
            let messages = try OBDParser(response, idBits: obdProtocol.idBits).messages

            guard let data = messages[0].data else {
                return nil
            }
            
			guard let decodedValue = command.properties.decoder.decode(data: data) else {
                return nil
            }

            switch decodedValue {
                case .troubleCode(let value):
                    return value
                default:
                    return nil
            }
        } catch {
            logger.error("\(error.localizedDescription)")
            throw error
        }
    }

    func clearTroubleCodes() async throws {
        do {
            let command = OBDCommand.Mode4.CLEAR_DTC
            _ = try await sendMessageAsync(command.properties.command)
            logger.info("Trouble codes cleared")
        } catch {
            logger.error("Failed to clear trouble codes: \(error.localizedDescription)")
            throw error
        }
    }

    func requestDTC() async throws {
        do {
            let response = try await sendMessageAsync("0101")

            await decodeDTC(response: response)
        } catch {
            logger.error("\(error.localizedDescription)")
            throw error
        }
    }

    func decodeDTC(response: [String]) async {
        do {
            let messages = try OBDParser(response, idBits: obdProtocol.idBits).messages

            guard let data = messages[0].data else {
                return
            }

            let command: OBDCommand.Mode1 = .status

            guard let decodedValue = command.properties.decoder.decode(data: data) else {
                return
            }

            guard let status = decodeToStatus(decodedValue) else {
                return
            }
            if status.MIL {
                logger.info("\(status.dtcCount)")
                // get dtc's
            } else {
                logger.info("no dtc found")
            }
        } catch {

        }
    }

    func setupAdapter(setupOrder: [OBDCommand.General], autoProtocol: Bool = true) async throws -> OBDInfo {
        var obdInfo = OBDInfo()

//        if connectionState != .connectedToAdapter {
//            try await connectToAdapter()
//        }

        try await adapterInitialization(setupOrder: setupOrder)

        try await connectToVehicle(autoProtocol: autoProtocol)

        obdInfo.obdProtocol = obdProtocol
        await setHeader(header: ECUHeader.ENGINE)

        obdInfo.supportedPIDs = await getSupportedPIDs(obdProtocol)
        try await _ = okResponse(message: "ATH0")

        // Setup Complete will attempt to get the VIN Number
        if let vin = await requestVin() {
            obdInfo.vin = vin
        }
        try await _ = okResponse(message: "ATH1")


        return obdInfo
    }

    func requestVin() async -> String? {
        do {
            let vinResponse = try await sendMessageAsync("0902")
            let vin = await decodeVIN(response: vinResponse.joined())
            return vin
        } catch {
            logger.error("\(error.localizedDescription)")
            return nil
        }
    }

    private func adapterInitialization(setupOrder: [OBDCommand.General]) async throws {
        do {
            for step in setupOrder {
                switch step {
                case .ATD, .ATL0, .ATE0, .ATH1, .ATAT1, .ATSTFF, .ATH0:
                    _ = try await okResponse(message: step.properties.command)
                case .ATZ:
                    _ = try await sendMessageAsync(step.properties.command)
                case .ATRV:
                    // get the voltage
                    let voltage = try await sendMessageAsync(step.properties.command)
                    logger.info("Voltage: \(voltage)")
                case .ATDPN:
                    // Describe current protocol number
                    let protocolNumber = try await sendMessageAsync(step.properties.command)
                    self.obdProtocol = OBDProtocol(rawValue: protocolNumber[0]) ?? .protocol9
                default:
                    logger.error("Invalid Setup Step here: \(step.properties.description)")
                }
            }
        } catch {
            logger.error("\(error.localizedDescription)")
            throw SetupError.adapterInitFailed
        }
    }

    func connectToVehicle(autoProtocol: Bool) async throws {
        if autoProtocol {
            guard let _obdProtocol = try await autoProtocolDetection() else {
                logger.error("No protocol found")
                throw SetupError.noProtocolFound
            }
            obdProtocol = _obdProtocol
        } else {
            try await manualProtocolDetection()
        }
    }

    private func setHeader(header: String) async {
        do {
            _ = try await okResponse(message: "AT SH " + header + " ")
        } catch {
            logger.error("Set Header ('AT SH %s') did not return 'OK'")
        }
    }

    // MARK: - Protocol Selection

    private func autoProtocolDetection() async throws -> OBDProtocol? {
        do {
            _ = try await okResponse(message: "ATSP0")
            _ = try await sendMessageAsync("0100", withTimeoutSecs: 10)

            let obdProtocolNumber = try await sendMessageAsync("ATDPN")
            print(obdProtocolNumber[0].dropFirst())
            guard let obdProtocol = OBDProtocol(rawValue: String(obdProtocolNumber[0].dropFirst())) else {
                throw SetupError.invalidResponse
            }

            try await testProtocol(obdProtocol: obdProtocol)

            return obdProtocol
        } catch {
            logger.error("\(error.localizedDescription)")
            throw error
        }
    }

    private func manualProtocolDetection() async throws {
        do {
            while obdProtocol != .NONE {
                do {
                    try await testProtocol(obdProtocol: obdProtocol)
                    logger.info("Protocol: \(self.obdProtocol.description)")
                    return // Exit the loop if the protocol is found successfully
                } catch {
                    // Other errors are propagated
                    obdProtocol = obdProtocol.nextProtocol()
                }
            }
            // If we reach this point, no protocol was found
            logger.error("No protocol found")
            throw SetupError.noProtocolFound
        } catch {
            logger.error("\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Protocol Testing

    private func testProtocol(obdProtocol: OBDProtocol) async throws {
        do {
            // test protocol by sending 0100 and checking for 41 00 response
            _ = try await okResponse(message: obdProtocol.cmd)

            let r100 = try await sendMessageAsync("0100", withTimeoutSecs: 10)

            if r100.joined().contains("NO DATA") {
                logger.info("car is off")
                throw SetupError.ignitionOff
            }

            guard r100.joined().contains("41 00") else {
                logger.error("Invalid response to 0100")
                throw SetupError.invalidProtocol
            }

            logger.info("Protocol \(obdProtocol.rawValue) found")

            let response = try await sendMessageAsync("0100", withTimeoutSecs: 10)
            let messages = try OBDParser(response, idBits: obdProtocol.idBits).messages

            _ = populateECUMap(messages)
        } catch {
            logger.error("\(error.localizedDescription)")
            throw error
        }
    }

    private func populateECUMap(_ messages: [Message]) -> [UInt8: ECUID]? {
        let engineTXID = 0
        let transmissionTXID = 1
        var ecuMap: [UInt8: ECUID] = [:]

        // If there are no messages, return an empty map
        guard !messages.isEmpty else {
            return nil
        }

        // If there is only one message, assume it's from the engine
        if messages.count == 1 {
            ecuMap[messages[0].ecu?.rawValue ?? 0] = .engine
            return ecuMap
        }

        // Find the engine and transmission ECU based on TXID
        var foundEngine = false

        for message in messages {
            guard let txID = message.ecu?.rawValue else {
                logger.error("parse_frame failed to extract TX_ID")
                continue
            }

            if txID == engineTXID {
                ecuMap[txID] = .engine
                foundEngine = true
            } else if txID == transmissionTXID {
                ecuMap[txID] = .transmission
            }
        }

        // If engine ECU is not found, choose the one with the most bits
        if !foundEngine {
            var bestBits = 0
            var bestTXID: UInt8?

            for message in messages {
                guard let bits = message.data?.bitCount() else {
                    logger.error("parse_frame failed to extract data")
                    continue
                }
                if bits > bestBits {
                    bestBits = bits
                    bestTXID = message.ecu?.rawValue
                }
            }

            if let bestTXID = bestTXID {
                ecuMap[bestTXID] = .engine
            }
        }

        // Assign transmission ECU to messages without an ECU assignment
        for message in messages where ecuMap[message.ecu?.rawValue ?? 0] == nil {
            ecuMap[message.ecu?.rawValue ?? 0] = .transmission
        }

        return ecuMap
    }

    private func decodeVIN(response: String) async -> String {
        // Find the index of the occurrence of "49 02"
        guard let prefixIndex = response.range(of: "49 02")?.upperBound else {
            logger.error("Prefix not found in the response")
            return ""
        }

        // Extract the VIN hex string after "49 02"
        let vinHexString = response[prefixIndex...]
            .replacingOccurrences(of: " ", with: "")

        // Convert the hex string to ASCII characters
        var asciiString = ""
		let hex = vinHexString

        // Iterate through hex string in pairs
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if nextIndex > hex.endIndex { break }

            let hexPair = hex[index..<nextIndex]
            if let hexValue = UInt8(hexPair, radix: 16) {
                 // Skip non-printable characters
                if hexValue > 31 && hexValue < 127 {
                     asciiString.append(Character(UnicodeScalar(hexValue)))
                }
            }
            index = nextIndex
        }

        return asciiString
    }
}

struct BatchedResponse {
    private var buffer: Data

    init(response: Data) {
        self.buffer = response
    }

    mutating func getValueForCommand(_ cmd: OBDCommand) -> OBDDecodeResult? {
        guard buffer.count >= cmd.properties.bytes else {
                return nil
        }
        let value = buffer.prefix(cmd.properties.bytes)
//        print("value ",value.compactMap { String(format: "%02X ", $0) }.joined())

        buffer.removeFirst(cmd.properties.bytes)
//        print("Buffer: \(buffer.compactMap { String(format: "%02X ", $0) }.joined())")

        return cmd.properties.decoder.decode(data: value.dropFirst()).map { $0 }
    }
}

extension ELM327 {
	func requestPIDs(_ pids: [OBDCommand]) async -> [Message] {
        do {
            let response = try await sendMessageAsync(pids.compactMap { $0.properties.command }.joined())
            return try OBDParser(response, idBits: obdProtocol.idBits).messages
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        return []
    }
	
    func getSupportedPIDs(_ obdProtocol: OBDProtocol) async -> [OBDCommand] {
        let pidGetters = OBDCommand.pidGetters
        var supportedPIDs: [OBDCommand] = []

        for pidGetter in pidGetters {
            do {
                let response = try await sendMessageAsync(pidGetter.properties.command)
                // find first instance of 41 plus command sent, from there we determine the position of everything else
                // Ex.
                //        || ||
                // 7E8 06 41 00 BE 7F B8 13
                guard let supportedPidsByECU = try? parseResponse(response, obdProtocol) else {
                    continue
                }

                let supportedCommands = OBDCommand.allCommands
                    .filter { supportedPidsByECU.contains(String($0.properties.command.dropFirst(2))) }
                    .map { $0 }

                supportedPIDs.append(contentsOf: supportedCommands)
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }
        // remove duplicates
        return Array(Set(supportedPIDs))
    }

    private func parseResponse(_ response: [String], _ obdProtocol: OBDProtocol) throws -> Set<String> {
        let messages = try OBDParser(response, idBits: obdProtocol.idBits).messages

        guard !messages.isEmpty,
              let ecuData = messages[0].data else {
            throw NSError(domain: "Invalid data format", code: 0, userInfo: nil)
        }
        print(ecuData[1...].compactMap { String(format: "%02X", $0) }.joined(separator: " "))
        let binaryData = BitArray(data: ecuData[1...]).binaryArray
        print(binaryData)
        return extractSupportedPIDs(binaryData)
    }

    func extractSupportedPIDs(_ binaryData: [Int]) -> Set<String> {
        var supportedPIDs: Set<String> = []

        for (index, value) in binaryData.enumerated() {
            if value == 1 {
                let pid = String(format: "%02X", index + 1)
                supportedPIDs.insert(pid)
            }
        }
        return supportedPIDs
    }

    func extractDataLength(_ startIndex: Int, _ response: [String]) throws -> Int? {
        guard let lengthHex = UInt8(response[startIndex - 1], radix: 16) else {
            return nil
        }
        // Extract frame data, type, and dataLen
        // Ex.
        //     ||
        // 7E8 06 41 00 BE 7F B8 13

        let frameType = FrameType(rawValue: lengthHex & 0xF0)

        switch frameType {
        case .singleFrame:
            return Int(lengthHex) & 0x0F
        case .firstFrame:
            guard let secondLengthHex = UInt8(response[startIndex - 2], radix: 16) else {
                throw NSError(domain: "Invalid data format", code: 0, userInfo: nil)
            }
            return Int(lengthHex) + Int(secondLengthHex)
        case .consecutiveFrame:
            return Int(lengthHex)
        default:
            return nil
        }
    }

    func hexToBinary(_ hexString: String) -> String? {
        // Create a scanner to parse the hex string
        let scanner = Scanner(string: hexString)

        // Check if the string starts with "0x" or "0X" and skip it if present
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "0x")
        var intValue: UInt64 = 0

        // Use the scanner to convert the hex string to an integer
        if scanner.scanHexInt64(&intValue) {
            // Convert the integer to a binary string with leading zeros
            let binaryString = String(intValue, radix: 2)
            let leadingZerosCount = hexString.count * 4 - binaryString.count
            let leadingZeros = String(repeating: "0", count: leadingZerosCount)
            return leadingZeros + binaryString
        }
        // Return nil if the conversion fails
        return nil
    }
}
