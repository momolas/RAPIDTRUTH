import Foundation

/// UDSClient gère les séquences de diagnostic avancées via UDS (ISO 14229).
/// Il orchestre les requêtes complexes comme le déverrouillage de sécurité (Seed/Key)
/// et la lecture de mémoire (ReadMemoryByAddress).
@MainActor
class UDSClient {
    private let driver: PandaDriver
    
    init(driver: PandaDriver) {
        self.driver = driver
    }
    
    /// Tente de lire une portion de mémoire après avoir déverrouillé l'ECU.
    ///
    /// - Parameters:
    ///   - startAddress: L'adresse mémoire de départ (ex: 0x00000000)
    ///   - length: La taille en octets à lire.
    /// - Returns: Les données lues.
    func unlockAndReadMemory(startAddress: UInt32, length: UInt32) async throws -> Data {
        print("🏁 UDSClient: Début de la procédure de lecture mémoire (Adresse: \(String(format: "0x%08X", startAddress)), Taille: \(length) octets)")
        
        // 1. Diagnostic Session Control (0x10) - Extended Diagnostic Session (0x03) ou Programming (0x02)
        print("📡 Envoi de 'Start Diagnostic Session' (10 03)...")
        let sessionResponse = try await driver.sendDiagnosticRequest("1003", timeout: 2.0)
        guard sessionResponse.hasPrefix("5003") || sessionResponse.hasPrefix("50 03") else {
            throw NSError(domain: "UDSClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Échec du changement de session: \(sessionResponse)"])
        }
        print("✅ Session étendue activée.")
        
        // 2. Security Access (0x27) - Request Seed (0x01)
        print("📡 Envoi de 'Security Access - Request Seed' (27 01)...")
        let seedResponse = try await driver.sendDiagnosticRequest("2701", timeout: 2.0)
        
        let cleanedSeedResponse = seedResponse.replacingOccurrences(of: " ", with: "")
        guard cleanedSeedResponse.hasPrefix("6701") else {
            throw NSError(domain: "UDSClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Échec de la demande de Seed: \(seedResponse)"])
        }
        
        // Extraction du seed (les octets après '6701')
        let seedHex = String(cleanedSeedResponse.dropFirst(4))
        let seedBytes = dataFromHexString(seedHex).map { $0 }
        print("✅ Seed reçu: \(seedBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 3. Calcul de la clé
        let keyBytes = SecurityAccess.calculateKey(seed: seedBytes)
        let keyHex = keyBytes.map { String(format: "%02X", $0) }.joined()
        
        // 4. Security Access (0x27) - Send Key (0x02)
        print("📡 Envoi de 'Security Access - Send Key' (27 02 \(keyHex))...")
        let keyResponse = try await driver.sendDiagnosticRequest("2702" + keyHex, timeout: 2.0)
        let cleanedKeyResponse = keyResponse.replacingOccurrences(of: " ", with: "")
        
        guard cleanedKeyResponse.hasPrefix("6702") else {
            throw NSError(domain: "UDSClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "Échec du déverrouillage de sécurité: \(keyResponse)"])
        }
        print("🔓 ECU DÉVERROUILLÉ AVEC SUCCÈS !")
        
        // 5. Read Memory By Address (0x23)
        // Format typique: 23 [FormatIdentifier] [Address] [MemorySize]
        // Exemple avec des adresses sur 4 octets et des tailles sur 4 octets (FormatIdentifier = 0x44)
        let formatIdentifier = "44"
        let addressHex = String(format: "%08X", startAddress)
        let lengthHex = String(format: "%08X", length)
        
        let readRequest = "23" + formatIdentifier + addressHex + lengthHex
        print("📡 Envoi de 'Read Memory By Address' (\(readRequest))...")
        
        // Note: Pour une vraie lecture, il faudra gérer des tailles plus grandes en bouclant
        // sur des blocs (ex: 0x400 octets max par requête 0x23 selon l'ECU).
        let readResponse = try await driver.sendDiagnosticRequest(readRequest, timeout: 5.0)
        let cleanedReadResponse = readResponse.replacingOccurrences(of: " ", with: "")
        
        guard cleanedReadResponse.hasPrefix("63") else {
            throw NSError(domain: "UDSClient", code: 4, userInfo: [NSLocalizedDescriptionKey: "Échec de lecture mémoire: \(readResponse)"])
        }
        
        print("✅ Lecture mémoire terminée.")
        // On retire le byte de réponse positive (63)
        let payloadHex = String(cleanedReadResponse.dropFirst(2))
        return dataFromHexString(payloadHex)
    }
    
    private func dataFromHexString(_ hex: String) -> Data {
        var data = Data()
        var hexStr = hex.replacingOccurrences(of: " ", with: "")
        if hexStr.count % 2 != 0 { hexStr = "0" + hexStr }
        var i = hexStr.startIndex
        while i < hexStr.endIndex {
            let next = hexStr.index(i, offsetBy: 2)
            if let b = UInt8(hexStr[i..<next], radix: 16) {
                data.append(b)
            }
            i = next
        }
        return data
    }
}
