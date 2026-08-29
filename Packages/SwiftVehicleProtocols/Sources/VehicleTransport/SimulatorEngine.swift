import Foundation
import VehicleCore

public actor SimulatorEngine: VehicleInterface {
    private var currentTx: String = "7E0"
    private var currentRx: String = "7E8"

    public init() {}

    public func setTarget(txID: String, rxID: String?) async throws {
        self.currentTx = txID
        if let rxID {
            self.currentRx = rxID
        } else {
            let txVal = UInt32(txID, radix: 16) ?? 0x7E0
            self.currentRx = String(format: "%X", txVal + 8)
        }
    }

    public func sendRawCAN(id: UInt32, data: Data, bus: UInt8) async throws {
        // Mock sending raw frame
    }

    public func sendDiagnosticRequest(_ requestHex: String, timeout: TimeInterval = 2.0) async throws -> String {
        let clean = requestHex.replacingOccurrences(of: " ", with: "").uppercased()

        // 1. Session request
        if clean.hasPrefix("10") {
            return "50" + clean.dropFirst(2) + "003201F4"
        }

        // 2. Read Local Identifier (21 XX)
        if clean.hasPrefix("21") {
            let lid = String(clean.dropFirst(2).prefix(2))
            if lid == "00" {
                return "61 00 01 00 00 00 00 00" // UCH config mock
            } else if lid == "01" {
                return "61 01 00 01 01 00 00 00" // TdB config mock
            } else if lid == "0C" || lid == "A0" {
                return "61 A0 0B B8" // 750 RPM
            }
            return "61" + lid + "0000"
        }

        // 3. Write Local Identifier (3B XX)
        if clean.hasPrefix("3B") {
            let lid = String(clean.dropFirst(2).prefix(2))
            return "7B" + lid
        }

        // 4. Routine Control / Actuators (30 / 31)
        if clean.hasPrefix("30") || clean.hasPrefix("31") {
            return "7101"
        }

        // 5. OBD-II Mode 01
        if clean.hasPrefix("01") {
            let pid = String(clean.dropFirst(2).prefix(2))
            if pid == "0C" {
                return "41 0C 0B B8" // 750 RPM
            } else if pid == "0D" {
                return "41 0D 32" // 50 km/h
            } else if pid == "05" {
                return "41 05 78" // 80°C
            }
            return "41" + pid + "00"
        }

        // Default positive response
        return "60" + clean
    }
}
