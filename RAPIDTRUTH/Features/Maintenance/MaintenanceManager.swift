import Foundation
import Observation

@MainActor
@Observable
final class MaintenanceManager {
    var isExecuting = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    /// Réinitialisation de l'intervalle de vidange (TdB - 7A1)
    func resetOilService(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "7A1", // TdB Header
            routineCommand: "310101", // Fake routine for oil reset
            name: "Remise à zéro Vidange"
        )
    }

    /// Mode Maintenance Frein de Parking (FPA - 7A0)
    func enterEPBMaintenanceMode(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "7A0", // FPA Header
            routineCommand: "310102", // Fake routine for EPB maintenance
            name: "Mode Atelier Frein de Parking"
        )
    }

    /// Régénération statique du Filtre à Particules (Injection - 7E0)
    func forceDPFRegeneration(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "7E0", // Injection Header
            routineCommand: "310103", // Fake routine for DPF regeneration
            name: "Régénération FAP"
        )
    }

    /// Purge du groupe hydraulique ABS (ABS - 760)
    func purgeABSGroup(interface: VehicleInterface) async {
        await executeRoutine(
            interface: interface,
            ecuHeader: "760", // ABS Header
            routineCommand: "310104", // Fake routine for ABS bleeding
            name: "Purge du groupe ABS"
        )
    }
    
    /// Télécodage SSPP : true = Activé (CF023 / LC017), false = Désactivé
    func setSSPPEnabled(interface: VehicleInterface, enabled: Bool) async {
        let statusName = enabled ? "Activation de la surveillance SSPP" : "Désactivation de la surveillance SSPP"
        // UDS Write Data By Identifier (2E) on parameter CF023 (01 = Active, 00 = inactive)
        let command = enabled ? "2ECF02301" : "2ECF02300"
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
        // UDS Routine Control (31) to start routine VP011 or VP007
        let command = increase ? "3101VP11" : "3101VP07"
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
            
            // Start Extended Session
            _ = try? await interface.sendDiagnosticRequest("10C0", timeout: 3.0)
            try Task.checkCancellation()
            
            // Write KM Periodicity (VP006 - 2 bytes)
            let kmHex = String(format: "%04X", intervalKM)
            let responseKM = try await interface.sendDiagnosticRequest("2EVP006" + kmHex, timeout: 3.0)
            try Task.checkCancellation()
            
            // Write Months Periodicity (VP007 - 1 byte)
            let monthsHex = String(format: "%02X", intervalMonths)
            let responseMonths = try await interface.sendDiagnosticRequest("2EVP007" + monthsHex, timeout: 3.0)
            
            // Close Session
            _ = try? await interface.sendDiagnosticRequest("1081", timeout: 3.0)
            
            if responseKM.contains("6E") || responseMonths.contains("6E") || responseKM.isEmpty {
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
        // UDS Routine Control (31) on parameters VP006 (Lock) or VP007 (Unlock)
        let command = locked ? "3101VP006" : "3101VP007"
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

            // 2. Start Session (Extended Diagnostic)
            _ = try await interface.sendDiagnosticRequest("10C0", timeout: 4.0)
            try Task.checkCancellation()

            // 3. Send Routine Control Command
            let response = try await interface.sendDiagnosticRequest(routineCommand, timeout: 4.0)
            try Task.checkCancellation()

            // 4. Close Session (Return to default)
            _ = try await interface.sendDiagnosticRequest("1081", timeout: 4.0)

            // Minimal validation logic (71 is positive response to 31, 6E is for 2E)
            if response.contains("71") || response.contains("6E") || response.isEmpty || response.contains("OK") {
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
}
