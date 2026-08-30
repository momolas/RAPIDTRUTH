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
    public var statusByte: UInt8? = nil
    public var statusMask: DTCStatusMask? = nil
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
                    
                    // Read DTC by Status (KWP2000 Renault specific: 17 FF 00 ou UDS 19 02 FF)
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
                        additionalAttributes: ["Erreur NRC": "\(nrc.title) (\(nrc.actionAdvice))"]
                    )
                } else {
                    let frame = parseFreezeFrameResponse(response, dtcCode: dtc.code)
                    dtcs[dtcIndex].freezeFrame = frame
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
        var extra: [String: String] = [:]
        var rpmVal: Int? = nil
        var speedVal: Int? = nil
        var tempVal: Int? = nil

        try? await interface.setTarget(txID: "7E0", rxID: nil)
        
        // Mode 02 PID 02: DTC that caused freeze frame
        if let resp = try? await interface.sendDiagnosticRequest("020200", timeout: 2.0) {
            let clean = resp.replacingOccurrences(of: " ", with: "")
            if clean.count >= 8 {
                let hexCode = String(clean.dropFirst(4).prefix(4))
                extra["DTC Déclencheur"] = DTCDecoder.decodeSingleDTC(hexCode) ?? hexCode
            }
        }
        
        // Mode 02 PID 0C: Engine RPM at freeze frame
        if let resp = try? await interface.sendDiagnosticRequest("020C00", timeout: 2.0) {
            let clean = resp.replacingOccurrences(of: " ", with: "")
            if clean.count >= 8 {
                let a = Double(UInt8(String(clean.dropFirst(4).prefix(2)), radix: 16) ?? 0)
                let b = Double(UInt8(String(clean.dropFirst(6).prefix(2)), radix: 16) ?? 0)
                rpmVal = Int((a * 256.0 + b) / 4.0)
            }
        }
        
        // Mode 02 PID 0D: Vehicle Speed at freeze frame
        if let resp = try? await interface.sendDiagnosticRequest("020D00", timeout: 2.0) {
            let clean = resp.replacingOccurrences(of: " ", with: "")
            if clean.count >= 6 {
                speedVal = Int(UInt8(String(clean.dropFirst(4).prefix(2)), radix: 16) ?? 0)
            }
        }
        
        // Mode 02 PID 05: Coolant Temp at freeze frame
        if let resp = try? await interface.sendDiagnosticRequest("020500", timeout: 2.0) {
            let clean = resp.replacingOccurrences(of: " ", with: "")
            if clean.count >= 6 {
                tempVal = Int(UInt8(String(clean.dropFirst(4).prefix(2)), radix: 16) ?? 0) - 40
            }
        }
        
        return FreezeFrameData(
            triggerDTC: targetDTC,
            rpm: rpmVal,
            vehicleSpeed: speedVal,
            coolantTemp: tempVal,
            additionalAttributes: extra
        )
    }

    private func scanGenericDTCs(interface: VehicleInterface) async -> [DTC] {
        var results: [DTC] = []
        let modes: [(String, DTCState)] = [
            ("03", .active), // Confirmed DTCs
            ("07", .stored), // Pending DTCs
            ("0A", .stored)  // Permanent DTCs
        ]

        for (mode, state) in modes {
            do {
                try await interface.setTarget(txID: "7E0", rxID: nil)
                let response = try await interface.sendDiagnosticRequest(mode, timeout: 3.0)
                let decoded = DTCDecoder.decodeDTCsWithStatus(from: response)
                for item in decoded {
                    let desc = DTCDescriptionProvider.shared.description(for: item.code)
                    let mask: DTCStatusMask = item.statusMask ?? (state == .active ? [.confirmedDTC, .testFailed] : [.pendingDTC])
                    results.append(DTC(
                        rawHex: item.code,
                        code: item.code,
                        dfCode: nil,
                        description: desc,
                        state: state,
                        ecu: "engine",
                        statusByte: item.statusByte,
                        statusMask: mask
                    ))
                }
            } catch {
                NSLog("[DTCLoader] Generic scan for mode \(mode) failed: \(error)")
            }
        }
        return results.sorted(by: { $0.code < $1.code })
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
            
            if joinedPayload.count >= 2 {
                joinedPayload.removeFirst(2)
                
                let chars = Array(joinedPayload)
                var i = 0
                while i + 5 < chars.count {
                    let hexCode = String(chars[i...i+3])
                    let hexStatus = String(chars[i+4...i+5])
                    
                    if let code = DTCDecoder.decodeSingleDTC(hexCode), code != "P0000" {
                        let statusVal = UInt8(hexStatus, radix: 16)
                        let mask = statusVal.map { DTCStatusMask(rawValue: $0) }
                        let state: DTCState = (statusVal ?? 0 & 0x04) != 0 ? .active : .stored
                        let desc = DTCDescriptionProvider.shared.description(for: hexCode)
                        let dfCode = formatRenaultDFCode(hexCode)
                        results.append(DTC(
                            rawHex: hexCode,
                            code: code,
                            dfCode: dfCode,
                            description: desc,
                            state: state,
                            ecu: ecuName,
                            statusByte: statusVal,
                            statusMask: mask
                        ))
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
        let clean = hex.replacingOccurrences(of: " ", with: "").uppercased()
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
        DTCDecoder.decodeSingleDTC(hex)
    }
}
