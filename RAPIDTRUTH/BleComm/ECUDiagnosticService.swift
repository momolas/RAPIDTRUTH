//
//  ECUDiagnosticService.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import Foundation

class ECUDiagnosticService {
    let obdService: OBDService

    init(obdService: OBDService) {
        self.obdService = obdService
    }

    func loadECU(from jsonString: String) throws -> ECUDefinition {
        let data = Data(jsonString.utf8)
        return try JSONDecoder().decode(ECUDefinition.self, from: data)
    }

    func loadECU(from fileURL: URL) throws -> ECUDefinition {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ECUDefinition.self, from: data)
    }

    func loadLayout(from fileURL: URL) throws -> ECULayout {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ECULayout.self, from: data)
    }

    func execute(request: ECURequest, definition: ECUDefinition, ecu: DatabaseECU? = nil) async throws -> [String: String] {
        // 1. Prepare Protocol and Header if ECU info is provided
        if let ecu = ecu {
             try await setupHeader(for: ecu)
        }

        // 2. Send the command
        // Note: sentbytes is a hex string e.g., "3BC100"
        let command = request.sentbytes

        let rawResponse = try await obdService.sendRawCommand(command)

        // 3. Parse the response
        // rawResponse is [String], e.g. ["61 93 12 ..."]
        guard let firstLine = rawResponse.first else { return [:] }

        // Clean response
        let cleanHex = firstLine.replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: ">", with: "")

        // Handle "NO DATA" or errors
        if cleanHex.contains("NODATA") || cleanHex.contains("ERROR") {
             return ["Status": cleanHex]
        }

        let dataBytes = Data(hexString: cleanHex)

        guard let dataBytes = dataBytes else { return ["Error": "Invalid Hex Response: \(cleanHex)"] }

        return decode(data: dataBytes, request: request, definition: definition)
    }

    private func setupHeader(for ecu: DatabaseECU) async throws {
        // Handle protocol and addressing logic based on X84_db.json format
        // Example: "address": "7A", "protocol": "CAN"

        guard let addressStr = getAddress(ecu: ecu) else { return }

        // Determine Header command based on Protocol
        // X84 is typically CAN (ISO 15765) or KWP2000

        if ecu.protocol?.uppercased() == "CAN" {
             // For Renault CAN, standard ID is often 0x700 + Addr
             // e.g. "7A" -> 0x77A. "01" (ABS) -> 0x701? (Wait, ABS is usually 760 or similar, but X84 might use simplified addressing)
             // Let's assume the DB "address" is the lower byte of the 11-bit CAN ID 0x7xx.
             // command: AT SH 7xx

             // If address is "7A", header is "77A"
             // If address is "01", header is "701" ?
             // NOTE: Some Renault DBs use a mapping. But without it, 7xx is the best guess.
             // Or maybe "address" IS the full ID? "7A" is too short. "58" too short.
             // So 7<Address> is highly probable for Renault Diag on CAN.

             let header = "7\(addressStr)"
             _ = try await obdService.sendRawCommand("AT SH \(header)")

        } else if ecu.protocol?.uppercased().contains("KWP") == true {
             // KWP2000 (ISO 14230)
             // Header format: Priority Target Source
             // Target = Address. Source = F1 (Scanner). Priority = 81 (Physical) or C1/80.
             // Standard: AT SH 81 <Addr> F1

             let header = "81 \(addressStr) F1"
             _ = try await obdService.sendRawCommand("AT SH \(header)")

             // Also might need to switch protocol?
             // Ideally we should use `AT SP ...` but that might reset connection.
             // Assuming user/app is in compatible mode or Auto.
        }
    }

    private func getAddress(ecu: DatabaseECU) -> String? {
        // Address in DB is string "7A", "01", "26"...
        guard !ecu.address.isEmpty else { return nil }
        return ecu.address
    }

    private func decode(data: Data, request: ECURequest, definition: ECUDefinition) -> [String: String] {
        var results: [String: String] = [:]

        guard let bindings = request.receivebyte_dataitems else {
            return ["Raw": data.map { String(format: "%02X", $0) }.joined(separator: " ")]
        }

        for (itemName, binding) in bindings {
            guard let itemDef = definition.data[itemName] else {
                results[itemName] = "No Definition"
                continue
            }

            // Adjust index: definitions often include the Service ID in the count, or are 1-based.
            // In a raw response "61 80 12...", 61 is the Positive Response SID.
            // If binding says "firstbyte": 1. Does it mean 61? Or 80?
            // Usually in DDT/Renault json, 1 is the Service ID.
            // So byteIndex = binding.firstbyte - 1.

            let byteIndex = binding.firstbyte - 1

            let byteCount = itemDef.bytescount ?? 1

            guard byteIndex < data.count else {
                results[itemName] = "N/A"
                continue
            }

            // Extract bytes
            var rawValue: Int = 0
            if byteIndex + byteCount <= data.count {
                // Check Endianness (Global definition `endian`)
                // Default Big Endian for OBD usually.
                // If "Little", we swap.
                // definition.endian == "Little" ?

                let isLittle = (definition.endian == "Little")

                if isLittle {
                    for i in 0..<byteCount {
                        rawValue |= Int(data[byteIndex + i]) << (8 * i)
                    }
                } else {
                    for i in 0..<byteCount {
                        rawValue = (rawValue << 8) | Int(data[byteIndex + i])
                    }
                }
            } else {
                results[itemName] = "Out of bounds"
                continue
            }

            // Handle Bits
            if let bitOffset = binding.bitoffset {
                // DDT2000: bitoffset usually 0..7.
                // Is it 0=LSB?
                let bitsCount = itemDef.bitscount ?? 1
                let mask = (1 << bitsCount) - 1
                rawValue = (rawValue >> bitOffset) & mask
            }

            // Decode Logic
            if let lists = itemDef.lists {
                // Discrete values
                // Lists keys are strings in JSON "0", "1"...
                results[itemName] = lists[String(rawValue)] ?? "\(rawValue)"
            } else if itemDef.scaled == true {
                // Scaling
                var physValue = Double(rawValue)

                if itemDef.signed == true {
                   // Handle signed integer of `bitscount` or `byteCount*8` bits
                   let totalBits = (itemDef.bitscount ?? (byteCount * 8))
                   let maxVal = 1 << (totalBits - 1)
                   if rawValue >= maxVal {
                       rawValue -= (1 << totalBits)
                       physValue = Double(rawValue)
                   }
                }

                if let divideBy = itemDef.divideby, divideBy != 0 {
                    physValue /= divideBy
                }
                if let step = itemDef.step {
                     physValue *= step
                }

                if let offset = itemDef.offset {
                    physValue += offset
                }

                let unit = itemDef.unit ?? ""
                results[itemName] = String(format: "%.2f %@", physValue, unit)

            } else if itemDef.bytesascii == true {
                // ASCII String
                let subData = data.subdata(in: byteIndex..<min(byteIndex+byteCount, data.count))
                // Filter non-printable
                let str = String(data: subData, encoding: .ascii) ?? ""
                results[itemName] = str.trimmingCharacters(in: .controlCharacters)
            } else {
                // Default raw
                results[itemName] = String(rawValue)
            }
        }

        return results
    }
}

// Helper for Hex Data
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var ptr = hexString.startIndex
        for _ in 0..<len {
            let end = hexString.index(ptr, offsetBy: 2)
            let bytes = hexString[ptr..<end]
            if let num = UInt8(bytes, radix: 16) {
                data.append(num)
            } else {
                return nil
            }
            ptr = end
        }
        self = data
    }
}
