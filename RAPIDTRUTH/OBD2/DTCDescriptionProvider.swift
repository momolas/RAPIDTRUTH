import Foundation

final class DTCDescriptionProvider: Sendable {
    static let shared = DTCDescriptionProvider()
    
    private let dtcMap: [String: String]
    
    private init() {
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
    }
    
    func description(for hexCode: String) -> String? {
        // e.g. "0104" or "9000"
        return dtcMap[hexCode]
    }
}
