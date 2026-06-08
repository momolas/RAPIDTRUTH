import Foundation

enum VINReader {
    /// Send Mode 09 PID 02 (Vehicle ID) and parse the 17-byte VIN out of the
    /// multi-frame ISO-TP response. Returns nil if the ECU doesn't respond
    /// with a VIN, or the parsed string isn't a 17-char alphanumeric VIN.
    @MainActor
    static func read(interface: VehicleInterface) async throws -> String? {
        try Task.checkCancellation()
        
        // 1. If it's a PandaDriver, perform active CAN bus auto-detection
        if let panda = interface as? PandaDriver {
            var activeBus: UInt8? = nil
            
            // 1a. Try 11-bit standard diagnostic ping on buses 0, 1, 2
            for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                panda.bus = testBus
                try? await panda.setTarget(txID: "7DF", rxID: "7E8")
                if let response = try? await panda.sendDiagnosticRequest("0100", timeout: 1.0) {
                    let normalized = response.uppercased().replacing(" ", with: "")
                    if normalized.contains("4100") {
                        activeBus = testBus
                        NSLog("[VINReader] Detected active 11-bit CAN bus: \(testBus)")
                        break
                    }
                }
            }
            
            // 1b. Try 29-bit standard diagnostic ping on buses 0, 1, 2
            if activeBus == nil {
                for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                    panda.bus = testBus
                    try? await panda.setTarget(txID: "18DB33F1", rxID: "18DAF110")
                    if let response = try? await panda.sendDiagnosticRequest("0100", timeout: 1.0) {
                        let normalized = response.uppercased().replacing(" ", with: "")
                        if normalized.contains("4100") {
                            activeBus = testBus
                            NSLog("[VINReader] Detected active 29-bit CAN bus: \(testBus)")
                            break
                        }
                    }
                }
            }
            
