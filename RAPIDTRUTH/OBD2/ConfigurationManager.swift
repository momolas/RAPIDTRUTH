import Foundation
import Observation

@MainActor
@Observable
final class ConfigurationManager {
    // TdB (Tableau de Bord)
    var dashboardLanguage: String = "FR" // "FR" or "EN"
    var seatbeltWarning: Bool = true
    var clockDisplay: Bool = true
    var consumptionUnit: String = "L/100" // "L/100" or "KM/L"
    var overspeedWarning: Bool = false
    var fuelType: String = "DSL" // "DSL" (Diesel) or "GSL" (Gasoline)
    var gearboxType: String = "BVM" // "BVM" (Manual) or "BVA" (Automatic)
    var voiceSynthesis: Bool = true
    var oilServiceInterval: String = "20K" // "15K", "20K", "30K"
    
    // UCH (Unité Centrale Habitacle)
    var autoLockDoors: Bool = true
    var autoRearWiper: Bool = true
    var followMeHome: Bool = false
    var oneTouchTurnSignal: Bool = true
    var deadlocking: Bool = false
    var tpmsEnabled: Bool = true
    var autoRainSensor: Bool = true
    var keylessGo: Bool = false
    var selectiveUnlocking: Bool = false
    
    // RadNav (Multimedia)
    var androidAuto: Bool = false
    var rearViewCamera: Bool = false
    
    // UPC (Unité Protection Commutation - Compartiment Moteur)
    var xenonHeadlights: Bool = false
    var drlEnabled: Bool = false
    var alternatorClass: String = "110A" // "110A" or "150A"
    var corneringLightsMode: Int = 0 // 0: NO_CORNERING_NO_AFS, 1: CORNERING_ON_NO_AFS, 2: NO_CORNERING_AFS_ON, 3: CORNERING_ON_AFS_ON
    var corneringSpeedThreshold: Int = 40 // Speed threshold in km/h
    
    // FPA (Frein de Parking Assisté)
    var coldClimateMode: Bool = false
    
    // AAS (Aide au Stationnement)
    var parkAssistVolume: Int = 3 // 0 (Désactivé), 2 (Faible), 3 (Moyen), 4 (Moyen Fort), 5 (Assez Fort), 6 (Fort), 7 (Très Fort)
    var parkAssistTone: Int = 3 // 0 (500Hz), 1 (666Hz), 2 (800Hz), 3 (1000Hz), 4 (2000Hz)
    var parkAssistInhibitionButton: Bool = true // disabled (false/0) or enabled (true/128)
    
    var isReading = false
    var isWriting = false
    var actionError: String?
    var showSuccessMessage = false
    private var successTimerTask: Task<Void, Never>?

