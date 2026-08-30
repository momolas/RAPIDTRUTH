import Foundation
import Observation
import SwiftVehicleProtocols

/// Loads JSON profiles bundled into the app at build time. The profiles ship
/// from `../src/profiles/builtin/` (see `project.yml`), so they're identical
/// to the ones the web app uses.
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

    /// Heuristic: pick the first profile whose `vehicle_match` lists this
    /// make + (optional) model + (optional) year. Falls back to "generic_obd2".
    func suggestedProfile(make: String?, model: String? = nil, year: Int?) -> Profile {
        if let make = make?.lowercased() {
            // First pass: try to match both make and model if model is provided
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
            
            // Second pass: fallback to matching only make (and year)
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

        for url in entries where url.pathExtension.lowercased() == "json" {
            if url.lastPathComponent.hasPrefix("_") || url.lastPathComponent.hasPrefix("dtc_") { continue }
            
            do {
                let data = try Data(contentsOf: url)
                let baseId = url.deletingPathExtension().lastPathComponent

                // 1. Essai de décodage comme UnifiedECUProfile (Format Moderne OVD)
                if let uProfile = try? JSONDecoder().decode(UnifiedECUProfile.self, from: data) {
                    let legacy = UnifiedProfileConverter.toLegacyProfile(unified: uProfile, id: baseId)
                    if override || !seen.contains(legacy.profileId) {
                        outProfiles.append(legacy)
                        outUnified.append(uProfile)
                        seen.insert(legacy.profileId)
                    }
                    continue
                }

                // 2. Essai de décodage comme Profile (Format Hérité)
                if let legacy = try? JSONDecoder().decode(Profile.self, from: data) {
                    let uProfile = UnifiedProfileConverter.convert(legacyProfile: legacy)
                    if override || !seen.contains(legacy.profileId) {
                        outProfiles.append(legacy)
                        outUnified.append(uProfile)
                        seen.insert(legacy.profileId)
                    }
                    continue
                }

                // 3. Fallback DDT2000 brut
                if let parsedDDT = try? DDT2000Parser.parse(fileURL: url) {
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
