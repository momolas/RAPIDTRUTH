import Foundation
import Observation
import SwiftVehicleProtocols

@MainActor
@Observable
final class ConfigurationManager {
    // MARK: - 1. Éclairage & Visibilité
    var drlEnabled: Bool = false // Feux de jour (Daytime Running Lights)
    var xenonHeadlights: Bool = false // Projecteurs Xénon / LED
    var corneringLightsMode: Int = 0 // 0: Sans, 1: Feux virage, 2: AFS seul, 3: Virage + AFS
    var corneringSpeedThreshold: Int = 40 // Seuil vitesse en km/h
    var followMeHome: Bool = false // Éclairage d'accompagnement
    var comingHomeDuration: Int = 30 // Durée en secondes (30, 60, 120)
    var oneTouchTurnSignal: Bool = true // Clignotants impulsionnels
    var laneChangeFlashes: Int = 3 // 3 ou 5 clignotements
    var autoRainSensor: Bool = true // Allumage auto feux & essuie-glaces
    var alternatorClass: String = "110A" // 110A ou 150A

    // MARK: - 2. Portes, Vitres & Sécurité
    var autoLockDoors: Bool = true // Condamnation automatique à 10 km/h
    var autoRearWiper: Bool = true // Essuie-glace arrière en marche arrière
    var deadlocking: Bool = false // Super-condamnation
    var selectiveUnlocking: Bool = false // Déverrouillage porte conducteur seule
    var keylessGo: Bool = false // Accès & Démarrage mains libres
    var rainClosing: Bool = false // Fermeture automatique des vitres si pluie
    var acousticLockConfirmation: Bool = false // Bip sonore au verrouillage
    var tpmsEnabled: Bool = true // Surveillance pression pneus (SSPP)

    // MARK: - 3. Combiné d'Instruments & Habitacle
    var needleSweep: Bool = false // Balayage des aiguilles au contact (Gauge Staging)
    var seatbeltWarning: Bool = true // Alerte sonore de ceinture
    var overspeedWarning: Bool = false // Alerte de survitesse
    var overspeedThreshold: Int = 120 // Seuil survitesse en km/h (90, 110, 120, 130)
    var dashboardLanguage: String = "FR" // "FR" ou "EN"
    var consumptionUnit: String = "L/100" // "L/100" ou "KM/L"
    var clockDisplay: Bool = true // Affichage de l'horloge
    var startStopMemory: Bool = false // Mémoriser le dernier état du Start & Stop
    var fuelType: String = "DSL" // "DSL" (Diesel) ou "GSL" (Essence)
    var gearboxType: String = "BVM" // "BVM" (Manuelle) ou "BVA" (Automatique)
    var voiceSynthesis: Bool = true // Synthèse vocale
    var oilServiceInterval: String = "20K" // "15K", "20K", "30K"

    // MARK: - 4. Aides à la Conduite & Multimédia
    var parkAssistVolume: Int = 3 // 0 (Désactivé) à 7 (Très Fort)
    var parkAssistTone: Int = 3 // 0 (500Hz) à 4 (2000Hz)
    var parkAssistInhibitionButton: Bool = true
    var androidAuto: Bool = false // Activation Android Auto / CarPlay RadNav
    var rearViewCamera: Bool = false // Activation caméra de recul
    var coldClimateMode: Bool = false // Mode climat froid frein à main électrique
    
    // Status
    var isReading = false
    var isWriting = false
    var actionError: String?
    var showSuccessMessage = false
    private var successTimerTask: Task<Void, Never>?

    // MARK: - Lecture de Configuration

    func readConfig(interface: VehicleInterface) async {
        isReading = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // 1. Read UCH config (txID 745)
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
                rainClosing = uchRes.contains("RAINCLOSE")
                acousticLockConfirmation = uchRes.contains("BEEP")
                laneChangeFlashes = uchRes.contains("FLASH5") ? 5 : 3
            }
            
            // 2. Read TdB config (txID 743)
            try await interface.setTarget(txID: "743", rxID: nil)
            try Task.checkCancellation()
            let tdbRes = try await interface.sendDiagnosticRequest("2101", timeout: 4.0)
            try Task.checkCancellation()
            
            if tdbRes.contains("6101") || tdbRes.contains("61 01") {
                dashboardLanguage = tdbRes.contains("EN") ? "EN" : "FR"
                seatbeltWarning = !tdbRes.contains("NOBEEP")
                clockDisplay = !tdbRes.contains("NOCLK")
                consumptionUnit = tdbRes.contains("KML") ? "KM/L" : "L/100"
                overspeedWarning = tdbRes.contains("120") || tdbRes.contains("110") || tdbRes.contains("130")
                fuelType = tdbRes.contains("GSL") ? "GSL" : "DSL"
                gearboxType = tdbRes.contains("BVA") ? "BVA" : "BVM"
                voiceSynthesis = !tdbRes.contains("NOSYN")
                oilServiceInterval = tdbRes.contains("15K") ? "15K" : (tdbRes.contains("30K") ? "30K" : "20K")
                needleSweep = tdbRes.contains("SWEEP")
                startStopMemory = tdbRes.contains("SSMEM")
            }
            
