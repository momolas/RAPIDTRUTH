import Foundation
import Observation

enum DTCState: String, Sendable {
    case active = "Active"
    case stored = "Stored"
}

struct DTC: Identifiable, Equatable, Sendable {
    var id: String { "\(ecu)-\(code)" }
    let code: String
    let description: String?
    let state: DTCState
    let ecu: String
}

@MainActor
@Observable
final class DTCLoader {
    var dtcs: [DTC] = []
    var isScanning = false
    var isClearing = false
    var scanError: String?
    var currentEcuScanning: String?

    func scan(interface: VehicleInterface, profile: Profile) async {
        isScanning = true
        scanError = nil
        dtcs.removeAll()

        do {
            if profile.profileId.contains("generic") {
                self.dtcs = await scanGenericDTCs(interface: interface)
            } else {
                var allFound: [DTC] = []
                for (ecuName, ecuDef) in profile.ecus {
                    currentEcuScanning = ecuName
                    try await interface.setTarget(txID: ecuDef.requestHeader, rxID: nil)
                    
                    // Read DTC by Status (KWP2000 Renault specific)
                    let hexResponse = try await interface.sendDiagnosticRequest("17FF00", timeout: 4.0)
                    let ecuDTCs = parseRenaultDTCs(from: hexResponse, ecuName: ecuName)
                    allFound.append(contentsOf: ecuDTCs)
                }
                self.dtcs = allFound.sorted(by: { $0.code < $1.code })
            }
        } catch {
            scanError = error.localizedDescription
        }
        
        currentEcuScanning = nil
        isScanning = false
    }

    func clear(interface: VehicleInterface, profile: Profile) async {
        isClearing = true
        scanError = nil
        do {
            if profile.profileId.contains("generic") {
                try await interface.setTarget(txID: "7E0", rxID: nil)
                // Mode 04: Clear Diagnostic Trouble Codes
                _ = try await interface.sendDiagnosticRequest("04", timeout: 4.0)
                try? await Task.sleep(for: .milliseconds(500))
                dtcs.removeAll()
            } else {
                for (_, ecuDef) in profile.ecus {
                    try await interface.setTarget(txID: ecuDef.requestHeader, rxID: nil)
                    // Clear Diagnostic Information
                    _ = try await interface.sendDiagnosticRequest("14FF00", timeout: 4.0)
                    try? await Task.sleep(for: .milliseconds(500))
                }
                dtcs.removeAll()
            }
        } catch {
            scanError = "Clear failed: \(error.localizedDescription)"
        }
        isClearing = false
    }

    private func scanGenericDTCs(interface: VehicleInterface) async -> [DTC] {
        var results: [DTC] = []
        let modes: [(String, DTCState)] = [
            ("03", .active), // Confirmed codes
            ("07", .stored), // Pending codes
            ("0A", .stored)  // Permanent codes
        ]
        
        for (mode, state) in modes {
            do {
                try await interface.setTarget(txID: "7E0", rxID: nil)
                let response = try await interface.sendDiagnosticRequest(mode, timeout: 3.0)
                let codes = parseGenericDTCs(from: response)
                for code in codes {
                    let desc = DTCDescriptionProvider.shared.description(for: code)
                    results.append(DTC(code: code, description: desc, state: state, ecu: "engine"))
                }
            } catch {
                NSLog("[DTCLoader] Generic scan for mode \(mode) failed: \(error)")
            }
        }
        return results.sorted(by: { $0.code < $1.code })
    }

    private func parseGenericDTCs(from hex: String) -> [String] {
        var results: [String] = []
        let lines = hex.split(whereSeparator: \.isNewline).map { String($0) }
        var joinedPayload = ""
        
        for line in lines {
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
            if clean.isEmpty || clean.contains("NODATA") || clean.contains("ERROR") || clean.contains(">") { continue }
            
            var frameData = clean
            if let colonIdx = frameData.firstIndex(of: ":") {
                frameData = String(frameData[frameData.index(after: colonIdx)...])
            }
            if frameData.hasPrefix("7E8") {
                frameData.removeFirst(3)
            }
            joinedPayload += frameData
        }
        
        // Find positive response markers (43, 47, 4A)
        var payload = joinedPayload
        if let range = payload.range(of: "43") {
            payload = String(payload[range.upperBound...])
        } else if let range = payload.range(of: "47") {
            payload = String(payload[range.upperBound...])
        } else if let range = payload.range(of: "4A") {
            payload = String(payload[range.upperBound...])
        } else {
            return []
        }
        
        // Skip DTC count byte (2 characters)
        if payload.count >= 2 {
            payload.removeFirst(2)
        }
        
        let chars = Array(payload)
        var i = 0
        while i + 3 < chars.count {
            let hexCode = String(chars[i...i+3])
            if hexCode != "0000", let code = decodeSingleDTC(hexCode) {
                results.append(code)
            }
            i += 4
        }
        
        return results
    }

    private func parseRenaultDTCs(from hex: String, ecuName: String) -> [DTC] {
        var results: [DTC] = []
        
        let lines = hex.split(whereSeparator: \.isNewline).map { String($0) }
        var joinedPayload = ""
        
        for line in lines {
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
            if clean.isEmpty || clean.contains("NODATA") || clean.contains("ERROR") { continue }
            if clean.count <= 3 && Int(clean, radix: 16) != nil { continue }
            
            var frameData = clean
            if let colonIdx = frameData.firstIndex(of: ":") {
                frameData = String(frameData[frameData.index(after: colonIdx)...])
            }
            joinedPayload += frameData
        }
        
        if joinedPayload.hasPrefix("57") {
            joinedPayload.removeFirst(2) // Remove "57"
            
            // Second byte is NDTC (Number of DTCs)
            if joinedPayload.count >= 2 {
                joinedPayload.removeFirst(2)
                
                let chars = Array(joinedPayload)
                var i = 0
                // Each DTC is 3 bytes (6 hex characters): [High] [Low] [Status]
                while i + 5 < chars.count {
                    let hexCode = String(chars[i...i+3])
                    let hexStatus = String(chars[i+4...i+5])
                    
                    if let code = decodeSingleDTC(hexCode), code != "P0000" {
                        if let statusVal = UInt8(hexStatus, radix: 16) {
                            // Bit 2 (0x04) = Current Failure / Active
                            // Bit 1 (0x02) = Historical / Stored
                            let state: DTCState = (statusVal & 0x04) != 0 ? .active : .stored
                            let desc = DTCDescriptionProvider.shared.description(for: hexCode)
                            results.append(DTC(code: code, description: desc, state: state, ecu: ecuName))
                        }
                    }
                    i += 6
                }
            }
        }
        return results
    }

    private func decodeSingleDTC(_ hex: String) -> String? {
        guard hex.count == 4, let value = UInt16(hex, radix: 16) else { return nil }
        
        let highByte = UInt8((value >> 8) & 0xFF)
        let lowByte = UInt8(value & 0xFF)
        
        let typeMap = ["P", "C", "B", "U"]
        let typeIdx = Int((highByte >> 6) & 0b11)
        let type = typeMap[typeIdx]
        
        let digit1 = (highByte >> 4) & 0b11
        let digit2 = highByte & 0x0F
        let digit3 = (lowByte >> 4) & 0x0F
        let digit4 = lowByte & 0x0F
        
        return String(format: "%@%d%X%X%X", type, digit1, digit2, digit3, digit4)
    }
}
