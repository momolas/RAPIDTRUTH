import Foundation

struct VINDecoderResult: Equatable {
    let year: Int?
    let make: String
    let model: String
    let trim: String
    let fuelTypePrimary: String?
    let fuelTypeSecondary: String?
}

protocol VINDecodingService: Sendable {
    func decode(vin: String) async throws -> VINDecoderResult
}

@MainActor
func getActiveDecoderService() -> VINDecodingService {
    let settings = SettingsStore.shared
    if settings.vinDecoderAPI.lowercased() == "apiplaque" {
        return ApiPlaqueClient(token: settings.apiPlaqueToken)
    }
    return NHTSAClient()
}

func isValidVINFormat(_ candidate: String) -> Bool {
    guard candidate.count == 17 else { return false }
    let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
    return candidate.uppercased().unicodeScalars.allSatisfy { allowed.contains($0) }
}

func titleCase(_ value: String?) -> String {
    guard let value, !value.isEmpty else { return "" }
    return value
        .lowercased()
        .split(separator: " ")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}
