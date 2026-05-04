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

    private func executeRoutine(interface: VehicleInterface, ecuHeader: String, routineCommand: String, name: String) async {
        isExecuting = true
        errorMessage = nil
        successMessage = nil

        do {
            // 1. Setup Header
            try await interface.setTarget(txID: ecuHeader, rxID: nil)

            // 2. Start Session (Extended Diagnostic)
            _ = try await interface.sendDiagnosticRequest("10C0", timeout: 4.0)

            // 3. Send Routine Control Command
            let response = try await interface.sendDiagnosticRequest(routineCommand, timeout: 4.0)

            // 4. Close Session (Return to default)
            _ = try await interface.sendDiagnosticRequest("1081", timeout: 4.0)

            // Minimal validation logic (71 is positive response to 31)
            if response.contains("71") {
                successMessage = "\(name) exécutée avec succès."
            } else {
                errorMessage = "Échec de l'opération : Réponse inattendue (\(response))"
            }

        } catch {
            errorMessage = "Erreur de communication : \(error.localizedDescription)"
        }

        isExecuting = false
    }
}
