import Foundation
import Observation

@MainActor
@Observable
final class MaintenanceManager {
    var isExecuting = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    /// Réinitialisation de l'intervalle de vidange (TdB - 7A1)
    func resetOilService(elm: ELM327) async {
        await executeRoutine(
            elm: elm,
            ecuHeader: "ATSH7A1", // TdB Header
            routineCommand: "310101", // Fake routine for oil reset
            name: "Remise à zéro Vidange"
        )
    }

    /// Mode Maintenance Frein de Parking (FPA - 7A0)
    func enterEPBMaintenanceMode(elm: ELM327) async {
        await executeRoutine(
            elm: elm,
            ecuHeader: "ATSH7A0", // FPA Header
            routineCommand: "310102", // Fake routine for EPB maintenance
            name: "Mode Atelier Frein de Parking"
        )
    }

    /// Régénération statique du Filtre à Particules (Injection - 7E0)
    func forceDPFRegeneration(elm: ELM327) async {
        await executeRoutine(
            elm: elm,
            ecuHeader: "ATSH7E0", // Injection Header
            routineCommand: "310103", // Fake routine for DPF regeneration
            name: "Régénération FAP"
        )
    }

    private func executeRoutine(elm: ELM327, ecuHeader: String, routineCommand: String, name: String) async {
        isExecuting = true
        errorMessage = nil
        successMessage = nil

        do {
            // 1. Setup Header
            _ = try await elm.send(ecuHeader)

            // 2. Start Session (Extended Diagnostic)
            _ = try await elm.send("10C0")

            // 3. Send Routine Control Command
            let response = try await elm.send(routineCommand)

            // 4. Close Session (Return to default)
            _ = try await elm.send("1081")

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
