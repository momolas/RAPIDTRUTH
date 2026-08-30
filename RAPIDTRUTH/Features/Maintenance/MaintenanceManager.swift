import Foundation
import Observation
import SwiftVehicleProtocols

enum BatteryTechnology: String, CaseIterable, Identifiable, Sendable {
    case standardLeadAcid = "Plomb-Acide Standard (SLI)"
    case efb = "EFB (Enhanced Flooded - Stop & Start)"
    case agm = "AGM (Absorbent Glass Mat - Haute Puissance)"
    
    var id: String { rawValue }
    
    var hexCode: UInt8 {
        switch self {
        case .standardLeadAcid: return 0x01
        case .efb: return 0x02
        case .agm: return 0x03
        }
    }
}

@MainActor
@Observable
final class MaintenanceManager {
    var isExecuting = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var activeActuatorTestName: String? = nil

    // MARK: - Outils d'Entretien Courant

    /// Réinitialisation de l'intervalle de vidange (TdB - 743)
    func resetOilService(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "743", // TdB Header
            routineCommand: "300101", // KWP2000 start routine for oil reset
            name: "Remise à zéro Vidange"
        )
    }

    /// Régénération statique du Filtre à Particules (Injection - 7E0)
    func forceDPFRegeneration(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "7E0", // Injection Header
            routineCommand: "300103", // KWP2000 start routine for DPF regeneration
            name: "Régénération FAP"
        )
    }

    // MARK: - Frein à Main Électrique (EPB / FPA)

    /// Mode Maintenance Frein de Parking (FPA - 755 / 746) - Rétractation des pistons pour changement plaquettes
    func enterEPBMaintenanceMode(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "755", // FPA Header
            routineCommand: "300102", // KWP2000 start routine for EPB maintenance
            name: "Rétractation des Étriers (Mode Remplacement Plaquettes)"
        )
    }

    /// Sortie du Mode Maintenance Frein de Parking (FPA - 755 / 746) - Calibrage et resserrage des pistons
    func exitEPBMaintenanceMode(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "755", // FPA Header
            routineCommand: "300105", // Calibrate and tighten
            name: "Fermeture & Calibration des Étriers Frein de Parking"
        )
    }

    // MARK: - Enregistrement Batterie & Gestion d'Énergie (BMS)

    /// Déclaration d'une nouvelle batterie au calculateur d'énergie (BMS / UPC - 745 / 744)
    func registerNewBattery(interface: VehicleInterface, technology: BatteryTechnology, capacityAh: Int) async {
        isExecuting = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // Target UPC / BCM (745 ou 744)
            try await interface.setTarget(txID: "745", rxID: nil)
            try Task.checkCancellation()
            
            _ = try await openDiagnosticSession(interface: interface)
            try Task.checkCancellation()
            
            // Format paramètre : Tech (1 octet) + Capacité en Ah (1 octet) -> ex: 03 46 (AGM 70Ah)
            let batteryHex = String(format: "%02X%02X", technology.hexCode, UInt8(capacityAh))
            let writeResp = try await interface.sendDiagnosticRequest("3B2E" + batteryHex, timeout: 3.5)
            
            // Réinitialisation de l'historique d'état de santé batterie (SoH)
            _ = try? await interface.sendDiagnosticRequest("30010A", timeout: 2.0)
            
            _ = try? await interface.sendDiagnosticRequest("1081", timeout: 2.0)
            
            if writeResp.contains("7B") || writeResp.contains("6E") || writeResp.isEmpty || writeResp.contains("OK") {
                successMessage = "Batterie enregistrée avec succès : \(technology.rawValue) - \(capacityAh) Ah. Courbe de charge alternateur réinitialisée."
            } else {
                errorMessage = "Réponse inattendue lors de l'écriture batterie : \(writeResp)"
            }
        } catch {
            if !(error is CancellationError) {
                errorMessage = "Erreur enregistrement batterie : \(error.localizedDescription)"
            }
        }
        
        isExecuting = false
    }

    // MARK: - Freinage & ABS

    /// Purge globale du groupe hydraulique ABS (ABS - 740)
    func purgeABSGroup(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "740", // ABS Header
            routineCommand: "300104", // KWP2000 start routine for ABS bleeding
            name: "Purge active du groupe hydraulique ABS"
        )
    }

    /// Commande individuelle de purge pour une roue spécifique (ABS - 740)
    func purgeABSWheel(interface: VehicleInterface, wheelName: String) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "740", // ABS Header
            routineCommand: "300104", // command for ABS bleeding
            name: "Purge active roue : \(wheelName)"
        )
    }

    // MARK: - Moteur & Injection

    /// Réapprentissage et alignement des butées du boîtier papillon motorisé (Injection - 7E0)
    func adaptThrottleBody(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "7E0",
            routineCommand: "300109",
            name: "Alignement & Réapprentissage Boîtier Papillon"
        )
    }

    /// Réinitialisation des autoadaptatifs moteur (Injection - 7E0)
    func resetECUAdaptations(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "7E0",
            routineCommand: "300108",
            name: "Réinitialisation des Autoadaptatifs Moteur (Fuel Trims)"
        )
    }

    /// Ajustement du ralenti moteur dCi : true = Augmenter (+50 RPM), false = Diminuer (-50 RPM)
    func adjustIdleSpeed(interface: VehicleInterface, increase: Bool) async {
        let statusName = increase ? "Augmentation du ralenti dCi (+50 tr/min)" : "Diminution du ralenti dCi (-50 tr/min)"
        let command = increase ? "30010B" : "300107"
        await executeRoutine(
            interface: interface,
            ecuHeader: "7E0", // Injection Header
            routineCommand: command,
            name: statusName
        )
    }

    // MARK: - Programmation & Sécurité

    /// Télécodage SSPP : true = Activé (CF023 / LC017), false = Désactivé
    func setSSPPEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation de la surveillance SSPP" : "Désactivation de la surveillance SSPP"
        let command = enabled ? "3B2301" : "3B2300"
        await executeRoutine(
            interface: interface,
            ecuHeader: "745", // UCH Header
            routineCommand: command,
            name: statusName
        )
    }

    /// Programmation de la périodicité de vidange personnalisée sur le Tableau de Bord
    func setOilServicePeriodicity(interface: VehicleInterface, intervalKM: Int, intervalMonths: Int) async {
        isExecuting = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await interface.setTarget(txID: "743", rxID: "763")
            try Task.checkCancellation()
            
            _ = try await openDiagnosticSession(interface: interface)
            try Task.checkCancellation()
            
            let kmHex = String(format: "%04X", intervalKM)
            let responseKM = try await interface.sendDiagnosticRequest("3B06" + kmHex, timeout: 3.0)
            try Task.checkCancellation()
            
            let monthsHex = String(format: "%02X", intervalMonths)
            let responseMonths = try await interface.sendDiagnosticRequest("3B07" + monthsHex, timeout: 3.0)
            try Task.checkCancellation()
            
            _ = try? await interface.sendDiagnosticRequest("1081", timeout: 3.0)
            
            if responseKM.contains("7B") || responseMonths.contains("7B") || responseKM.isEmpty {
                successMessage = "Télécodage réussi ! Périodicité d'entretien programmée à \(intervalKM) km / \(intervalMonths) mois."
            } else {
                errorMessage = "Réponse inattendue lors de l'écriture TDB."
            }
        } catch {
            if !(error is CancellationError) {
                errorMessage = "Erreur de télécodage : \(error.localizedDescription)"
            }
        }
        
        isExecuting = false
    }

    /// Verrouillage / Déverrouillage de sécurité du calculateur d'Airbag
    func setAirbagLocked(interface: VehicleInterface, locked: Bool) async {
        let statusName = locked ? "Verrouillage sécurisé Airbag (Atelier)" : "Déverrouillage actif Airbag (Route)"
        let command = locked ? "300106" : "300107"
        await executeRoutine(
            interface: interface,
            ecuHeader: "752", // Airbag Header
            routineCommand: command,
            name: statusName
        )
    }

    /// Allumage automatique des feux : true = Activé (CF064), false = Désactivé
    func setAutoHeadlightsEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation allumage auto des feux" : "Désactivation allumage auto des feux"
        let command = enabled ? "3B4001" : "3B4000"
        await executeRoutine(
            interface: interface,
            ecuHeader: "745", // UCH Header
            routineCommand: command,
            name: statusName
        )
    }

    /// Essuyage arrière en marche arrière : true = Activé (CF108), false = Désactivé
    func setReverseWiperEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation essuyage arrière en marche arrière" : "Désactivation essuyage arrière en marche arrière"
        let command = enabled ? "3B6C01" : "3B6C00"
        await executeRoutine(
            interface: interface,
            ecuHeader: "745", // UCH Header
            routineCommand: command,
            name: statusName
        )
    }

    /// Alerte sonore ceinture : true = Activé (CF030), false = Désactivé
    func setSeatbeltBuzzerEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation de l'alerte ceinture" : "Désactivation de l'alerte ceinture"
        let command = enabled ? "3B1E01" : "3B1E00"
        await executeRoutine(
            interface: interface,
            ecuHeader: "745", // UCH Header
            routineCommand: command,
            name: statusName
        )
    }

    // MARK: - Exécution de Routines

    private func executeRoutine(interface: VehicleInterface, ecuHeader: String, routineCommand: String, name: String) async {
        isExecuting = true
        errorMessage = nil
        successMessage = nil

        do {
            try await interface.setTarget(txID: ecuHeader, rxID: nil)
            try Task.checkCancellation()

            _ = try await openDiagnosticSession(interface: interface)
            try Task.checkCancellation()

            let response = try await interface.sendDiagnosticRequest(routineCommand, timeout: 4.0)
            try Task.checkCancellation()

            _ = try await interface.sendDiagnosticRequest("1081", timeout: 4.0)

            if response.contains("70") || response.contains("7B") || response.isEmpty || response.contains("OK") {
                successMessage = "\(name) exécutée avec succès."
            } else {
                errorMessage = "Échec de l'opération : Réponse inattendue (\(response))"
            }

        } catch {
            if !(error is CancellationError) {
                errorMessage = "Erreur de communication : \(error.localizedDescription)"
            }
        }

        isExecuting = false
    }

    private func openDiagnosticSession(interface: VehicleInterface) async throws -> Bool {
        do {
            let res = try await interface.sendDiagnosticRequest("1085", timeout: 2.0)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        do {
            let res = try await interface.sendDiagnosticRequest("1086", timeout: 2.0)
            let normalized = res.uppercased().replacing(" ", with: "")
            if !normalized.starts(with: "7F") && !normalized.isEmpty {
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        
        return false
    }

    /// Lance un test actif d'actionneur (KWP2000 Service 2F - InputOutputControlByLocalIdentifier)
    func runActuatorTest(interface: VehicleInterface, ecuHeader: String, command: String, name: String) async {
        isExecuting = true
        activeActuatorTestName = name
        errorMessage = nil
        successMessage = nil

        var finalCommand = command
        if finalCommand.hasPrefix("30") {
            finalCommand = "2F" + finalCommand.dropFirst(2)
        }

        do {
            try await interface.setTarget(txID: ecuHeader, rxID: nil)
            try Task.checkCancellation()

            _ = try await openDiagnosticSession(interface: interface)
            try Task.checkCancellation()

            let response = try await interface.sendDiagnosticRequest(finalCommand, timeout: 4.0)
            try Task.checkCancellation()

            _ = try await interface.sendDiagnosticRequest("1081", timeout: 2.0)

            if response.contains("6F") || response.isEmpty || response.contains("OK") {
                successMessage = "Test actionneur : \(name) activé avec succès."
            } else {
                errorMessage = "Échec du test de l'actionneur : Réponse inattendue (\(response))"
            }
        } catch {
            if !(error is CancellationError) {
                errorMessage = "Erreur actionneur : \(error.localizedDescription)"
            }
        }

        isExecuting = false
        activeActuatorTestName = nil
    }
}
