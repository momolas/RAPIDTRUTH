import Foundation
import Observation

@MainActor
@Observable
final class ActuatorManager {
    var activeActuator: ActuatorDef? = nil
    var isExecuting: Bool = false
    var remainingSeconds: Int = 0
    var statusMessage: String? = nil
    var lastNRCError: UDSNRCResponse? = nil
    var executionSuccess: Bool? = nil
    
    private var countdownTask: Task<Void, Never>?

    init() {}

    func runActuatorTest(actuator: ActuatorDef, interface: VehicleInterface) async {
        guard !isExecuting else { return }
        
        isExecuting = true
        activeActuator = actuator
        remainingSeconds = actuator.durationSeconds
        statusMessage = "Initialisation de la session..."
        lastNRCError = nil
        executionSuccess = nil
        
        do {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            
            // 1. Cibler l'ECU concerné
            try await interface.setTarget(txID: actuator.ecuHeader, rxID: nil)
            
            // 2. Ouvrir la Session Étendue si nécessaire (Service 0x10 0x03 ou 0x10 0xC0)
            if actuator.requiresExtendedSession {
                statusMessage = "Ouverture de session diagnostic (0x10 0x03)..."
                let sessionResp = try await interface.sendDiagnosticRequest("1003", timeout: 2.0)
                if let nrc = UDSNRC.parse(from: sessionResp) {
                    // Si 1003 est refusé, tenter 10C0 (KWP2000 Renault)
                    let fallbackResp = try await interface.sendDiagnosticRequest("10C0", timeout: 2.0)
                    if let fallbackNrc = UDSNRC.parse(from: fallbackResp) {
                        lastNRCError = fallbackNrc
                        statusMessage = "Refus de session : \(fallbackNrc.title)"
                        executionSuccess = false
                        isExecuting = false
                        return
                    }
                }
            }
            
            // 3. Déclencher la commande d'actionnement
            statusMessage = "Déclenchement : \(actuator.name)..."
            let startResp = try await interface.sendDiagnosticRequest(actuator.startCommandHex, timeout: 3.0)
            
            if let nrc = UDSNRC.parse(from: startResp) {
                lastNRCError = nrc
                statusMessage = "Rejet actionneur : \(nrc.title) — \(nrc.actionAdvice)"
                executionSuccess = false
                isExecuting = false
                return
            }
            
            // 4. Lancer le compte à rebours de sécurité
            statusMessage = "Actionnement en cours (\(actuator.durationSeconds)s)..."
            startCountdown(duration: actuator.durationSeconds)
            
            // Attendre la fin de la durée
            try await Task.sleep(for: .seconds(actuator.durationSeconds))
            
            // 5. Arrêter l'actionnement si commande d'arrêt disponible
            if let stopCmd = actuator.stopCommandHex {
                statusMessage = "Arrêt de l'actionneur..."
                _ = try? await interface.sendDiagnosticRequest(stopCmd, timeout: 2.0)
            }
            
            executionSuccess = true
            statusMessage = "Test validé avec succès !"
        } catch {
            statusMessage = "Erreur communication : \(error.localizedDescription)"
            executionSuccess = false
        }
        
        countdownTask?.cancel()
        countdownTask = nil
        isExecuting = false
    }

    func cancelTest(interface: VehicleInterface) async {
        guard isExecuting, let actuator = activeActuator else { return }
        countdownTask?.cancel()
        countdownTask = nil
        
        statusMessage = "Interruption d'urgence..."
        if let stopCmd = actuator.stopCommandHex {
            _ = try? await interface.sendDiagnosticRequest(stopCmd, timeout: 1.5)
        }
        
        isExecuting = false
        executionSuccess = false
        statusMessage = "Actionnement interrompu par l'utilisateur."
    }

    private func startCountdown(duration: Int) {
        countdownTask?.cancel()
        remainingSeconds = duration
        countdownTask = Task { [weak self] in
            while let self = self, self.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                self.remainingSeconds -= 1
            }
        }
    }
}