    func readConfig(interface: VehicleInterface) async {
        isReading = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Read UCH config (txID 745)
            try await interface.setTarget(txID: "745", rxID: nil)
            try Task.checkCancellation()
            let uchRes = try await interface.sendDiagnosticRequest("222100", timeout: 4.0)
            try Task.checkCancellation()
            
            if uchRes.contains("62 21 00") {
                autoLockDoors = uchRes.contains("01")
                autoRearWiper = !uchRes.contains("NORW")
                followMeHome = uchRes.contains("FMH")
                oneTouchTurnSignal = !uchRes.contains("NOTS")
                deadlocking = uchRes.contains("DLK")
                tpmsEnabled = !uchRes.contains("NOTPMS")
                autoRainSensor = !uchRes.contains("NORS")
                keylessGo = uchRes.contains("KEYLESS")
                selectiveUnlocking = uchRes.contains("SELUN")
            }
            
            // Read TdB config (txID 743)
            try await interface.setTarget(txID: "743", rxID: nil)
            try Task.checkCancellation()
            let tdbRes = try await interface.sendDiagnosticRequest("222101", timeout: 4.0)
            try Task.checkCancellation()
            
            if tdbRes.contains("62 21 01") {
                dashboardLanguage = tdbRes.contains("EN") ? "EN" : "FR"
                seatbeltWarning = !tdbRes.contains("NOBEEP")
                clockDisplay = !tdbRes.contains("NOCLK")
                consumptionUnit = tdbRes.contains("KML") ? "KM/L" : "L/100"
                overspeedWarning = tdbRes.contains("120")
                fuelType = tdbRes.contains("GSL") ? "GSL" : "DSL"
                gearboxType = tdbRes.contains("BVA") ? "BVA" : "BVM"
                voiceSynthesis = !tdbRes.contains("NOSYN")
                oilServiceInterval = tdbRes.contains("15K") ? "15K" : (tdbRes.contains("30K") ? "30K" : "20K")
            }
            
            // Read RadNav config (txID 756)
            try await interface.setTarget(txID: "756", rxID: nil)
            try Task.checkCancellation()
            let radNavRes = try await interface.sendDiagnosticRequest("222102", timeout: 4.0)
            try Task.checkCancellation()
            
            if radNavRes.contains("62 21 02") {
                androidAuto = radNavRes.contains("AA")
                rearViewCamera = radNavRes.contains("RVC")
            }
            
            // Read UPC config (txID 7A2)
            try await interface.setTarget(txID: "7A2", rxID: nil)
            try Task.checkCancellation()
            if let upcRes = try? await interface.sendDiagnosticRequest("222103", timeout: 4.0), upcRes.contains("62 21 03") {
                xenonHeadlights = upcRes.contains("XENON")
                drlEnabled = upcRes.contains("DRL")
                alternatorClass = upcRes.contains("ALT150") ? "150A" : "110A"
            }
            try Task.checkCancellation()
            
            // Read Cornering Lights config from UPC (txID 7A2)
            if let corneringRes = try? await interface.sendDiagnosticRequest("223092", timeout: 4.0) {
                if let modeByte = parseHexByte(from: corneringRes, prefix: "62 30 92") ?? parseHexByte(from: corneringRes, prefix: "61 92") {
                    corneringLightsMode = modeByte
                }
            }
            try Task.checkCancellation()
            
            if let speedRes = try? await interface.sendDiagnosticRequest("224604", timeout: 4.0) {
                if let speedByte = parseHexByte(from: speedRes, prefix: "62 46 04") ?? parseHexByte(from: speedRes, prefix: "61 04") {
                    corneringSpeedThreshold = speedByte
                }
            }
            try Task.checkCancellation()
            
            // Read FPA config (txID 7A0)
            try await interface.setTarget(txID: "7A0", rxID: nil)
            try Task.checkCancellation()
            if let fpaRes = try? await interface.sendDiagnosticRequest("222104", timeout: 4.0), fpaRes.contains("62 21 04") {
                coldClimateMode = fpaRes.contains("COLD")
            }
            try Task.checkCancellation()
            
            // Read AAS config (txID 7A4)
            try await interface.setTarget(txID: "7A4", rxID: nil)
            try Task.checkCancellation()
            
            // Read Volume (222171)
            if let volRes = try? await interface.sendDiagnosticRequest("222171", timeout: 4.0) {
                if let volByte = parseHexByte(from: volRes, prefix: "62 21 71") ?? parseHexByte(from: volRes, prefix: "61 71") {
                    parkAssistVolume = volByte
                }
            }
            try Task.checkCancellation()
            
            // Read Tonalité (222172)
            if let toneRes = try? await interface.sendDiagnosticRequest("222172", timeout: 4.0) {
                if let toneByte = parseHexByte(from: toneRes, prefix: "62 21 72") ?? parseHexByte(from: toneRes, prefix: "61 72") {
                    parkAssistTone = toneByte
                }
            }
            try Task.checkCancellation()
            
            // Read Bouton d'Inhibition (2221E3)
            if let inhibRes = try? await interface.sendDiagnosticRequest("2221E3", timeout: 4.0) {
                if let inhibByte = parseHexByte(from: inhibRes, prefix: "62 21 E3") ?? parseHexByte(from: inhibRes, prefix: "61 E3") {
                    parkAssistInhibitionButton = (inhibByte == 128)
                }
            }
            
        } catch is CancellationError {
            // Clean exit on cooperative task cancellation
        } catch {
            actionError = "Failed to read configuration: \(error.localizedDescription)"
        }
        
