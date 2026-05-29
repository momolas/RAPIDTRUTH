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

struct FallbackVINDecoder: VINDecodingService {
    enum DecodeError: LocalizedError {
        case notConfigured
        
        var errorDescription: String? {
            return "Aucun décodeur VIN actif n'est configuré."
        }
    }
    
    func decode(vin: String) async throws -> VINDecoderResult {
        throw DecodeError.notConfigured
    }
}

@MainActor
func getActiveDecoderService(settings: SettingsStore) -> VINDecodingService {
    let api = settings.vinDecoderAPI.lowercased()
    if api == "apiplaque" {
        return ApiPlaqueClient(token: settings.apiPlaqueToken)
    } else if api == "autodev" {
        return AutoDevClient(apiKey: settings.autoDevToken)
    }
    return FallbackVINDecoder()
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
