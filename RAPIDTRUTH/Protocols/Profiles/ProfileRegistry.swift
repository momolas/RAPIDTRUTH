import Foundation
import Observation
import SwiftVehicleProtocols

/// Charge les profils JSON embarqués ou importés par l'utilisateur.
/// Tous les profils reposent désormais nativement sur le format déclaratif universel (UnifiedECUProfile).
@MainActor
@Observable
final class ProfileRegistry {

    private(set) var profiles: [Profile] = []
    private(set) var unifiedProfiles: [UnifiedECUProfile] = []
    private(set) var loadError: String?

    static let shared = ProfileRegistry()

    init() {
        load()
    }

    func profile(id: String) -> Profile? {
        profiles.first { $0.profileId == id }
    }

    func unifiedProfile(name: String) -> UnifiedECUProfile? {
        unifiedProfiles.first { $0.name.localizedCaseInsensitiveContains(name) }
    }

    /// Recommandation de profil par correspondance marque / modèle / année.
    func suggestedProfile(make: String?, model: String? = nil, year: Int?) -> Profile {
        if let make = make?.lowercased() {
            if let model = model?.lowercased(), !model.isEmpty {
                for p in profiles {
                    guard let match = p.vehicleMatch else { continue }
                    if let pmake = match.make?.lowercased(), pmake == make {
                        let modelMatches = match.models?.contains { $0.lowercased() == model } ?? false
                        if modelMatches {
                            if let year, let lo = match.yearMin, let hi = match.yearMax {
                                if year >= lo && year <= hi { return p }
                            } else {
                                return p
                            }
                        }
                    }
                }
            }
            
            for p in profiles {
                guard let match = p.vehicleMatch else { continue }
                if let pmake = match.make?.lowercased(), pmake == make {
                    if let year, let lo = match.yearMin, let hi = match.yearMax {
                        if year >= lo && year <= hi { return p }
                    } else {
                        return p
                    }
                }
            }
        }
        return profile(id: "generic_obd2") ?? profiles.first ?? Profile.fallback
    }

    func reload() {
        load()
    }

    // MARK: - Internals

    private func load() {
        loadError = nil
        var loadedProfiles: [Profile] = []
        var loadedUnified: [UnifiedECUProfile] = []
        var seenIDs: Set<String> = []

        // 1) Profils bundle intégrés
        if let bundledDir = Bundle.main.url(forResource: "builtin", withExtension: nil) {
            let (p, u) = loadJSONs(from: bundledDir, seen: &seenIDs)
            loadedProfiles.append(contentsOf: p)
            loadedUnified.append(contentsOf: u)
        } else {
            let (p, u) = loadJSONs(from: Bundle.main.bundleURL, seen: &seenIDs)
            if p.isEmpty {
                loadError = "Profiles directory missing from app bundle."
            } else {
                loadedProfiles.append(contentsOf: p)
                loadedUnified.append(contentsOf: u)
            }
        }

        // 2) Documents utilisateur (override)
        let userDir = AppStorage.shared.url(for: "profiles")
        if FileManager.default.fileExists(atPath: userDir.path) {
            let (userProfiles, userUnified) = loadJSONs(from: userDir, seen: &seenIDs, override: true)
            loadedProfiles.removeAll { existing in userProfiles.contains { $0.profileId == existing.profileId } }
            loadedProfiles.append(contentsOf: userProfiles)
            loadedUnified.append(contentsOf: userUnified)
        }

        // Tri stable : générique en premier, puis alphabétique
        loadedProfiles.sort { lhs, rhs in
            let lg = lhs.profileId.hasPrefix("generic_")
            let rg = rhs.profileId.hasPrefix("generic_")
            if lg != rg { return lg }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        if loadedProfiles.isEmpty && loadError == nil {
            loadError = "No valid profiles could be loaded."
        }

        profiles = loadedProfiles
        unifiedProfiles = loadedUnified
    }

    private func loadJSONs(
        from dir: URL,
        seen: inout Set<String>,
        override: Bool = false
    ) -> ([Profile], [UnifiedECUProfile]) {
        var outProfiles: [Profile] = []
        var outUnified: [UnifiedECUProfile] = []
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return (outProfiles, outUnified)
        }

        let decoder = JSONDecoder()

        for url in entries where url.pathExtension.lowercased() == "json" {
            if url.lastPathComponent.hasPrefix("_") || url.lastPathComponent.hasPrefix("dtc_") { continue }
            
            do {
                let data = try Data(contentsOf: url)
                let baseId = url.deletingPathExtension().lastPathComponent

                // Décodage direct du Schéma Déclaratif Universel (OVD)
                if let uProfile = try? decoder.decode(UnifiedECUProfile.self, from: data) {
                    let legacy = UnifiedProfileConverter.toLegacyProfile(unified: uProfile, id: baseId)
                    if override || !seen.contains(legacy.profileId) {
                        outProfiles.append(legacy)
                        outUnified.append(uProfile)
                        seen.insert(legacy.profileId)
                    }
                } else if let obdbProfile = try? OBDbImporter.convert(jsonData: data, vehicleName: baseId.replacingOccurrences(of: "_", with: " ").capitalized, profileId: baseId) {
                    // Importation transparente de profils OBDb multi-marques
                    let legacy = UnifiedProfileConverter.toLegacyProfile(unified: obdbProfile, id: baseId)
                    if override || !seen.contains(legacy.profileId) {
                        outProfiles.append(legacy)
                        outUnified.append(obdbProfile)
                        seen.insert(legacy.profileId)
                    }
                } else if let parsedDDT = try? DDT2000Parser.parse(fileURL: url) {
                    // Fallback rétrocompatible pour l'import de fichiers DDT2000 / PyRen
                    let uProfile = UnifiedProfileConverter.convert(legacyProfile: parsedDDT)
                    if override || !seen.contains(parsedDDT.profileId) {
                        outProfiles.append(parsedDDT)
                        outUnified.append(uProfile)
                        seen.insert(parsedDDT.profileId)
                    }
                }
            } catch {
                NSLog("Failed to parse \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (outProfiles, outUnified)
    }
}