        isReading = false
    }

    func writeConfig(interface: VehicleInterface) async {
        isWriting = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Write UCH (txID 745)
            try await interface.setTarget(txID: "745", rxID: nil)
            try Task.checkCancellation()
            let uchPayload1 = autoLockDoors ? "01" : "00"
            let uchPayload2 = autoRearWiper ? "" : "NORW"
            let uchPayload3 = followMeHome ? "FMH" : ""
            let uchPayload4 = oneTouchTurnSignal ? "" : "NOTS"
            let uchPayload5 = deadlocking ? "DLK" : ""
            let tpmsPayload = tpmsEnabled ? "TPMS" : "NOTPMS"
            let rainPayload = autoRainSensor ? "" : "NORS"
            let keylessPayload = keylessGo ? "KEYLESS" : ""
            let selunPayload = selectiveUnlocking ? "SELUN" : ""
            
            _ = try await interface.sendDiagnosticRequest("2E2100\(uchPayload1)\(uchPayload2)\(uchPayload3)\(uchPayload4)\(uchPayload5)\(tpmsPayload)\(rainPayload)\(keylessPayload)\(selunPayload)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write TdB (txID 743)
            try await interface.setTarget(txID: "743", rxID: nil)
            try Task.checkCancellation()
            let langPayload = dashboardLanguage == "EN" ? "EN" : "FR"
            let beepPayload = seatbeltWarning ? "BEEP" : "NOBEEP"
            let clkPayload = clockDisplay ? "CLK" : "NOCLK"
            let consPayload = consumptionUnit == "KM/L" ? "KML" : "L100"
            let overspeedPayload = overspeedWarning ? "120" : "000"
            let fuelPayload = fuelType == "GSL" ? "GSL" : "DSL"
            let gearboxPayload = gearboxType == "BVA" ? "BVA" : "BVM"
            let voicePayload = voiceSynthesis ? "SYN" : "NOSYN"
            let oilPayload = oilServiceInterval
            
            _ = try await interface.sendDiagnosticRequest("2E2101\(langPayload)\(beepPayload)\(clkPayload)\(consPayload)\(overspeedPayload)\(fuelPayload)\(gearboxPayload)\(voicePayload)\(oilPayload)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write RadNav (txID 756)
            try await interface.setTarget(txID: "756", rxID: nil)
            try Task.checkCancellation()
            let aaPayload = androidAuto ? "AA" : "NOAA"
            let rvcPayload = rearViewCamera ? "RVC" : "NORVC"
            _ = try await interface.sendDiagnosticRequest("2E2102\(aaPayload)\(rvcPayload)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write UPC (txID 7A2)
            try await interface.setTarget(txID: "7A2", rxID: nil)
            try Task.checkCancellation()
            let xenonPayload = xenonHeadlights ? "XENON" : "HALO"
            let drlPayload = drlEnabled ? "DRL" : "NODRL"
            let altPayload = alternatorClass == "150A" ? "ALT150" : "ALT110"
            _ = try? await interface.sendDiagnosticRequest("2E2103\(xenonPayload)\(drlPayload)\(altPayload)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write Cornering Lights config (txID 7A2)
            let corneringModeHex = String(format: "%02X", corneringLightsMode)
            _ = try? await interface.sendDiagnosticRequest("2E3092\(corneringModeHex)", timeout: 4.0)
            try Task.checkCancellation()
            
            let speedHex = String(format: "%02X", corneringSpeedThreshold)
            _ = try? await interface.sendDiagnosticRequest("2E4604\(speedHex)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write FPA (txID 7A0)
            try await interface.setTarget(txID: "7A0", rxID: nil)
            try Task.checkCancellation()
            let fpaPayload = coldClimateMode ? "COLD" : "STD"
            _ = try? await interface.sendDiagnosticRequest("2E2104\(fpaPayload)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write AAS (txID 7A4)
            try await interface.setTarget(txID: "7A4", rxID: nil)
            try Task.checkCancellation()
            
            // Write Volume (3BB1xx)
            let volHex = String(format: "%02X", parkAssistVolume)
            _ = try? await interface.sendDiagnosticRequest("3BB1\(volHex)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write Tonalité (3BC1xx)
            let toneHex = String(format: "%02X", parkAssistTone)
            _ = try? await interface.sendDiagnosticRequest("3BC1\(toneHex)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Write Bouton d'Inhibition (3BE3xx)
            let inhibHex = parkAssistInhibitionButton ? "80" : "00"
            _ = try? await interface.sendDiagnosticRequest("3BE3\(inhibHex)", timeout: 4.0)
            try Task.checkCancellation()
            
            // Show success for 3 seconds
            showSuccessMessage = true
            successTimerTask?.cancel()
            successTimerTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    showSuccessMessage = false
                }
            }
            
        } catch is CancellationError {
            // Clean exit on cooperative task cancellation
        } catch {
            actionError = "Failed to write configuration: \(error.localizedDescription)"
        }
        
        isWriting = false
    }
    
    private func parseHexByte(from response: String, prefix: String) -> Int? {
        let cleanResponse = response.replacingOccurrences(of: " ", with: "")
        let cleanPrefix = prefix.replacingOccurrences(of: " ", with: "")
        
        guard let range = cleanResponse.range(of: cleanPrefix) else { return nil }
        let remaining = cleanResponse[range.upperBound...]
        guard remaining.count >= 2 else { return nil }
        let byteString = String(remaining.prefix(2))
        return Int(byteString, radix: 16)
    }
}
