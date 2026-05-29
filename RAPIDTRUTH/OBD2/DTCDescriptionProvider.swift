import Foundation

final class DTCDescriptionProvider: Sendable {
    static let shared = DTCDescriptionProvider()
    
    private let dtcMap: [String: String]
    private let genericDtcMap: [String: String]
    
    private init() {
        // 1. Load Renault-specific codes
        if let url = Bundle.main.url(forResource: "dtc_renault_fr", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            self.dtcMap = map
        } else {
            // Also try to find it in the bundle root or Resources directory
            let fileManager = FileManager.default
            let bundlePath = Bundle.main.bundlePath
            let possiblePaths = [
                "\(bundlePath)/dtc_renault_fr.json",
                "\(bundlePath)/Resources/dtc_renault_fr.json",
                "\(bundlePath)/RAPIDTRUTH/Profiles/dtc_renault_fr.json"
            ]
            
            var loadedMap: [String: String] = [:]
            for path in possiblePaths {
                if fileManager.fileExists(atPath: path),
                   let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                   let map = try? JSONDecoder().decode([String: String].self, from: data) {
                    loadedMap = map
                    break
                }
            }
            self.dtcMap = loadedMap
        }

        // 2. Load Generic OBD2 codes
        if let url = Bundle.main.url(forResource: "dtc_generic_en", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            self.genericDtcMap = map
        } else {
            let fileManager = FileManager.default
            let bundlePath = Bundle.main.bundlePath
            let possiblePaths = [
                "\(bundlePath)/dtc_generic_en.json",
                "\(bundlePath)/Resources/dtc_generic_en.json",
                "\(bundlePath)/RAPIDTRUTH/Profiles/dtc_generic_en.json"
            ]
            
            var loadedMap: [String: String] = [:]
            for path in possiblePaths {
                if fileManager.fileExists(atPath: path),
                   let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                   let map = try? JSONDecoder().decode([String: String].self, from: data) {
                    loadedMap = map
                    break
                }
            }
            self.genericDtcMap = loadedMap
        }
    }
    
    func description(for hexCode: String) -> String? {
        // e.g. "0104" or "9000"
        if let desc = dtcMap[hexCode] {
            return desc
        }
        
        // Fallback: decode hex to standard format (e.g. "0420" -> "P0420") and search generic mapping
        if let standardCode = decodeSingleDTC(hexCode) {
            if let desc = genericDtcMap[standardCode] {
                return desc
            }
        }
        
        return nil
    }

    private func decodeSingleDTC(_ hex: String) -> String? {
        guard hex.count == 4, let value = UInt16(hex, radix: 16) else { return nil }
        
        let highByte = UInt8((value >> 8) & 0xFF)
        let lowByte = UInt8(value & 0xFF)
        
        let typeMap = ["P", "C", "B", "U"]
        let typeIdx = Int((highByte >> 6) & 0b11)
        let type = typeMap[typeIdx]
        
        let digit1 = (highByte >> 4) & 0b11
        let digit2 = highByte & 0x0F
        let digit3 = (lowByte >> 4) & 0x0F
        let digit4 = lowByte & 0x0F
        
        return String(format: "%@%d%X%X%X", type, digit1, digit2, digit3, digit4)
    }
}