            // 3. Read RadNav config (txID 756 / 74D)
            try await interface.setTarget(txID: "756", rxID: nil)
            try Task.checkCancellation()
            let radNavRes = try await interface.sendDiagnosticRequest("2102", timeout: 4.0)
            try Task.checkCancellation()
            
            if radNavRes.contains("6102") || radNavRes.contains("61 02") {
                androidAuto = radNavRes.contains("AA")
                rearViewCamera = radNavRes.contains("RVC")
            }
            
            // 4. Read UPC config (txID 744)
            try await interface.setTarget(txID: "744", rxID: nil)
            try Task.checkCancellation()
            let upcRes = try await interface.sendDiagnosticRequest("2103", timeout: 4.0)
            try Task.checkCancellation()
            
            if upcRes.contains("6103") || upcRes.contains("61 03") {
                xenonHeadlights = upcRes.contains("XENON")
                drlEnabled = !upcRes.contains("NODRL")
                alternatorClass = upcRes.contains("150A") ? "150A" : "110A"
                if upcRes.contains("CORN_ON_AFS_ON") {
                    corneringLightsMode = 3
                } else if upcRes.contains("CORN_OFF_AFS_ON") {
                    corneringLightsMode = 2
                } else if upcRes.contains("CORN_ON_AFS_OFF") {
                    corneringLightsMode = 1
                } else {
                    corneringLightsMode = 0
                }
            }
            
            // 5. Read FPA config (txID 755)
            try await interface.setTarget(txID: "755", rxID: nil)
            try Task.checkCancellation()
            let fpaRes = try await interface.sendDiagnosticRequest("2104", timeout: 4.0)
            try Task.checkCancellation()
            
            if fpaRes.contains("6104") || fpaRes.contains("61 04") {
                coldClimateMode = fpaRes.contains("COLD")
            }
            
            // 6. Read AAS config (txID 747)
            try await interface.setTarget(txID: "747", rxID: nil)
            try Task.checkCancellation()
            let aasRes = try await interface.sendDiagnosticRequest("2105", timeout: 4.0)
            try Task.checkCancellation()
            
