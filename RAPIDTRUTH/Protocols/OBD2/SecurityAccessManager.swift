import Foundation

/// Gère le calcul des clés d'accès de sécurité (Service 27) pour les différents calculateurs (ECUs).
/// Implémente les algorithmes classiques de clés pour la génération Scenic II / Modus / Megane II.
public final class SecurityAccessManager: Sendable {
    
    /// Les différents algorithmes d'accès de sécurité couramment utilisés sur les calculateurs Renault.
    public enum Algorithm: String, Sendable {
        /// Algorithme XOR statique simple avec une clé de masque.
        case xorStatique
        
        /// Algorithme d'association standard Renault KWP2000 (Siemens/SAGEM).
        case renaultStandard
        
        /// Algorithme d'association pour les calculateurs de climatisation / UCH.
        case comfortModule
    }
    
    /// Calcule la clé de sécurité à partir d'un seed hexadécimal et d'un algorithme donné.
    /// - Parameters:
    ///   - seedHex: Le seed brut retourné par le calculateur (ex: "A1 B2")
    ///   - algorithm: L'algorithme de calcul à appliquer
    ///   - maskHex: Le masque ou la clé secrète associée au calculateur (ex: "4B D2")
    /// - Returns: La clé de sécurité calculée au format hexadécimal
    public static func calculateKey(seedHex: String, algorithm: Algorithm, maskHex: String) -> String {
        let seed = dataFromHexString(seedHex)
        let mask = dataFromHexString(maskHex)
        
        guard !seed.isEmpty else { return "" }
        
        var keyBytes = Data()
        
        switch algorithm {
        case .xorStatique:
            // Algorithme XOR simple : chaque octet du seed est combiné par XOR avec l'octet de masque correspondant (boucle)
            for i in 0..<seed.count {
                let maskByte = mask.isEmpty ? 0x00 : mask[i % mask.count]
                keyBytes.append(seed[i] ^ maskByte)
            }
            
        case .renaultStandard:
            // Algorithme d'association standard Renault (KWP2000)
            // Utilise généralement un seed de 2 ou 4 octets et combine les octets avec des décalages et masques
            if seed.count >= 2 {
                let maskVal = mask.count >= 2 ? UInt16(mask[0]) << 8 | UInt16(mask[1]) : 0xABCD
                let seedVal = UInt16(seed[0]) << 8 | UInt16(seed[1])
                
                // Formule de rotation et XOR classique Renault
                let temp = (seedVal ^ maskVal)
                let calculated = (temp << 3) | (temp >> 13) // Rotation gauche de 3 bits
                
                keyBytes.append(UInt8((calculated >> 8) & 0xFF))
                keyBytes.append(UInt8(calculated & 0xFF))
            } else {
                keyBytes = seed // Fallback
            }
            
        case .comfortModule:
            // Algorithme d'association d'habitacle/climatisation (UCH Siemens)
            // Effectue des opérations modulo et des additions sur les octets
            for i in 0..<seed.count {
                let maskByte = mask.isEmpty ? 0x55 : mask[i % mask.count]
                let calculated = (seed[i].addingReportingOverflow(maskByte).partialValue) ^ 0xAA
                keyBytes.append(calculated)
            }
        }
        
        return keyBytes.map { String(format: "%02X", $0) }.joined()
    }
    
    private static func dataFromHexString(_ hex: String) -> Data {
        var data = Data()
        let cleanHex = hex.replacingOccurrences(of: " ", with: "")
        var hexStr = cleanHex
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
