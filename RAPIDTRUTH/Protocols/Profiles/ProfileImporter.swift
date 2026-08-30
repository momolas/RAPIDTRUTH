import Foundation
import SwiftVehicleProtocols

/// Valide et enregistre un profil au format universel dans `Documents/profiles/`.
enum ProfileImporter {
    enum ImportError: LocalizedError {
        case unreadable(String)
        case invalidJSON(String)
        case missingFields(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let msg): return "Impossible de lire le fichier : \(msg)"
            case .invalidJSON(let msg): return "Format de profil invalide : \(msg)"
            case .missingFields(let msg): return "Champs obligatoires manquants : \(msg)"
            case .writeFailed(let msg): return "Échec de l'enregistrement : \(msg)"
            }
        }
    }

    /// Importe depuis une URL de fichier (Document Picker ou partage système).
    static func importProfile(from url: URL) throws -> Profile {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsScope { url.stopAccessingSecurityScopedResource() }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }

        let baseId = url.deletingPathExtension().lastPathComponent
        let uProfile: UnifiedECUProfile
        let legacyProfile: Profile

        // 1. Décodage du Schéma Déclaratif Universel (OVD)
        if let directUnified = try? JSONDecoder().decode(UnifiedECUProfile.self, from: data) {
            uProfile = directUnified
            legacyProfile = UnifiedProfileConverter.toLegacyProfile(unified: uProfile, id: baseId)
        } else if let obdbProfile = try? OBDbImporter.convert(jsonData: data, vehicleName: baseId.replacingOccurrences(of: "_", with: " ").capitalized, profileId: baseId) {
            // 2. Importation directe d'un signalset OBDb multi-marques
            uProfile = obdbProfile
            legacyProfile = UnifiedProfileConverter.toLegacyProfile(unified: uProfile, id: baseId)
        } else if let parsedLegacy = try? DDT2000Parser.parse(fileURL: url) {
            // 3. Fallback pour formats bruts DDT2000 / PyRen
            legacyProfile = parsedLegacy
            uProfile = UnifiedProfileConverter.convert(legacyProfile: legacyProfile)
        } else {
            throw ImportError.invalidJSON("Le fichier ne correspond ni au format universel OVD, ni à un signalset OBDb, ni à une base DDT2000 valide.")
        }

        guard !legacyProfile.pids.isEmpty else {
            throw ImportError.missingFields("Aucun PID / service trouvé dans le profil.")
        }

        // Sauvegarde canonique au format universel dans Documents/profiles/<profile_id>.json
        let target = "profiles/\(legacyProfile.profileId).json"
        do {
            try AppStorage.shared.ensureDir("profiles")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let canonical = try encoder.encode(uProfile)
            let dest = AppStorage.shared.url(for: target)
            try canonical.write(to: dest, options: .atomic)
        } catch {
            throw ImportError.writeFailed(error.localizedDescription)
        }

        return legacyProfile
    }
}
