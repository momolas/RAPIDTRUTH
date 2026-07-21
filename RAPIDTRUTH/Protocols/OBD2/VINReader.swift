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
            var activeSpeed: Int? = nil
            
            // KWP2000 & OBD2 on Scenic II / Modus platform operates at 500 kbps (Engine/ABS) or 250 kbps (Diag/UCH)
            for testSpeed in [500, 250] {
                if activeBus != nil { break }
                
                for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                    try Task.checkCancellation()
                    try? await panda.setCANSpeed(bus: testBus, kbps: testSpeed)
                    panda.bus = testBus
                    
                    // Probe 1: Standard OBD2 Broadcast ping (0x7DF -> 0x7E8)
                    try? await panda.setTarget(txID: "7DF", rxID: "7E8")
                    if let resp = try? await panda.sendDiagnosticRequest("0100", timeout: 0.35) {
                        let norm = resp.uppercased().replacing(" ", with: "")
                        if !norm.isEmpty && !norm.contains("TIMEOUT") {
                            activeBus = testBus
                            activeSpeed = testSpeed
                            AppLogger.shared.log("Detected active OBD2 Broadcast CAN bus: \(testBus) at \(testSpeed) kbps", level: .info)
                            break
                        }
                    }
                    
                    // Probe 2: Renault Engine physical ping (0x7E0 -> 0x7E8)
                    try? await panda.setTarget(txID: "7E0", rxID: "7E8")
                    if let resp = try? await panda.sendDiagnosticRequest("2181", timeout: 0.35) {
                        let norm = resp.uppercased().replacing(" ", with: "")
                        if !norm.isEmpty && !norm.contains("TIMEOUT") {
                            activeBus = testBus
                            activeSpeed = testSpeed
                            AppLogger.shared.log("Detected active Renault Engine CAN bus: \(testBus) at \(testSpeed) kbps", level: .info)
                            break
                        }
                    }
                    
                    // Probe 3: Renault UCH physical ping (0x744 -> 0x764)
                    try? await panda.setTarget(txID: "744", rxID: "764")
                    if let resp = try? await panda.sendDiagnosticRequest("2181", timeout: 0.35) {
                        let norm = resp.uppercased().replacing(" ", with: "")
                        if !norm.isEmpty && !norm.contains("TIMEOUT") {
                            activeBus = testBus
                            activeSpeed = testSpeed
                            AppLogger.shared.log("Detected active Renault UCH CAN bus: \(testBus) at \(testSpeed) kbps", level: .info)
                            break
                        }
                    }
                }
            }
            
            if let activeBus, let activeSpeed {
                panda.bus = activeBus
                for b in [UInt8(0), UInt8(1), UInt8(2)] {
                    try? await panda.setCANSpeed(bus: b, kbps: activeSpeed)
                }
            } else {
                AppLogger.shared.log("No active CAN bus detected during probe, defaulting to Bus 0 at 250 kbps", level: .warning)
                panda.bus = 0
                for b in [UInt8(0), UInt8(1), UInt8(2)] {
                    try? await panda.setCANSpeed(bus: b, kbps: 250)
                }
            }
        }
        
        // 2. Perform VIN discovery across Standard OBD2, UDS, and Renault KWP2000
        
        // Stage A: Standard OBD2 Mode 09 PID 02 (Broadcast 0x7DF -> 0x7E8)
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7DF", rxID: "7E8")
            let response = try await interface.sendDiagnosticRequest("0902", timeout: 2.0)
            if let vin = parseVINResponse(response) {
                AppLogger.shared.log("Success reading Standard OBD2 VIN: \(vin)", level: .info)
                return vin
            }
        } catch {
            if error is CancellationError { throw error }
        }

        // Stage B: Standard UDS Read DID F190 (Engine 0x7E0 -> 0x7E8)
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            let response = try await interface.sendDiagnosticRequest("22F190", timeout: 2.0)
            if let vin = parseUDSVINResponse(response) {
                AppLogger.shared.log("Success reading UDS Engine VIN: \(vin)", level: .info)
                return vin
            }
        } catch {
            if error is CancellationError { throw error }
        }

        // Stage C: Renault Physical Injection ECU (0x7E0 -> 0x7E8) KWP2000
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            _ = try? await openDiagnosticSession(interface: interface)
            
            for lidCmd in ["2181", "2180", "2182"] {
                if let response = try? await interface.sendDiagnosticRequest(lidCmd, timeout: 1.5),
                   let vin = parseRenaultVINResponse(response) {
                    AppLogger.shared.log("Success reading Renault Engine KWP VIN (\(lidCmd)): \(vin)", level: .info)
                    await closeDiagnosticSession(interface: interface)
                    return vin
                }
            }
            await closeDiagnosticSession(interface: interface)
        } catch {
            if error is CancellationError { throw error }
            AppLogger.shared.log("Stage C (Renault Engine KWP) failed/timed out: \(error.localizedDescription)", level: .error)
        }

        // Stage D: Renault Physical UCH (0x744 -> 0x764) KWP2000
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "744", rxID: "764")
            _ = try? await openDiagnosticSession(interface: interface)
            
            for lidCmd in ["2181", "2180", "2182"] {
                if let response = try? await interface.sendDiagnosticRequest(lidCmd, timeout: 1.5),
                   let vin = parseRenaultVINResponse(response) {
                    AppLogger.shared.log("Success reading Renault UCH KWP VIN (\(lidCmd)): \(vin)", level: .info)
                    await closeDiagnosticSession(interface: interface)
                    return vin
                }
            }
            await closeDiagnosticSession(interface: interface)
        } catch {
            if error is CancellationError { throw error }
            AppLogger.shared.log("Stage D (Renault UCH KWP) failed/timed out: \(error.localizedDescription)", level: .error)
        }
        
        return nil
    }

    @discardableResult
    @MainActor
    private static func openDiagnosticSession(interface: VehicleInterface) async throws -> Bool {
        // 1. Tente la session Renault KWP 1085 en premier (Scenic II, Megane II, Clio III...)
        do {
            let res = try await interface.sendDiagnosticRequest("1085", timeout: 1.5)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        // 2. Tente la session Renault KWP 1086 en deuxième
        do {
            let res = try await interface.sendDiagnosticRequest("1086", timeout: 1.5)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        return false
    }

    @MainActor
    private static func closeDiagnosticSession(interface: VehicleInterface) async {
        _ = try? await interface.sendDiagnosticRequest("1081", timeout: 1.0)
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
    /// Parses a standard UDS diagnostic Mode 22 DID F190 response into a 17-char VIN.
    private static func parseUDSVINResponse(_ response: String) -> String? {
        let lines = response
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(stripFrameIndex)
        let concatenated = lines.joined().uppercased()
        
        guard concatenated.contains("62F190") else {
            return nil
        }
        
        guard let range = concatenated.range(of: "62F190") else { return nil }
        let start = range.upperBound
        let dataHex = String(concatenated[start...].prefix(34))
        guard dataHex.count == 34 else { return nil }
        
        let ascii = hexToAscii(dataHex)
        return firstVINMatch(in: ascii)
    }

    private static func parseRenaultVINResponse(_ response: String) -> String? {
        let lines = response
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(stripFrameIndex)
        let concatenated = lines.joined().uppercased()
        
        guard concatenated.contains("6181"), concatenated.count >= 38 else {
            return nil
        }
        
        guard let range = concatenated.range(of: "6181") else { return nil }
        let start = range.upperBound
        let dataHex = String(concatenated[start...].prefix(34))
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
