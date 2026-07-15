import Foundation
import Observation

@MainActor
@Observable
final class MaintenanceManager {
    var isExecuting = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var activeActuatorTestName: String? = nil

    /// Réinitialisation de l'intervalle de vidange (TdB - 743)
    func resetOilService(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "743", // TdB Header
            routineCommand: "300101", // KWP2000 start routine for oil reset
            name: "Remise à zéro Vidange"
        )
    }

    /// Mode Maintenance Frein de Parking (FPA - 755)
    func enterEPBMaintenanceMode(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "755", // FPA Header
            routineCommand: "300102", // KWP2000 start routine for EPB maintenance
            name: "Mode Atelier Frein de Parking"
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

    /// Purge du groupe hydraulique ABS (ABS - 740)
    func purgeABSGroup(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "740", // ABS Header
            routineCommand: "300104", // KWP2000 start routine for ABS bleeding
            name: "Purge du groupe ABS"
        )
    }
    
    /// Télécodage SSPP : true = Activé (CF023 / LC017), false = Désactivé
    func setSSPPEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation de la surveillance SSPP" : "Désactivation de la surveillance SSPP"
        // KWP2000 Write Data By Local Identifier (3B) on parameter CF023 (01 = Active, 00 = inactive)
        let command = enabled ? "3BCF02301" : "3BCF02300"
        await executeRoutine(
            interface: interface,
            ecuHeader: "745", // UCH Header
            routineCommand: command,
            name: statusName
        )
    }
    
    /// Ajustement du ralenti moteur dCi : true = Augmenter (+50 RPM / VP011), false = Diminuer (-50 RPM / VP007)
    func adjustIdleSpeed(interface: VehicleInterface, increase: Bool) async {
        let statusName = increase ? "Augmentation du ralenti dCi (+50 tr/min)" : "Diminution du ralenti dCi (-50 tr/min)"
        // KWP2000 Start Routine By Local Identifier (30) to start routine VP011 or VP007
        let command = increase ? "3001VP11" : "3001VP07"
        await executeRoutine(
            interface: interface,
            ecuHeader: "7E0", // Injection Header
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
            // Target TDB (743 / Response 763)
            try await interface.setTarget(txID: "743", rxID: "763")
            try Task.checkCancellation()
            
            // Start Extended Session KWP2000 (1085)
            _ = try await openDiagnosticSession(interface: interface)
            try Task.checkCancellation()
            
            // Write KM Periodicity (VP006 - 2 bytes) using KWP2000 Service 3B
            let kmHex = String(format: "%04X", intervalKM)
            let responseKM = try await interface.sendDiagnosticRequest("3BVP006" + kmHex, timeout: 3.0)
            try Task.checkCancellation()
            
            // Write Months Periodicity (VP007 - 1 byte) using KWP2000 Service 3B
            let monthsHex = String(format: "%02X", intervalMonths)
            let responseMonths = try await interface.sendDiagnosticRequest("3BVP007" + monthsHex, timeout: 3.0)
            try Task.checkCancellation()
            
            // Close Session KWP2000 (1081)
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
        // KWP2000 Start Routine By Local Identifier (30) on parameters VP006 (Lock) or VP007 (Unlock)
        let command = locked ? "3001VP006" : "3001VP007"
        await executeRoutine(
            interface: interface,
            ecuHeader: "752", // Airbag Header
            routineCommand: command,
            name: statusName
        )
    }

    private func executeRoutine(interface: VehicleInterface, ecuHeader: String, routineCommand: String, name: String) async {
        isExecuting = true
        errorMessage = nil
        successMessage = nil

        do {
            // 1. Setup Header
            try await interface.setTarget(txID: ecuHeader, rxID: nil)
            try Task.checkCancellation()

            // 2. Start Session (Extended Diagnostic KWP2000)
            _ = try await openDiagnosticSession(interface: interface)
            try Task.checkCancellation()

            // 3. Send Routine Command
            let response = try await interface.sendDiagnosticRequest(routineCommand, timeout: 4.0)
            try Task.checkCancellation()

            // 4. Close Session (Return to default KWP2000)
            _ = try await interface.sendDiagnosticRequest("1081", timeout: 4.0)

            // Minimal validation logic (70 is positive response to 30, 7B is for 3B)
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

    /// Allumage automatique des feux : true = Activé (CF064), false = Désactivé
    func setAutoHeadlightsEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation allumage auto des feux" : "Désactivation allumage auto des feux"
        let command = enabled ? "3BCF06401" : "3BCF06400"
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
        let command = enabled ? "3BCF10801" : "3BCF10800"
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
        let command = enabled ? "3BCF03001" : "3BCF03000"
        await executeRoutine(
            interface: interface,
            ecuHeader: "745", // UCH Header
            routineCommand: command,
            name: statusName
        )
    }

    /// Sortie du Mode Maintenance Frein de Parking (FPA - 755) - Calibrage et resserrage des pistons
    func exitEPBMaintenanceMode(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "755", // FPA Header
            routineCommand: "300105", // Calibrate and tighten
            name: "Fermeture & Calibrage Frein de Parking"
        )
    }

    /// Commande individuelle de purge pour une roue spécifique (ABS - 740)
    func purgeABSWheel(interface: VehicleInterface, wheelName: String) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "740", // ABS Header
            routineCommand: "300104", // command for ABS bleeding
            name: "Purge active : \(wheelName)"
        )
    }

    /// Lance un test actif d'actionneur (KWP2000 Service 2F - InputOutputControlByLocalIdentifier)
    func runActuatorTest(interface: VehicleInterface, ecuHeader: String, command: String, name: String) async {
        isExecuting = true
        activeActuatorTestName = name
        errorMessage = nil
        successMessage = nil

        // Convert command from UDS 30 to KWP2000 2F if it starts with 30
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