            // 1c. Try Renault-specific physical engine ping on buses 0, 1, 2
            if activeBus == nil {
                for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                    panda.bus = testBus
                    try? await panda.setTarget(txID: "7E0", rxID: "7E8")
                    if let response = try? await panda.sendDiagnosticRequest("2181", timeout: 1.0) {
                        let normalized = response.uppercased().replacing(" ", with: "")
                        if normalized.contains("6181") {
                            activeBus = testBus
                            NSLog("[VINReader] Detected active Renault CAN bus: \(testBus)")
                            break
                        }
                    }
                }
            }
            
            if let activeBus {
                panda.bus = activeBus
            } else {
                NSLog("[VINReader] No active CAN bus detected during 0100 probe, defaulting to Bus 0")
                panda.bus = 0
            }
        }
        
        // 2. Perform Multi-stage VIN discovery fallback
        
        // Stage A: Standard 11-bit OBD2 query
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7DF", rxID: "7E8")
            let response = try await interface.sendDiagnosticRequest("0902", timeout: 5.0)
            if let vin = parseVINResponse(response) {
                NSLog("[VINReader] Success reading standard 11-bit VIN: \(vin)")
                return vin
            }
        } catch {
            NSLog("[VINReader] Stage A (11-bit OBD2) failed/timed out: \(error)")
        }
        
        // Stage B: Standard 29-bit OBD2 query
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "18DB33F1", rxID: "18DAF110")
            let response = try await interface.sendDiagnosticRequest("0902", timeout: 5.0)
            if let vin = parseVINResponse(response) {
                NSLog("[VINReader] Success reading standard 29-bit VIN: \(vin)")
                return vin
            }
        } catch {
            NSLog("[VINReader] Stage B (29-bit OBD2) failed/timed out: \(error)")
        }
        
        // Stage C: Renault physical Injection ECU (7E0) UDS query
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            let response = try await interface.sendDiagnosticRequest("2181", timeout: 3.0)
            if let vin = parseRenaultVINResponse(response) {
                NSLog("[VINReader] Success reading Renault Engine VIN: \(vin)")
                return vin
            }
        } catch {
            NSLog("[VINReader] Stage C (Renault Engine UDS) failed/timed out: \(error)")
        }
        
        // Stage D: Renault physical UCH (745) UDS query
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "745", rxID: "765")
            let response = try await interface.sendDiagnosticRequest("2181", timeout: 3.0)
            if let vin = parseRenaultVINResponse(response) {
                NSLog("[VINReader] Success reading Renault UCH VIN: \(vin)")
                return vin
            }
        } catch {
            NSLog("[VINReader] Stage D (Renault UCH UDS) failed/timed out: \(error)")
        }
        
        return nil
    }

    /// Parses a Mode 09 PID 02 response into a 17-char VIN. Mirrors the web
    /// app's `parseVinResponse` in `src/obd/vin.ts`.
    ///
    /// Strategy (permissive — adapters format differently):
    ///   1. Split on whitespace; drop empty lines.
    ///   2. Strip leading frame-index prefixes like `0:`, `1:`, `2:` that some
    ///      adapters emit on multi-frame responses.
    ///   3. Concatenate into one big hex string and uppercase.
    ///   4. Locate `4902` (positive response to Mode 09 PID 02).
    ///   5. Skip past `4902` + the 1-byte message count → hex-decode the rest
    ///      to ASCII, mapping non-printable bytes to space.
    ///   6. First 17-char run of valid VIN chars wins.
    static func parseVINResponse(_ response: String) -> String? {
        let lines = response
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(stripFrameIndex)
        let concatenated = lines.joined().uppercased()
        guard let headerRange = concatenated.range(of: "4902") else { return nil }
        // 4902 is 4 hex chars; skip 2 more for the message-count byte (typ. 01).
        let dataStart = concatenated.index(headerRange.upperBound, offsetBy: 2, limitedBy: concatenated.endIndex) ?? concatenated.endIndex
        let dataHex = String(concatenated[dataStart...])
        let ascii = hexToAscii(dataHex)
        return firstVINMatch(in: ascii)
    }

    /// Parses a Renault physical/UDS diagnostic Mode 21 PID 81 response into a 17-char VIN.
    private static func parseRenaultVINResponse(_ response: String) -> String? {
        let cleanHex = response
            .uppercased()
            .replacing(" ", with: "")
            .replacing("\n", with: "")
            .replacing("\r", with: "")
        guard cleanHex.contains("6181"), cleanHex.count >= 38 else {
            return nil
        }
        
        guard let range = cleanHex.range(of: "6181") else { return nil }
        let start = range.upperBound
        let dataHex = String(cleanHex[start...].prefix(34))
        guard dataHex.count == 34 else { return nil }
        
        let ascii = hexToAscii(dataHex)
        return firstVINMatch(in: ascii)
    }

    /// Drops a `<digit>:` prefix on lines like `0:4902014A` → `4902014A`.
    nonisolated private static func stripFrameIndex(_ line: String) -> String {
        guard let colonIdx = line.firstIndex(of: ":") else { return line }
        let prefix = line[..<colonIdx]
        // Frame indices are short single-digit (sometimes 2-digit) hex counters.
        guard prefix.count <= 2, prefix.allSatisfy({ $0.isHexDigit }) else { return line }
        return String(line[line.index(after: colonIdx)...])
    }

    private static func hexToAscii(_ hex: String) -> String {
        var out = ""
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard hex.distance(from: idx, to: next) == 2 else { break }
            let pair = String(hex[idx..<next])
            if let byte = UInt8(pair, radix: 16) {
                if byte >= 0x20 && byte < 0x7F {
                    out.append(Character(UnicodeScalar(byte)))
                } else {
                    out.append(" ")
                }
            }
            idx = next
        }
        return out
    }

    private static func firstVINMatch(in ascii: String) -> String? {
        // VIN: 17 chars, alphanumeric, no I/O/Q.
        let allowed: Set<Character> = Set("ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
        let chars = Array(ascii)
        guard chars.count >= 17 else { return nil }
        for start in 0...(chars.count - 17) {
            let slice = chars[start..<(start + 17)]
            if slice.allSatisfy({ allowed.contains($0) }) {
                return String(slice)
            }
        }
        return nil
    }



}
