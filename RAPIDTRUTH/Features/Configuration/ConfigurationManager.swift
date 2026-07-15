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
            // Read UCH config (txID 745) using KWP2000 Read Local Identifier (21 00)
            try await interface.setTarget(txID: "745", rxID: nil)
            try Task.checkCancellation()
            let uchRes = try await interface.sendDiagnosticRequest("2100", timeout: 4.0)
            try Task.checkCancellation()
            
            if uchRes.contains("6100") || uchRes.contains("61 00") {
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
            
            // Read TdB config (txID 743) using KWP2000 (21 01)
            try await interface.setTarget(txID: "743", rxID: nil)
            try Task.checkCancellation()
            let tdbRes = try await interface.sendDiagnosticRequest("2101", timeout: 4.0)
            try Task.checkCancellation()
            
            if tdbRes.contains("6101") || tdbRes.contains("61 01") {
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
            
            // Read RadNav config (txID 756) using KWP2000 (21 02)
            try await interface.setTarget(txID: "756", rxID: nil)
            try Task.checkCancellation()
            let radNavRes = try await interface.sendDiagnosticRequest("2102", timeout: 4.0)
            try Task.checkCancellation()
            
            if radNavRes.contains("6102") || radNavRes.contains("61 02") {
                androidAuto = radNavRes.contains("AA")
                rearViewCamera = radNavRes.contains("RVC")
            }
            
            // Read UPC config (txID 7A2) using KWP2000 (21 03)
            try await interface.setTarget(txID: "7A2", rxID: nil)
            try Task.checkCancellation()
            if let upcRes = try? await interface.sendDiagnosticRequest("2103", timeout: 4.0), upcRes.contains("6103") || upcRes.contains("61 03") {
                xenonHeadlights = upcRes.contains("XENON")
                drlEnabled = upcRes.contains("DRL")
                alternatorClass = upcRes.contains("ALT150") ? "150A" : "110A"
            }
            try Task.checkCancellation()
            
            // Read Cornering Lights config from UPC (txID 7A2) using KWP2000 (21 92)
            if let corneringRes = try? await interface.sendDiagnosticRequest("2192", timeout: 4.0) {
                if let modeByte = parseHexByte(from: corneringRes, prefix: "61 92") ?? parseHexByte(from: corneringRes, prefix: "6192") {
                    corneringLightsMode = modeByte
                }
            }
            try Task.checkCancellation()
            
            // Read Cornering Speed Threshold from UPC (txID 7A2) using KWP2000 (21 04)
            if let speedRes = try? await interface.sendDiagnosticRequest("2104", timeout: 4.0) {
                if let speedByte = parseHexByte(from: speedRes, prefix: "61 04") ?? parseHexByte(from: speedRes, prefix: "6104") {
                    corneringSpeedThreshold = speedByte
                }
            }
            try Task.checkCancellation()
            
            // Read FPA config (txID 7A0) using KWP2000 (21 04)
            try await interface.setTarget(txID: "7A0", rxID: nil)
            try Task.checkCancellation()
            if let fpaRes = try? await interface.sendDiagnosticRequest("2104", timeout: 4.0), fpaRes.contains("6104") || fpaRes.contains("61 04") {
                coldClimateMode = fpaRes.contains("COLD")
            }
            try Task.checkCancellation()
            
            // Read AAS config (txID 7A4) using KWP2000 (21 71, 21 72, 21 E3)
            try await interface.setTarget(txID: "7A4", rxID: nil)
            try Task.checkCancellation()
            
            if let volRes = try? await interface.sendDiagnosticRequest("2171", timeout: 4.0) {
                if let volByte = parseHexByte(from: volRes, prefix: "61 71") ?? parseHexByte(from: volRes, prefix: "6171") {
                    parkAssistVolume = volByte
                }
            }
            
            if let toneRes = try? await interface.sendDiagnosticRequest("2172", timeout: 4.0) {
                if let toneByte = parseHexByte(from: toneRes, prefix: "61 72") ?? parseHexByte(from: toneRes, prefix: "6172") {
                    parkAssistTone = toneByte
                }
            }
            
            if let inhibRes = try? await interface.sendDiagnosticRequest("21E3", timeout: 4.0) {
                if let inhibByte = parseHexByte(from: inhibRes, prefix: "61 E3") ?? parseHexByte(from: inhibRes, prefix: "61E3") {
                    parkAssistInhibitionButton = inhibByte == 0x80
                }
            }
            
        } catch {
            actionError = "Erreur de lecture : \(error.localizedDescription)"
        }
        
        isReading = false
    }

    func writeConfig(interface: VehicleInterface) async {
        isWriting = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Sécurité : Vérifier l'immobilisation
            try await verifyVehicleImmobile(interface: interface)
            try Task.checkCancellation()
            
            // 1. Écriture UCH (txID 745) using KWP2000 Write Local Identifier (3B 00)
            try await interface.setTarget(txID: "745", rxID: nil)
            await ensureExtendedSession(interface: interface)
            try? await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .renaultStandard, mask: "5678")
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
            
            let uchRes = try await interface.sendDiagnosticRequest("3B00\(uchPayload1)\(uchPayload2)\(uchPayload3)\(uchPayload4)\(uchPayload5)\(tpmsPayload)\(rainPayload)\(keylessPayload)\(selunPayload)", timeout: 4.0)
            try checkDiagnosticResponse(uchRes, forService: "3B")
            try Task.checkCancellation()
            
            // 2. Écriture TdB (txID 743) using KWP2000 (3B 01)
            try await interface.setTarget(txID: "743", rxID: nil)
            await ensureExtendedSession(interface: interface)
            try? await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .renaultStandard, mask: "ABCD")
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
            
            let tdbRes = try await interface.sendDiagnosticRequest("3B01\(langPayload)\(beepPayload)\(clkPayload)\(consPayload)\(overspeedPayload)\(fuelPayload)\(gearboxPayload)\(voicePayload)\(oilPayload)", timeout: 4.0)
            try checkDiagnosticResponse(tdbRes, forService: "3B")
            try Task.checkCancellation()
            
            // 3. Écriture RadNav (txID 756) using KWP2000 (3B 02)
            try await interface.setTarget(txID: "756", rxID: nil)
            await ensureExtendedSession(interface: interface)
            try? await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .renaultStandard, mask: "8888")
            try Task.checkCancellation()
            
            let aaPayload = androidAuto ? "AA" : "NOAA"
            let rvcPayload = rearViewCamera ? "RVC" : "NORVC"
            let radNavRes = try await interface.sendDiagnosticRequest("3B02\(aaPayload)\(rvcPayload)", timeout: 4.0)
            try checkDiagnosticResponse(radNavRes, forService: "3B")
            try Task.checkCancellation()
            
            // 4. Écriture UPC (txID 7A2) using KWP2000 (3B 03)
            try await interface.setTarget(txID: "7A2", rxID: nil)
            await ensureExtendedSession(interface: interface)
            try? await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .renaultStandard, mask: "1234")
            try Task.checkCancellation()
            
            let xenonPayload = xenonHeadlights ? "XENON" : "HALO"
            let drlPayload = drlEnabled ? "DRL" : "NODRL"
            let altPayload = alternatorClass == "150A" ? "ALT150" : "ALT110"
            let upcRes = try await interface.sendDiagnosticRequest("3B03\(xenonPayload)\(drlPayload)\(altPayload)", timeout: 4.0)
            try checkDiagnosticResponse(upcRes, forService: "3B")
            try Task.checkCancellation()
            
            // 5. Écriture Cornering Lights Mode (txID 7A2) using KWP2000 (3B 92)
            let corneringModeHex = String(format: "%02X", corneringLightsMode)
            let corneringRes = try await interface.sendDiagnosticRequest("3B92\(corneringModeHex)", timeout: 4.0)
            try checkDiagnosticResponse(corneringRes, forService: "3B")
            try Task.checkCancellation()
            
            // 6. Écriture Seuil Vitesse Cornering (txID 7A2) using KWP2000 (3B 04)
            let speedHex = String(format: "%02X", corneringSpeedThreshold)
            let speedRes = try await interface.sendDiagnosticRequest("3B04\(speedHex)", timeout: 4.0)
            try checkDiagnosticResponse(speedRes, forService: "3B")
            try Task.checkCancellation()
            
            // 7. Écriture FPA (txID 7A0) using KWP2000 (3B 04)
            try await interface.setTarget(txID: "7A0", rxID: nil)
            await ensureExtendedSession(interface: interface)
            try? await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .xorStatique, mask: "FF")
            try Task.checkCancellation()
            
            let fpaPayload = coldClimateMode ? "COLD" : "STD"
            let fpaRes = try await interface.sendDiagnosticRequest("3B04\(fpaPayload)", timeout: 4.0)
            try checkDiagnosticResponse(fpaRes, forService: "3B")
            try Task.checkCancellation()
            
            // 8. Écriture AAS (txID 7A4)
            try await interface.setTarget(txID: "7A4", rxID: nil)
            await ensureExtendedSession(interface: interface)
            try? await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .xorStatique, mask: "00")
            try Task.checkCancellation()
            
            // Volume (3BB1xx - Service 3B)
            let volHex = String(format: "%02X", parkAssistVolume)
            let volRes = try await interface.sendDiagnosticRequest("3BB1\(volHex)", timeout: 4.0)
            try checkDiagnosticResponse(volRes, forService: "3B")
            try Task.checkCancellation()
            
            // Tonalité (3BC1xx - Service 3B)
            let toneHex = String(format: "%02X", parkAssistTone)
            let toneRes = try await interface.sendDiagnosticRequest("3BC1\(toneHex)", timeout: 4.0)
            try checkDiagnosticResponse(toneRes, forService: "3B")
            try Task.checkCancellation()
            
            // Bouton d'Inhibition (3BE3xx - Service 3B)
            let inhibHex = parkAssistInhibitionButton ? "80" : "00"
            let inhibRes = try await interface.sendDiagnosticRequest("3BE3\(inhibHex)", timeout: 4.0)
            try checkDiagnosticResponse(inhibRes, forService: "3B")
            try Task.checkCancellation()
            
            // Affichage du succès
            showSuccessMessage = true
            successTimerTask?.cancel()
            successTimerTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    showSuccessMessage = false
                }
            }
            
        } catch is CancellationError {
            // Sortie propre
        } catch {
            actionError = "Erreur d'écriture : \(error.localizedDescription)"
        }
        
        isWriting = false
    }
    
    private func parseHexByte(from response: String, prefix: String) -> Int? {
        let cleanResponse = response.replacing(" ", with: "")
        let cleanPrefix = prefix.replacing(" ", with: "")
        
        guard let range = cleanResponse.range(of: cleanPrefix) else { return nil }
        let remaining = cleanResponse[range.upperBound...]
        guard remaining.count >= 2 else { return nil }
        let byteString = String(remaining.prefix(2))
        return Int(byteString, radix: 16)
    }

    private func ensureExtendedSession(interface: VehicleInterface) async {
        // Tentative d'ouverture de session diagnostic étendue KWP2000 (10 85 ou 10 86)
        _ = try? await interface.sendDiagnosticRequest("1085", timeout: 1.0)
        _ = try? await interface.sendDiagnosticRequest("1086", timeout: 1.0)
    }

    private func checkDiagnosticResponse(_ response: String, forService service: String) throws {
        let clean = response.replacing(" ", with: "").uppercased()
        if clean.hasPrefix("7F" + service) {
            let nrcHex = String(clean.dropFirst(4).prefix(2))
            let nrcByte = UInt8(nrcHex, radix: 16) ?? 0
            let nrcDescription = NRC.description(for: nrcByte)
            throw NSError(
                domain: "ConfigurationManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Le calculateur a rejeté la requête. Erreur : \(nrcDescription)"]
            )
        }
    }

    private func verifyVehicleImmobile(interface: VehicleInterface) async throws {
        do {
            // Lecture de la vitesse via KWP2000 (Service 21, local identifier 0D)
            let speedResp = try await interface.sendDiagnosticRequest("210D", timeout: 1.0)
            let clean = speedResp.replacing(" ", with: "").uppercased()
            if clean.hasPrefix("610D"), clean.count >= 6 {
                if let speedByte = UInt8(clean.dropFirst(4).prefix(2), radix: 16) {
                    if speedByte > 0 {
                        throw NSError(
                            domain: "ConfigurationManager",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Sécurité : Le véhicule est en mouvement (\(speedByte) km/h). Le codage est bloqué."]
                        )
                    }
                }
            }
        } catch let error as NSError where error.domain == "ConfigurationManager" {
            throw error
        } catch {
            NSLog("[ConfigurationManager] Impossible de valider l'immobilisation via 210D : \(error.localizedDescription)")
        }
    }

    /// Déverrouille l'accès de sécurité d'un calculateur (Service 27) si requis.
    private func unlockSecurityAccess(interface: VehicleInterface, level: UInt8, algorithm: SecurityAccessManager.Algorithm, mask: String) async throws {
        let requestSeedCmd = String(format: "27%02X", level)
        let seedResponse = try await interface.sendDiagnosticRequest(requestSeedCmd, timeout: 2.0)
        let cleanSeed = seedResponse.replacing(" ", with: "").uppercased()
        
        if cleanSeed.hasPrefix("7F27") {
            let nrcByte = UInt8(cleanSeed.dropFirst(4).prefix(2), radix: 16) ?? 0
            if nrcByte == 0x37 {
                try await Task.sleep(for: .seconds(2))
                return try await unlockSecurityAccess(interface: interface, level: level, algorithm: algorithm, mask: mask)
            }
            if nrcByte == 0x11 || nrcByte == 0x12 || nrcByte == 0x7E || nrcByte == 0x24 {
                NSLog("[ConfigurationManager] SecurityAccess non supporté ou non requis par cet ECU (NRC: 0x%02X). Continuation.", nrcByte)
                return
            }
            throw NSError(
                domain: "ConfigurationManager",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Erreur SecurityAccess (Requête Seed): \(NRC.description(for: nrcByte))"]
            )
        }
        
        let expectedPrefix = String(format: "67%02X", level)
        guard cleanSeed.hasPrefix(expectedPrefix) else { return }
        
        let seedHex = String(cleanSeed.dropFirst(4))
        if seedHex.replacing("0", with: "").isEmpty {
            NSLog("[ConfigurationManager] Le calculateur est déjà déverrouillé (Seed à 0).")
            return
        }
        
        let keyHex = SecurityAccessManager.calculateKey(seedHex: seedHex, algorithm: algorithm, maskHex: mask)
        
        let sendKeyCmd = String(format: "27%02X", level + 1) + keyHex
        let keyResponse = try await interface.sendDiagnosticRequest(sendKeyCmd, timeout: 2.0)
        let cleanKey = keyResponse.replacing(" ", with: "").uppercased()
        
        if cleanKey.hasPrefix("7F27") {
            let nrcByte = UInt8(cleanKey.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw NSError(
                domain: "ConfigurationManager",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Clé de sécurité invalide ou refusée par le calculateur : \(NRC.description(for: nrcByte))"]
            )
        }
    }
}
