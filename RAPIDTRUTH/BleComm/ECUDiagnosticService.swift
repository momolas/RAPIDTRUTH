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

    func execute(request: ECURequest, definition: ECUDefinition) async throws -> [String: String] {
        // 1. Send the command
        // Note: sentbytes is a hex string e.g., "3BC100"
        let command = request.sentbytes

        // This relies on the adapter being in the correct protocol state.
        // The JSON specifies protocol ("KWP2000") and init parameters, which ideally should be handled by setup.
        // For now, we assume the user/app has set up the connection or we try sending raw.

        let rawResponse = try await obdService.sendRawCommand(command)

        // 2. Parse the response
        // rawResponse is [String], e.g. ["61 93 12 ..."]
        guard let firstLine = rawResponse.first else { return [:] }

        // Clean response
        let cleanHex = firstLine.replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: ">", with: "")
        let dataBytes = Data(hexString: cleanHex)

        guard let dataBytes = dataBytes else { return ["Error": "Invalid Hex Response"] }

        return decode(data: dataBytes, request: request, definition: definition)
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

            // Extract Raw Value
            // firstbyte is 1-based index in the JSON usually? Let's check.
            // "firstbyte": 8. In a response like "61 ...", bytes are 0-indexed.
            // Often these definitions start counting after the Service ID or Header?
            // "sentbytes": "2192", response likely "61 92 ..."
            // Standard ODX/JSON often uses 1-based index into the FULL payload including SID.

            let byteIndex = binding.firstbyte - 1 // Convert 1-based to 0-based

            // Determine length
            let byteCount = itemDef.bytescount ?? 1

            guard byteIndex < data.count else {
                results[itemName] = "N/A"
                continue
            }

            // Extract bytes
            // Handle multi-byte extraction (Big Endian per JSON "endian": "Big")
            var rawValue: Int = 0
            if byteIndex + byteCount <= data.count {
                for i in 0..<byteCount {
                    rawValue = (rawValue << 8) | Int(data[byteIndex + i])
                }
            } else {
                results[itemName] = "Out of bounds"
                continue
            }

            // Handle Bits
            // If bitscount or bitoffset is present
            // JSON example: "bitoffset": 1, "firstbyte": 5. "bitscount": 1 (implied if boolean?)
            // Example: "Historical Failure": { "bitoffset": 1, "firstbyte": 5 }, "bitscount": 1 in Data.
            if let bitOffset = binding.bitoffset {
                // Usually bitoffset 0 = LSB, 7 = MSB. Or reverse.
                // Assuming standard: (byte >> bitOffset) & 1
                // Wait, some definitions use 7-0.
                // Let's assume standard right shift for now.
                let bitsCount = itemDef.bitscount ?? 1
                let mask = (1 << bitsCount) - 1
                rawValue = (rawValue >> bitOffset) & mask
            }

            // Decode Logic
            if let lists = itemDef.lists {
                // Discrete values
                results[itemName] = lists[String(rawValue)] ?? "Unknown (\(rawValue))"
            } else if itemDef.scaled == true {
                // Scaling
                var physValue = Double(rawValue)

                // Signed?
                // If signed and simple byte, e.g. -40 to 215.
                // If definitions say "signed": true
                if itemDef.signed == true {
                   // Need to handle 2's complement based on bit size
                   // Simple case for now
                }

                if let divideBy = itemDef.divideby {
                    physValue /= divideBy
                }
                if let step = itemDef.step {
                     // Step usually means multiplier? or Step size.
                     // Often phys = raw * step + offset
                     // But here divideby is explicit.
                     // Example: "divideby": 1000.0, "step": 16.0.
                     // This might mean: Value = Raw * Step / DivideBy ?
                     // Or maybe Step is resolution.
                     // Let's try standard linear: y = mx + b
                     // If step is present, use it as multiplier.
                     physValue *= step
                }

                if let offset = itemDef.offset {
                    physValue += offset
                }

                let unit = itemDef.unit ?? ""
                // Format decimal places
                results[itemName] = String(format: "%.2f %@", physValue, unit)

            } else if itemDef.bytesascii == true {
                // ASCII String
                let subData = data.subdata(in: byteIndex..<min(byteIndex+byteCount, data.count))
                results[itemName] = String(data: subData, encoding: .utf8) ?? "Invalid String"
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
