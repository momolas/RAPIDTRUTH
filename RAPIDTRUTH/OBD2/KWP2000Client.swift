import Foundation

/// Gère les opérations de diagnostic avancées via le protocole KWP2000 (ISO 14230).
/// Utilisé principalement pour interroger les calculateurs des véhicules de génération K-Line/CAN anciens (ex: Scénic II).
@MainActor
final class KWP2000Client {
    private let interface: VehicleInterface
    private var testerPresentTask: Task<Void, Never>?
    
    /// Initialise le client avec l'interface véhicule active.
    init(interface: VehicleInterface) {
        self.interface = interface
    }
    
    /// Démarre une session de diagnostic KWP2000 (Service 10)
    /// - Parameter mode: Le mode de session (ex: 0x81 pour Standard, 0x85 pour Programmation)
    func startSession(mode: UInt8) async throws -> String {
        let hexMode = String(format: "%02X", mode)
        let command = "10" + hexMode
        let response = try await interface.sendDiagnosticRequest(command, timeout: 2.0)
        
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        // KWP2000 Negative Response : 7F 10 [NRC]
        if cleanResponse.hasPrefix("7F10") {
            throw KWP2000Error.negativeResponse(service: 0x10, response: cleanResponse)
        }
        
        // Réponse positive KWP2000 : 50 + Mode
        let expectedResponse = String(format: "50%02X", mode)
        guard cleanResponse.hasPrefix(expectedResponse) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedResponse, received: response)
        }
        
        // Activer le Tester Present périodique si nous sommes hors de la session standard (0x81)
        if mode != 0x81 {
            startTesterPresent()
        } else {
            stopTesterPresent()
        }
        
        return cleanResponse
    }
    
    /// Lit un paramètre local (LID) via le Service 21 (Read Data By Local Identifier)
    /// - Parameter lid: L'identifiant local sur 1 octet (0x00 à 0xFF)
    func readLocalIdentifier(lid: UInt8) async throws -> String {
        let hexLid = String(format: "%02X", lid)
        let command = "21" + hexLid
        let response = try await interface.sendDiagnosticRequest(command, timeout: 1.5)
        
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F21") {
            throw KWP2000Error.negativeResponse(service: 0x21, response: cleanResponse)
        }
        
        // Réponse positive KWP2000 : 61 + LID
        let expectedResponse = "61" + hexLid
        guard cleanResponse.hasPrefix(expectedResponse) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedResponse, received: response)
        }
        
        // Retourner la charge utile brute (sans le préfixe 61 LID)
        return String(cleanResponse.dropFirst(4))
    }
    
    /// Écrit un paramètre local (LID) via le Service 3B (Write Data By Local Identifier)
    /// - Parameters:
    ///   - lid: L'identifiant local sur 1 octet (0x00 à 0xFF)
    ///   - data: La charge utile à écrire sous forme hexadécimale
    func writeLocalIdentifier(lid: UInt8, data: String) async throws -> String {
        let hexLid = String(format: "%02X", lid)
        let cleanData = data.replacing(" ", with: "")
        let command = "3B" + hexLid + cleanData
        let response = try await interface.sendDiagnosticRequest(command, timeout: 2.0)
        
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F3B") {
            throw KWP2000Error.negativeResponse(service: 0x3B, response: cleanResponse)
        }
        
        // Réponse positive KWP2000 : 7B + LID
        let expectedResponse = "7B" + hexLid
        guard cleanResponse.hasPrefix(expectedResponse) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedResponse, received: response)
        }
        
        return cleanResponse
    }
    
    /// Arrête le maintien de session
    func stop() {
        stopTesterPresent()
    }
    
    // MARK: - Maintien de session (Tester Present)
    
    private func startTesterPresent() {
        testerPresentTask?.cancel()
        testerPresentTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard let self else { break }
                guard !Task.isCancelled else { break }
                
                // Envoyer Tester Present KWP2000 ("3E")
                _ = try? await self.interface.sendDiagnosticRequest("3E", timeout: 0.5)
            }
        }
    }
    
    private func stopTesterPresent() {
        testerPresentTask?.cancel()
        testerPresentTask = nil
    }
    
    deinit {
        testerPresentTask?.cancel()
    }
}

// MARK: - Erreurs KWP2000

enum KWP2000Error: LocalizedError {
    case negativeResponse(service: UInt8, response: String)
    case unexpectedResponse(expected: String, received: String)
    
    var errorDescription: String? {
        switch self {
        case .negativeResponse(let service, let response):
            let sHex = String(format: "%02X", service)
            return "Réponse négative KWP2000 (Service \(sHex)): \(response)"
        case .unexpectedResponse(let expected, let received):
            return "Réponse KWP2000 inattendue. Attendu: '\(expected)', Reçu: '\(received)'"
        }
    }
}
