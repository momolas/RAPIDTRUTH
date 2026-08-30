import Foundation
import Observation
import SwiftVehicleProtocols

public enum DTCState: String, Sendable {
    case active = "Active"
    case stored = "Stored"
}

public struct DTC: Identifiable, Equatable, Sendable {
    public var id: String { "\(ecu)-\(rawHex)" }
    public let rawHex: String
    public let code: String
    public let dfCode: String?
    public let description: String?
    public let state: DTCState
    public let ecu: String
    public var freezeFrame: FreezeFrameData? = nil
}

@MainActor
@Observable
final class DTCLoader {
    var dtcs: [DTC] = []
    var isScanning = false
    var isClearing = false
    var isLoadingFreezeFrame = false
    var scanError: String?
    var currentEcuScanning: String?
    var lastNRCError: UDSNRCResponse?

    func scan(interface: VehicleInterface, profile: Profile) async {
        isScanning = true
        scanError = nil
        lastNRCError = nil
        dtcs.removeAll()

        do {
            if profile.profileId.contains("generic") {
                self.dtcs = await scanGenericDTCs(interface: interface)
            } else {
                var allFound: [DTC] = []
                for (ecuName, ecuDef) in profile.ecus {
                    currentEcuScanning = ecuName
                    try await interface.setTarget(txID: ecuDef.requestHeader, rxID: nil)
                    
                    // Read DTC by Status (KWP2000 Renault specific: 17 FF 00)
                    let hexResponse = try await interface.sendDiagnosticRequest("17FF00", timeout: 4.0)
                    if let nrc = UDSNRC.parse(from: hexResponse) {
                        NSLog("[DTCLoader] ECU \(ecuName) returned NRC 0x\(nrc.rawHexCode) (\(nrc.title))")
                    }
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
        lastNRCError = nil
        do {
            if profile.profileId.contains("generic") {
                try await interface.setTarget(txID: "7E0", rxID: nil)
                // Mode 04: Clear Diagnostic Trouble Codes
                let resp = try await interface.sendDiagnosticRequest("04", timeout: 4.0)
                if let nrc = UDSNRC.parse(from: resp) {
                    lastNRCError = nrc
                    scanError = "Effacement refusé : \(nrc.title) — \(nrc.actionAdvice)"
                } else {
                    try? await Task.sleep(for: .milliseconds(500))
                    dtcs.removeAll()
                }
            } else {
                for (ecuName, ecuDef) in profile.ecus {
                    try await interface.setTarget(txID: ecuDef.requestHeader, rxID: nil)
                    // Clear Diagnostic Information (14 FF 00)
                    let resp = try await interface.sendDiagnosticRequest("14FF00", timeout: 4.0)
                    if let nrc = UDSNRC.parse(from: resp) {
                        lastNRCError = nrc
                        scanError = "Effacement refusé sur \(ecuName) : \(nrc.title) — \(nrc.actionAdvice)"
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                }
                if scanError == nil {
                    dtcs.removeAll()
                }
            }
        } catch {
            scanError = "Clear failed: \(error.localizedDescription)"
        }
        isClearing = false
    }

    /// Extrait la trame gelée (Freeze Frame / Contexte d'apparition) pour un défaut spécifique
    func fetchFreezeFrame(interface: VehicleInterface, profile: Profile, dtcIndex: Int) async {
        guard dtcs.indices.contains(dtcIndex) else { return }
        let dtc = dtcs[dtcIndex]
        isLoadingFreezeFrame = true
        
        do {
            if profile.profileId.contains("generic") {
                let frame = await fetchGenericFreezeFrame(interface: interface, targetDTC: dtc.code)
                dtcs[dtcIndex].freezeFrame = frame
            } else {
                let ecuDef = profile.ecus[dtc.ecu]
                let reqHeader = ecuDef?.requestHeader ?? "7E0"
                try await interface.setTarget(txID: reqHeader, rxID: nil)
                
                // KWP2000 Service 18: Report Extended Data by DTC (Freeze Frame)
                let reqCmd = "18\(dtc.rawHex)00"
                let response = try await interface.sendDiagnosticRequest(reqCmd, timeout: 3.0)
                
                if let nrc = UDSNRC.parse(from: response) {
                    dtcs[dtcIndex].freezeFrame = FreezeFrameData(
                        triggerDTC: dtc.code,
                        additionalAttributes: ["Statut": "\(nrc.title) (0x\(nrc.rawHexCode))", "Conseil": nrc.actionAdvice]
                    )
                } else {
                    let decodedFrame = parseFreezeFrameResponse(response, dtcCode: dtc.code)
                    dtcs[dtcIndex].freezeFrame = decodedFrame
                }
            }
        } catch {
            dtcs[dtcIndex].freezeFrame = FreezeFrameData(
                triggerDTC: dtc.code,
                additionalAttributes: ["Erreur": error.localizedDescription]
            )
        }
        
        isLoadingFreezeFrame = false
    }

    private func fetchGenericFreezeFrame(interface: VehicleInterface, targetDTC: String) async -> FreezeFrameData {
        var rpm: Int? = nil
        var speed: Int? = nil
        var coolant: Int? = nil
        var load: Double? = nil
        var intakePress: Int? = nil
        var intakeTemp: Int? = nil
        var throttle: Double? = nil
        var voltage: Double? = nil
        var triggerDtcFound = targetDTC
        
        do {
            try await interface.setTarget(txID: "7E0", rxID: nil)
            
            // Mode 02 PID 02: DTC triggering freeze frame
            if let resp = try? await interface.sendDiagnosticRequest("020200", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "02"), bytes.count >= 2 {
                let hexDTC = String(format: "%02X%02X", bytes[0], bytes[1])
                if let decoded = decodeSingleDTC(hexDTC) {
                    triggerDtcFound = decoded
                }
            }
            
            // Mode 02 PID 0C: Engine RPM
            if let resp = try? await interface.sendDiagnosticRequest("020C00", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "0C"), bytes.count >= 2 {
                rpm = Int((Double(bytes[0]) * 256.0 + Double(bytes[1])) / 4.0)
            }
            
            // Mode 02 PID 0D: Vehicle Speed
            if let resp = try? await interface.sendDiagnosticRequest("020D00", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "0D"), !bytes.isEmpty {
                speed = Int(bytes[0])
            }
            
            // Mode 02 PID 05: Coolant Temp
            if let resp = try? await interface.sendDiagnosticRequest("020500", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "05"), !bytes.isEmpty {
                coolant = Int(bytes[0]) - 40
            }
            
            // Mode 02 PID 04: Calculated Engine Load
            if let resp = try? await interface.sendDiagnosticRequest("020400", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "04"), !bytes.isEmpty {
                load = (Double(bytes[0]) / 255.0) * 100.0
            }
            
            // Mode 02 PID 0B: Intake Manifold Absolute Pressure
            if let resp = try? await interface.sendDiagnosticRequest("020B00", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "0B"), !bytes.isEmpty {
                intakePress = Int(bytes[0])
            }
            
            // Mode 02 PID 0F: Intake Air Temp
            if let resp = try? await interface.sendDiagnosticRequest("020F00", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "0F"), !bytes.isEmpty {
                intakeTemp = Int(bytes[0]) - 40
            }
            
            // Mode 02 PID 11: Throttle Position
            if let resp = try? await interface.sendDiagnosticRequest("021100", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "11"), !bytes.isEmpty {
                throttle = (Double(bytes[0]) / 255.0) * 100.0
            }
            
            // Mode 02 PID 42: Control Module Voltage
            if let resp = try? await interface.sendDiagnosticRequest("024200", timeout: 2.0),
               let bytes = extractMode02Bytes(resp, pid: "42"), bytes.count >= 2 {
                voltage = (Double(bytes[0]) * 256.0 + Double(bytes[1])) / 1000.0
            }
        } catch {
            NSLog("[DTCLoader] Error fetching generic freeze frame: \(error)")
        }
        
        return FreezeFrameData(
            triggerDTC: triggerDtcFound,
            timestampKm: nil,
            rpm: rpm,
            vehicleSpeed: speed,
            coolantTemp: coolant,
            engineLoad: load,
            intakePressureKPa: intakePress,
            intakeAirTemp: intakeTemp,
            batteryVoltage: voltage,
            throttlePosition: throttle,
            rawHex: "MODE02",
            additionalAttributes: [:]
        )
    }

    private func extractMode02Bytes(_ response: String, pid: String) -> [UInt8]? {
        let clean = response.uppercased().replacing(" ", with: "").replacing("\n", with: "").replacing("\r", with: "")
        let prefix = "42" + pid.uppercased()
        guard let range = clean.range(of: prefix) else { return nil }
        let after = String(clean[range.upperBound...])
        // Skip frame count (00) if present
        let payload = after.hasPrefix("00") ? String(after.dropFirst(2)) : after
        return HexParsing.bytes(payload)
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
                for (hexCode, stdCode) in codes {
                    let desc = DTCDescriptionProvider.shared.description(for: hexCode)
                    let dfCode = formatRenaultDFCode(hexCode)
                    results.append(DTC(rawHex: hexCode, code: stdCode, dfCode: dfCode, description: desc, state: state, ecu: "engine"))
                }
            } catch {
                NSLog("[DTCLoader] Generic scan for mode \(mode) failed: \(error)")
            }
        }
        return results.sorted(by: { $0.code < $1.code })
    }

    private func parseGenericDTCs(from hex: String) -> [(String, String)] {
        var results: [(String, String)] = []
        let lines = hex.split(whereSeparator: \.isNewline).map { String($0) }
        var joinedPayload = ""
        
        for line in lines {
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines).replacing(" ", with: "")
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
        
        if payload.count >= 2 {
            payload.removeFirst(2)
        }
        
        let chars = Array(payload)
        var i = 0
        while i + 3 < chars.count {
            let hexCode = String(chars[i...i+3])
            if hexCode != "0000", let code = decodeSingleDTC(hexCode) {
                results.append((hexCode, code))
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
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines).replacing(" ", with: "")
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
            
            if joinedPayload.count >= 2 {
                joinedPayload.removeFirst(2)
                
                let chars = Array(joinedPayload)
                var i = 0
                while i + 5 < chars.count {
                    let hexCode = String(chars[i...i+3])
                    let hexStatus = String(chars[i+4...i+5])
                    
                    if let code = decodeSingleDTC(hexCode), code != "P0000" {
                        if let statusVal = UInt8(hexStatus, radix: 16) {
                            let state: DTCState = (statusVal & 0x04) != 0 ? .active : .stored
                            let desc = DTCDescriptionProvider.shared.description(for: hexCode)
                            let dfCode = formatRenaultDFCode(hexCode)
                            results.append(DTC(rawHex: hexCode, code: code, dfCode: dfCode, description: desc, state: state, ecu: ecuName))
                        }
                    }
                    i += 6
                }
            }
        }
        return results
    }

    private func formatRenaultDFCode(_ hexCode: String) -> String {
        if let val = Int(hexCode, radix: 16) {
            return String(format: "DF%03d", val % 1000)
        }
        return "DF" + hexCode.suffix(3)
    }

    public func parseFreezeFrameResponse(_ hex: String, dtcCode: String) -> FreezeFrameData {
        let clean = hex.replacing(" ", with: "").uppercased()
        guard clean.contains("58"), clean.count >= 16 else {
            return FreezeFrameData(triggerDTC: dtcCode, additionalAttributes: ["Statut": "Trame gelée non enregistrée"])
        }
        
        var kmVal: Int? = nil
        var rpmVal: Int? = nil
        var tempVal: Int? = nil
        var speedVal: Int? = nil
        let extra: [String: String] = [:]
        
        let chars = Array(clean)
        if chars.count >= 20 {
            let byte1 = UInt32(String(chars[10...11]), radix: 16) ?? 0
            let byte2 = UInt32(String(chars[12...13]), radix: 16) ?? 0
            let byte3 = UInt32(String(chars[14...15]), radix: 16) ?? 0
            let km = Int((byte1 << 16) | (byte2 << 8) | byte3)
            if km > 0 && km < 1_000_000 {
                kmVal = km
            }
        }
        
        if chars.count >= 24 {
            let rpmByte1 = Double(UInt8(String(chars[16...17]), radix: 16) ?? 0)
            let rpmByte2 = Double(UInt8(String(chars[18...19]), radix: 16) ?? 0)
            let rpm = Int((rpmByte1 * 256.0 + rpmByte2) / 4.0)
            if rpm > 0 && rpm < 8000 {
                rpmVal = rpm
            }
        }
        
        if chars.count >= 28 {
            let tempByte = Int(UInt8(String(chars[20...21]), radix: 16) ?? 0) - 40
            if tempByte >= -40 && tempByte <= 150 {
                tempVal = tempByte
            }
            
            let sByte = Int(UInt8(String(chars[22...23]), radix: 16) ?? 0)
            speedVal = sByte
        }
        
        return FreezeFrameData(
            triggerDTC: dtcCode,
            timestampKm: kmVal,
            rpm: rpmVal,
            vehicleSpeed: speedVal,
            coolantTemp: tempVal,
            rawHex: clean,
            additionalAttributes: extra
        )
    }

    public func decodeSingleDTC(_ hex: String) -> String? {
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
