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
            
            // Try standard CAN speeds: 500 kbps (modern) and 250 kbps (older Renault Megane II / Scenic II)
            for testSpeed in [500, 250] {
                if activeBus != nil { break }
                
                // 1a. Try 11-bit standard diagnostic ping on buses 0, 1, 2
                for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                    try? await panda.setCANSpeed(bus: testBus, kbps: testSpeed)
                    panda.bus = testBus
                    try? await panda.setTarget(txID: "7DF", rxID: "7E8")
                    if let response = try? await panda.sendDiagnosticRequest("0100", timeout: 1.0) {
                        let normalized = response.uppercased().replacing(" ", with: "")
                        if normalized.contains("4100") {
                            activeBus = testBus
                            activeSpeed = testSpeed
                            NSLog("[VINReader] Detected active 11-bit CAN bus: \(testBus) at \(testSpeed) kbps")
                            break
                        }
                    }
                }
                
                // 1b. Try 29-bit standard diagnostic ping on buses 0, 1, 2
                if activeBus == nil {
                    for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                        try? await panda.setCANSpeed(bus: testBus, kbps: testSpeed)
                        panda.bus = testBus
                        try? await panda.setTarget(txID: "18DB33F1", rxID: "18DAF110")
                        if let response = try? await panda.sendDiagnosticRequest("0100", timeout: 1.0) {
                            let normalized = response.uppercased().replacing(" ", with: "")
                            if normalized.contains("4100") {
                                activeBus = testBus
                                activeSpeed = testSpeed
                                NSLog("[VINReader] Detected active 29-bit CAN bus: \(testBus) at \(testSpeed) kbps")
                                break
                            }
                        }
                    }
                }
                
                // 1c. Try Renault-specific physical engine ping on buses 0, 1, 2 (KWP and UDS)
                if activeBus == nil {
                    for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                        try Task.checkCancellation()
                        try? await panda.setCANSpeed(bus: testBus, kbps: testSpeed)
                        panda.bus = testBus
                        try? await panda.setTarget(txID: "7E0", rxID: "7E8")
                        _ = try? await openDiagnosticSession(interface: panda)
                        
                        // Try KWP2000
                        if let response = try? await panda.sendDiagnosticRequest("2181", timeout: 1.0) {
                            let normalized = response.uppercased().replacing(" ", with: "")
                            if normalized.contains("6181") {
                                activeBus = testBus
                                activeSpeed = testSpeed
                                NSLog("[VINReader] Detected active Renault CAN bus (KWP2000): \(testBus) at \(testSpeed) kbps")
                                await closeDiagnosticSession(interface: panda)
                                break
                            }
                        }
                        
                        // Try UDS
                        if let response = try? await panda.sendDiagnosticRequest("22F190", timeout: 1.0) {
                            let normalized = response.uppercased().replacing(" ", with: "")
                            if normalized.contains("62F190") {
                                activeBus = testBus
                                activeSpeed = testSpeed
                                NSLog("[VINReader] Detected active Renault CAN bus (UDS): \(testBus) at \(testSpeed) kbps")
                                await closeDiagnosticSession(interface: panda)
                                break
                            }
                        }
                        
                        await closeDiagnosticSession(interface: panda)
                    }
                }
            }
            
            if let activeBus, let activeSpeed {
                panda.bus = activeBus
                // Set all buses to the detected active speed to ensure uniform speed config
                for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                    try? await panda.setCANSpeed(bus: testBus, kbps: activeSpeed)
                }
            } else {
                NSLog("[VINReader] No active CAN bus detected during 0100 probe, defaulting to Bus 0 at 500 kbps")
                panda.bus = 0
                for testBus in [UInt8(0), UInt8(1), UInt8(2)] {
                    try? await panda.setCANSpeed(bus: testBus, kbps: 500)
                }
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
            if error is CancellationError { throw error }
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
            if error is CancellationError { throw error }
            NSLog("[VINReader] Stage B (29-bit OBD2) failed/timed out: \(error)")
        }
        
        // Stage C1: Renault physical Injection ECU (7E0) UDS query (22F190)
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            _ = try await openDiagnosticSession(interface: interface)
            let response = try await interface.sendDiagnosticRequest("22F190", timeout: 3.0)
            if let vin = parseUDSVINResponse(response) {
                NSLog("[VINReader] Success reading Renault Engine UDS VIN: \(vin)")
                await closeDiagnosticSession(interface: interface)
                return vin
            }
            await closeDiagnosticSession(interface: interface)
        } catch {
            if error is CancellationError { throw error }
            NSLog("[VINReader] Stage C1 (Renault Engine UDS 22F190) failed/timed out: \(error)")
        }

        // Stage C2: Renault physical Injection ECU (7E0) KWP query (2181)
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            _ = try await openDiagnosticSession(interface: interface)
            let response = try await interface.sendDiagnosticRequest("2181", timeout: 3.0)
            if let vin = parseRenaultVINResponse(response) {
                NSLog("[VINReader] Success reading Renault Engine KWP VIN: \(vin)")
                await closeDiagnosticSession(interface: interface)
                return vin
            }
            await closeDiagnosticSession(interface: interface)
        } catch {
            if error is CancellationError { throw error }
            NSLog("[VINReader] Stage C2 (Renault Engine KWP 2181) failed/timed out: \(error)")
        }
        
        // Stage D1: Renault physical UCH (745) UDS query (22F190)
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "745", rxID: "765")
            _ = try await openDiagnosticSession(interface: interface)
            let response = try await interface.sendDiagnosticRequest("22F190", timeout: 3.0)
            if let vin = parseUDSVINResponse(response) {
                NSLog("[VINReader] Success reading Renault UCH UDS VIN: \(vin)")
                await closeDiagnosticSession(interface: interface)
                return vin
            }
            await closeDiagnosticSession(interface: interface)
        } catch {
            if error is CancellationError { throw error }
            NSLog("[VINReader] Stage D1 (Renault UCH UDS 22F190) failed/timed out: \(error)")
        }

        // Stage D2: Renault physical UCH (745) KWP query (2181)
        do {
            try Task.checkCancellation()
            try await interface.setTarget(txID: "745", rxID: "765")
            _ = try await openDiagnosticSession(interface: interface)
            let response = try await interface.sendDiagnosticRequest("2181", timeout: 3.0)
            if let vin = parseRenaultVINResponse(response) {
                NSLog("[VINReader] Success reading Renault UCH KWP VIN: \(vin)")
                await closeDiagnosticSession(interface: interface)
                return vin
            }
            await closeDiagnosticSession(interface: interface)
        } catch {
            if error is CancellationError { throw error }
            NSLog("[VINReader] Stage D2 (Renault UCH KWP 2181) failed/timed out: \(error)")
        }
        
        return nil
    }

    @discardableResult
    @MainActor
    private static func openDiagnosticSession(interface: VehicleInterface) async throws -> Bool {
        // 1. Tente la session Renault UDS 10C0 en premier (Clio IV, Megane III...)
        do {
            let res = try await interface.sendDiagnosticRequest("10C0", timeout: 1.5)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        // 2. Tente la session Renault KWP 1085 en deuxième (Scenic II, Megane II, Clio III...)
        do {
            let res = try await interface.sendDiagnosticRequest("1085", timeout: 1.5)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        // 3. Tente la session Renault KWP 1086 en troisième
        do {
            let res = try await interface.sendDiagnosticRequest("1086", timeout: 1.5)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        // 4. Repli sur la session étendue standard 1003
        do {
            let res = try await interface.sendDiagnosticRequest("1003", timeout: 1.5)
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
        _ = try? await interface.sendDiagnosticRequest("1001", timeout: 1.0)
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
