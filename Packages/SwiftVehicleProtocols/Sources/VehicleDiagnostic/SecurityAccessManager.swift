import Foundation
import VehicleCore

public final class SecurityAccessManager: Sendable {
    public enum Algorithm: String, Sendable {
        case xorStatique
        case renaultStandard
        case comfortModule
    }

    public static func calculateKey(seedHex: String, algorithm: Algorithm, maskHex: String) -> String {
        guard let seed = HexParsing.bytes(seedHex), !seed.isEmpty else { return "" }
        let mask = HexParsing.bytes(maskHex) ?? []

        var keyBytes = [UInt8]()

        switch algorithm {
        case .xorStatique:
            for i in 0..<seed.count {
                let maskByte = mask.isEmpty ? 0x00 : mask[i % mask.count]
                keyBytes.append(seed[i] ^ maskByte)
            }

        case .renaultStandard:
            if seed.count >= 2 {
                let maskVal = mask.count >= 2 ? (UInt16(mask[0]) << 8 | UInt16(mask[1])) : 0xABCD
                let seedVal = UInt16(seed[0]) << 8 | UInt16(seed[1])
                let temp = (seedVal ^ maskVal)
                let calculated = (temp << 3) | (temp >> 13)
                keyBytes.append(UInt8((calculated >> 8) & 0xFF))
                keyBytes.append(UInt8(calculated & 0xFF))
            } else {
                keyBytes = seed
            }

        case .comfortModule:
            for i in 0..<seed.count {
                let b = seed[i]
                let m = mask.isEmpty ? 0x55 : mask[i % mask.count]
                keyBytes.append((b &+ m) ^ 0xAA)
            }
        }

        return HexParsing.hex(keyBytes)
    }
}
