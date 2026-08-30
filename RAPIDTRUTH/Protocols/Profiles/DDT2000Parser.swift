import Foundation
import SwiftVehicleProtocols

enum DDT2000Parser {
    /// Parses a RenoLink/PyREN JSON file and converts it into a `Profile`.
    static func parse(fileURL: URL) throws -> Profile {
        let data = try Data(contentsOf: fileURL)
        let unifiedProfile = try DDT2UnifiedConverter.convert(jsonData: data)
        return UnifiedProfileConverter.toLegacyProfile(unified: unifiedProfile)
    }
}
