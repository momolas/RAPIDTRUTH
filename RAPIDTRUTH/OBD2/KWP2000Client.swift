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
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x10, nrc: nrcByte)
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
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x21, nrc: nrcByte)
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
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x3B, nrc: nrcByte)
        }
        
        // Réponse positive KWP2000 : 7B + LID
        let expectedResponse = "7B" + hexLid
        guard cleanResponse.hasPrefix(expectedResponse) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedResponse, received: response)
        }
        
        return cleanResponse
    }
    
    /// Effectue la routine SecurityAccess (Service 27)
    /// - Parameters:
    ///   - level: Le niveau de sécurité demandé (impair pour demander le seed, ex: 0x01)
    ///   - keyCalculator: Une fermeture (closure) qui prend le seed brut sous forme de chaîne hexadécimale et calcule la clé correspondante.
    func performSecurityAccess(level: UInt8, keyCalculator: @Sendable (String) -> String) async throws {
        let requestSeedCmd = String(format: "27%02X", level)
        let seedResponse = try await interface.sendDiagnosticRequest(requestSeedCmd, timeout: 2.0)
        let cleanSeedResponse = seedResponse.replacing(" ", with: "").uppercased()

        if cleanSeedResponse.hasPrefix("7F27") {
            let nrcByte = UInt8(cleanSeedResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x27, nrc: nrcByte)
        }
        
        // Réponse positive attendue : 67 + level (ex: 67 01) + seed bytes
        let expectedPrefix = String(format: "67%02X", level)
        guard cleanSeedResponse.hasPrefix(expectedPrefix) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedPrefix, received: seedResponse)
        }
        
        // Extraire le seed
        let seedHex = String(cleanSeedResponse.dropFirst(4))
        
        // Calculer la clé via la closure passée
        let keyHex = keyCalculator(seedHex)
        
        // Envoyer la clé (le niveau est level + 1, ex: 0x02)
        let sendKeyLevel = level + 1
        let sendKeyCmd = String(format: "27%02X", sendKeyLevel) + keyHex
        let keyResponse = try await interface.sendDiagnosticRequest(sendKeyCmd, timeout: 2.0)
        let cleanKeyResponse = keyResponse.replacing(" ", with: "").uppercased()

        if cleanKeyResponse.hasPrefix("7F27") {
            let nrcByte = UInt8(cleanKeyResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x27, nrc: nrcByte)
        }
        
        let expectedKeyPrefix = String(format: "67%02X", sendKeyLevel)
        guard cleanKeyResponse.hasPrefix(expectedKeyPrefix) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedKeyPrefix, received: keyResponse)
        }
    }
    
    /// Accède aux paramètres temporels de l'ECU (Service 83)
    /// - Parameters:
    ///   - subFunction: La sous-fonction de timing (ex: 0x03 pour lire les paramètres actuels, 0x04 pour les définir)
    ///   - parameters: Paramètres temporels optionnels à définir (requis pour la sous-fonction 0x04)
    /// - Returns: Les paramètres temporels lus ou confirmés
    func accessTimingParameters(subFunction: UInt8, parameters: KWP2000TimingParameters? = nil) async throws -> KWP2000TimingParameters {
        let hexSub = String(format: "%02X", subFunction)
        var command = "83" + hexSub

        if subFunction == 0x04, let params = parameters {
            command += params.encode()
        }
        
        let response = try await interface.sendDiagnosticRequest(command, timeout: 2.0)
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F83") {
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x83, nrc: nrcByte)
        }
        
        let expectedPrefix = String(format: "C3%02X", subFunction)
        guard cleanResponse.hasPrefix(expectedPrefix) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedPrefix, received: response)
        }
        
        let dataPart = String(cleanResponse.dropFirst(4))
        guard let decoded = KWP2000TimingParameters.decode(from: dataPart) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedPrefix + " [5 octets de timing]", received: response)
        }
        
        return decoded
    }
    
    /// Démarre la communication KWP2000 (Service 81)
    /// - Returns: Les octets clés (Key Bytes) renvoyés par l'ECU si présents
    func startCommunication() async throws -> String {
        let command = "81"
        let response = try await interface.sendDiagnosticRequest(command, timeout: 2.0)
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F81") {
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x81, nrc: nrcByte)
        }
        
        // Réponse positive KWP2000 : C1 + Key Bytes (généralement 2 octets, ex: C1 EF 8F)
        guard cleanResponse.hasPrefix("C1") else {
            throw KWP2000Error.unexpectedResponse(expected: "C1", received: response)
        }
        
        return String(cleanResponse.dropFirst(2))
    }
    
    /// Arrête la communication KWP2000 (Service 82)
    func stopCommunication() async throws {
        let command = "82"
        let response = try await interface.sendDiagnosticRequest(command, timeout: 2.0)
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F82") {
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x82, nrc: nrcByte)
        }
        
        guard cleanResponse.hasPrefix("C2") else {
            throw KWP2000Error.unexpectedResponse(expected: "C2", received: response)
        }
    }
    
    /// Lit l'identification de l'ECU (Service 1A)
    /// - Parameter option: Option d'identification (ex: 0x80 à 0xBF)
    /// - Returns: Données d'identification brutes
    func readEcuIdentification(option: UInt8) async throws -> String {
        let hexOption = String(format: "%02X", option)
        let command = "1A" + hexOption
        let response = try await interface.sendDiagnosticRequest(command, timeout: 2.0)
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F1A") {
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x1A, nrc: nrcByte)
        }
        
        // Réponse positive KWP2000 : 5A + Option
        let expectedPrefix = "5A" + hexOption
        guard cleanResponse.hasPrefix(expectedPrefix) else {
            throw KWP2000Error.unexpectedResponse(expected: expectedPrefix, received: response)
        }
        
        return String(cleanResponse.dropFirst(4))
    }
    
    /// Efface les informations de diagnostic / DTC (Service 14)
    /// - Parameter group: Le groupe de DTC à effacer (généralement 0xFFFFFF pour tous les DTCs)
    func clearDiagnosticInformation(group: UInt32 = 0xFFFFFF) async throws {
        let hexGroup = String(format: "%06X", group)
        let command = "14" + hexGroup
        let response = try await interface.sendDiagnosticRequest(command, timeout: 3.0)
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F14") {
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x14, nrc: nrcByte)
        }
        
        // Réponse positive : 54
        guard cleanResponse.hasPrefix("54") else {
            throw KWP2000Error.unexpectedResponse(expected: "54", received: response)
        }
    }
    
    /// Lit les DTCs par statut (Service 18)
    /// - Parameters:
    ///   - statusMask: Le masque de statut des DTCs à lire (généralement 0xFF pour tous les DTCs)
    /// - Returns: La liste brute de réponse DTC
    func readDiagnosticTroubleCodesByStatus(statusMask: UInt8 = 0xFF) async throws -> String {
        let hexMask = String(format: "%02X", statusMask)
        let command = "1802" + hexMask + "FF00" // Forme courante chez Renault/KWP2000 pour lire par masque
        let response = try await interface.sendDiagnosticRequest(command, timeout: 3.0)
        let cleanResponse = response.replacing(" ", with: "").uppercased()
        
        if cleanResponse.hasPrefix("7F18") {
            let nrcByte = UInt8(cleanResponse.dropFirst(4).prefix(2), radix: 16) ?? 0
            throw KWP2000Error.negativeResponse(service: 0x18, nrc: nrcByte)
        }
        
        // Réponse positive : 58
        guard cleanResponse.hasPrefix("58") else {
            throw KWP2000Error.unexpectedResponse(expected: "58", received: response)
        }
        
        return cleanResponse
    }
    
    /// Arrête le maintien de session
    func stop() {
        stopTesterPresent()
    }
    
    // MARK: - Maintien de session (Tester Present)
    
    /// Envoie une trame TesterPresent (Service 3E)
    /// - Parameter suppressResponse: Si true, envoie 3E80 (pas de réponse attendue), sinon 3E00.
    func sendTesterPresent(suppressResponse: Bool = false) async throws {
        let command = suppressResponse ? "3E80" : "3E00"
        _ = try await interface.sendDiagnosticRequest(command, timeout: 1.0)
    }
    
    /// Démarre l'envoi régulier de TesterPresent en tâche de fond.
    /// - Parameters:
    ///   - interval: L'intervalle de temps entre chaque envoi (2.5s par défaut).
    ///   - suppressResponse: Si true, envoie 3E80 pour supprimer la réponse de l'ECU.
    func startTesterPresent(interval: TimeInterval = 2.5, suppressResponse: Bool = false) {
        testerPresentTask?.cancel()
        testerPresentTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(interval))
                    guard let self else { break }
                    let command = suppressResponse ? "3E80" : "3E00"
                    _ = try? await self.interface.sendDiagnosticRequest(command, timeout: 0.5)
                }
            } catch {
                // Arrêt coopératif lors de l'annulation
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

// MARK: - Structure TimingParameters

struct KWP2000TimingParameters: Sendable {
    let p2min: Double // en ms
    let p2max: Double // en ms
    let p3min: Double // en ms
    let p3max: Double // en ms
    let p4min: Double // en ms
    
    /// Décode les paramètres temporels à partir de la réponse brute KWP2000 (5 octets)
    static func decode(from hex: String) -> KWP2000TimingParameters? {
        let clean = hex.replacing(" ", with: "")
        guard clean.count >= 10 else { return nil }

        var bytes = [UInt8]()

        for i in stride(from: 0, to: 10, by: 2) {
            let start = clean.index(clean.startIndex, offsetBy: i)
            let end = clean.index(start, offsetBy: 2)
            if let byte = UInt8(clean[start..<end], radix: 16) {
                bytes.append(byte)
            } else {
                return nil
            }
        }
        
        guard bytes.count == 5 else { return nil }
        
        // Résolutions normalisées ISO 14230-3 :
        // P2min : 0.5 ms/unité
        // P2max : 25 ms/unité
        // P3min : 0.5 ms/unité
        // P3max : 250 ms/unité
        // P4min : 0.5 ms/unité
        return KWP2000TimingParameters(
            p2min: Double(bytes[0]) * 0.5,
            p2max: Double(bytes[1]) * 25.0,
            p3min: Double(bytes[2]) * 0.5,
            p3max: Double(bytes[3]) * 250.0,
            p4min: Double(bytes[4]) * 0.5
        )
    }
    
    /// Encode les paramètres temporels sous forme de chaîne hexadécimale (5 octets)
    func encode() -> String {
        let b1 = UInt8(clamping: Int((p2min / 0.5).rounded()))
        let b2 = UInt8(clamping: Int((p2max / 25.0).rounded()))
        let b3 = UInt8(clamping: Int((p3min / 0.5).rounded()))
        let b4 = UInt8(clamping: Int((p3max / 250.0).rounded()))
        let b5 = UInt8(clamping: Int((p4min / 0.5).rounded()))
        return String(format: "%02X%02X%02X%02X%02X", b1, b2, b3, b4, b5)
    }
}

// MARK: - Dictionnaire NRC (Negative Response Codes)

enum NRC: UInt8, Sendable {
    case generalReject = 0x10
    case serviceNotSupported = 0x11
    case subFunctionNotSupported = 0x12
    case incorrectMessageLengthOrInvalidFormat = 0x13
    case responseTooLong = 0x14
    case busyRepeatRequest = 0x21
    case conditionsNotCorrect = 0x22
    case requestSequenceError = 0x24
    case noResponseFromSubnetComponent = 0x25
    case failurePreventsExecutionOfRequestedAction = 0x26
    case requestOutOfRange = 0x31
    case securityAccessDenied = 0x33
    case invalidKey = 0x35
    case exceededNumberOfAttempts = 0x36
    case requiredTimeDelayNotExpired = 0x37
    case uploadDownloadNotAccepted = 0x70
    case transferDataSuspended = 0x71
    case generalProgrammingFailure = 0x72
    case wrongBlockSequenceCounter = 0x73
    case requestCorrectlyReceivedResponsePending = 0x78
    case subFunctionNotSupportedInActiveSession = 0x7E
    case serviceNotSupportedInActiveSession = 0x7F
    
    var description: String {
        switch self {
        case .generalReject: return "Reject Général (generalReject)"
        case .serviceNotSupported: return "Service Non Supporté (serviceNotSupported)"
        case .subFunctionNotSupported: return "Sous-fonction Non Supportée (subFunctionNotSupported)"
        case .incorrectMessageLengthOrInvalidFormat: return "Longueur Incorrecte ou Format Invalide (incorrectMessageLengthOrInvalidFormat)"
        case .responseTooLong: return "Réponse Trop Longue (responseTooLong)"
        case .busyRepeatRequest: return "Calculateur Occupé - Réessayer (busyRepeatRequest)"
        case .conditionsNotCorrect: return "Conditions Incorrectes (conditionsNotCorrect)"
        case .requestSequenceError: return "Erreur de Séquence de Requête (requestSequenceError)"
        case .noResponseFromSubnetComponent: return "Pas de Réponse du Composant Subnet (noResponseFromSubnetComponent)"
        case .failurePreventsExecutionOfRequestedAction: return "Échec empêchant l'exécution (failurePreventsExecutionOfRequestedAction)"
        case .requestOutOfRange: return "Requête Hors Limites (requestOutOfRange)"
        case .securityAccessDenied: return "Accès Sécurisé Refusé (securityAccessDenied)"
        case .invalidKey: return "Clé Invalide (invalidKey)"
        case .exceededNumberOfAttempts: return "Nombre de Tentatives Dépassé (exceededNumberOfAttempts)"
        case .requiredTimeDelayNotExpired: return "Délai d'Attente Requis Non Expiré (requiredTimeDelayNotExpired)"
        case .uploadDownloadNotAccepted: return "Upload/Download Refusé (uploadDownloadNotAccepted)"
        case .transferDataSuspended: return "Transfert de Données Suspendu (transferDataSuspended)"
        case .generalProgrammingFailure: return "Échec Général de Programmation (generalProgrammingFailure)"
        case .wrongBlockSequenceCounter: return "Compteur de Séquence de Bloc Incorrect (wrongBlockSequenceCounter)"
        case .requestCorrectlyReceivedResponsePending: return "Requête Reçue - Réponse En Attente (requestCorrectlyReceivedResponsePending)"
        case .subFunctionNotSupportedInActiveSession: return "Sous-fonction Non Supportée dans cette Session (subFunctionNotSupportedInActiveSession)"
        case .serviceNotSupportedInActiveSession: return "Service Non Supporté dans cette Session (serviceNotSupportedInActiveSession)"
        }
    }
    
    static func description(for nrcCode: UInt8) -> String {
        if let nrc = NRC(rawValue: nrcCode) {
            return nrc.description
        }
        return String(format: "NRC inconnu (0x%02X)", nrcCode)
    }
}

// MARK: - Erreurs KWP2000

enum KWP2000Error: LocalizedError {
    case negativeResponse(service: UInt8, nrc: UInt8)
    case unexpectedResponse(expected: String, received: String)
    
    var errorDescription: String? {
        switch self {
        case .negativeResponse(let service, let nrc):
            let sHex = String(format: "%02X", service)
            let nrcDesc = NRC.description(for: nrc)
            return "Réponse négative KWP2000 (Service \(sHex)): \(nrcDesc)"
        case .unexpectedResponse(let expected, let received):
            return "Réponse KWP2000 inattendue. Attendu: '\(expected)', Reçu: '\(received)'"
        }
    }
}