            if aasRes.contains("6105") || aasRes.contains("61 05") {
                parkAssistVolume = 3
                parkAssistTone = 3
                parkAssistInhibitionButton = !aasRes.contains("NOINHIB")
            }
            
        } catch is CancellationError {
            // Task canceled
        } catch {
            actionError = "Erreur lecture configuration : \(error.localizedDescription)"
        }
        
        isReading = false
    }

    // MARK: - Écriture de Configuration

    func writeConfig(interface: VehicleInterface) async {
        isWriting = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            try await verifyVehicleImmobile(interface: interface)
            
            // 1. Write UCH Config
            try await interface.setTarget(txID: "745", rxID: nil)
            try Task.checkCancellation()
            try await enterExtendedSession(interface: interface)
            try await unlockSecurityAccess(interface: interface, level: 0x01, algorithm: .xorStatique, mask: "5A5A")
            
            var uchConfigHex = "3B00"
            uchConfigHex += autoLockDoors ? "01" : "00"
            uchConfigHex += autoRearWiper ? "01" : "00"
            uchConfigHex += followMeHome ? "01" : "00"
            uchConfigHex += oneTouchTurnSignal ? "01" : "00"
            uchConfigHex += deadlocking ? "01" : "00"
            uchConfigHex += tpmsEnabled ? "01" : "00"
            uchConfigHex += autoRainSensor ? "01" : "00"
            uchConfigHex += keylessGo ? "01" : "00"
            uchConfigHex += selectiveUnlocking ? "01" : "00"
            uchConfigHex += rainClosing ? "01" : "00"
            uchConfigHex += acousticLockConfirmation ? "01" : "00"
            uchConfigHex += String(format: "%02X", laneChangeFlashes)
            
            let uchResp = try await interface.sendDiagnosticRequest(uchConfigHex, timeout: 5.0)
            try checkDiagnosticResponse(uchResp, forService: "3B")
            try await exitExtendedSession(interface: interface)
            
            // 2. Write TdB Config
            try await interface.setTarget(txID: "743", rxID: nil)
            try Task.checkCancellation()
            try await enterExtendedSession(interface: interface)
            
            var tdbConfigHex = "3B01"
            tdbConfigHex += (dashboardLanguage == "EN") ? "01" : "00"
            tdbConfigHex += seatbeltWarning ? "01" : "00"
            tdbConfigHex += clockDisplay ? "01" : "00"
            tdbConfigHex += (consumptionUnit == "KM/L") ? "01" : "00"
            tdbConfigHex += overspeedWarning ? String(format: "%02X", overspeedThreshold) : "00"
            tdbConfigHex += (fuelType == "GSL") ? "01" : "00"
            tdbConfigHex += (gearboxType == "BVA") ? "01" : "00"
            tdbConfigHex += voiceSynthesis ? "01" : "00"
            tdbConfigHex += (oilServiceInterval == "15K") ? "01" : ((oilServiceInterval == "30K") ? "03" : "02")
            tdbConfigHex += needleSweep ? "01" : "00"
            tdbConfigHex += startStopMemory ? "01" : "00"
            
            let tdbResp = try await interface.sendDiagnosticRequest(tdbConfigHex, timeout: 5.0)
            try checkDiagnosticResponse(tdbResp, forService: "3B")
            try await exitExtendedSession(interface: interface)
            
            // 3. Write RadNav Config
            try await interface.setTarget(txID: "756", rxID: nil)
            try Task.checkCancellation()
            try await enterExtendedSession(interface: interface)
            
            var radNavConfigHex = "3B02"
            radNavConfigHex += androidAuto ? "01" : "00"
            radNavConfigHex += rearViewCamera ? "01" : "00"
            
            let radNavResp = try await interface.sendDiagnosticRequest(radNavConfigHex, timeout: 5.0)
            try checkDiagnosticResponse(radNavResp, forService: "3B")
            try await exitExtendedSession(interface: interface)
            
            // 4. Write UPC Config
            try await interface.setTarget(txID: "744", rxID: nil)
            try Task.checkCancellation()
            try await enterExtendedSession(interface: interface)
            
            var upcConfigHex = "3B03"
            upcConfigHex += xenonHeadlights ? "01" : "00"
            upcConfigHex += drlEnabled ? "01" : "00"
            upcConfigHex += (alternatorClass == "150A") ? "01" : "00"
            upcConfigHex += String(format: "%02X", corneringLightsMode)
            upcConfigHex += String(format: "%02X", corneringSpeedThreshold)
            
            let upcResp = try await interface.sendDiagnosticRequest(upcConfigHex, timeout: 5.0)
            try checkDiagnosticResponse(upcResp, forService: "3B")
            try await exitExtendedSession(interface: interface)
            
            // 5. Write FPA Config
            try await interface.setTarget(txID: "755", rxID: nil)
            try Task.checkCancellation()
            try await enterExtendedSession(interface: interface)
            
            var fpaConfigHex = "3B04"
            fpaConfigHex += coldClimateMode ? "01" : "00"
            
            let fpaResp = try await interface.sendDiagnosticRequest(fpaConfigHex, timeout: 5.0)
            try checkDiagnosticResponse(fpaResp, forService: "3B")
            try await exitExtendedSession(interface: interface)
            
            // 6. Write AAS Config
            try await interface.setTarget(txID: "747", rxID: nil)
            try Task.checkCancellation()
            try await enterExtendedSession(interface: interface)
            
            var aasConfigHex = "3B05"
            aasConfigHex += String(format: "%02X", parkAssistVolume)
            aasConfigHex += String(format: "%02X", parkAssistTone)
            aasConfigHex += parkAssistInhibitionButton ? "80" : "00"
            
            let aasResp = try await interface.sendDiagnosticRequest(aasConfigHex, timeout: 5.0)
            try checkDiagnosticResponse(aasResp, forService: "3B")
            try await exitExtendedSession(interface: interface)
            
            showSuccessMessage = true
            successTimerTask?.cancel()
            successTimerTask = Task {
                try? await Task.sleep(for: .seconds(4))
                if !Task.isCancelled {
                    self.showSuccessMessage = false
                }
            }
            
        } catch is CancellationError {
            // Task canceled
        } catch {
            actionError = error.localizedDescription
        }
        
        isWriting = false
    }

    // MARK: - Méthodes Utilitaires & Sécurité

    private func enterExtendedSession(interface: VehicleInterface) async throws {
        _ = try? await interface.sendDiagnosticRequest("1085", timeout: 2.0)
    }

    private func exitExtendedSession(interface: VehicleInterface) async throws {
        _ = try? await interface.sendDiagnosticRequest("1086", timeout: 1.0)
    }

    private func checkDiagnosticResponse(_ response: String, forService service: String) throws {
        let clean = response.replacing(" ", with: "").uppercased()
        if clean.hasPrefix("7F" + service) {
            let nrcHex = String(clean.dropFirst(4).prefix(2))
            let nrcByte = UInt8(nrcHex, radix: 16) ?? 0
            let nrcDescription = UDSNRC.description(for: nrcByte)
            throw NSError(
                domain: "ConfigurationManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Le calculateur a rejeté la requête. Erreur : \(nrcDescription)"]
            )
        }
    }

    private func verifyVehicleImmobile(interface: VehicleInterface) async throws {
        do {
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
                return
            }
            throw NSError(
                domain: "ConfigurationManager",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Erreur SecurityAccess (Requête Seed): \(UDSNRC.description(for: nrcByte))"]
            )
        }
        
        let expectedPrefix = String(format: "67%02X", level)
        guard cleanSeed.hasPrefix(expectedPrefix) else { return }
        
        let seedHex = String(cleanSeed.dropFirst(4))
        if seedHex.replacing("0", with: "").isEmpty {
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
                userInfo: [NSLocalizedDescriptionKey: "Clé de sécurité invalide ou refusée par le calculateur : \(UDSNRC.description(for: nrcByte))"]
            )
        }
    }
}
