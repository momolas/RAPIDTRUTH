import Foundation
import Observation

/// Loads JSON profiles bundled into the app at build time. The profiles ship
/// from `../src/profiles/builtin/` (see `project.yml`), so they're identical
/// to the ones the web app uses.
@MainActor
@Observable
final class ProfileRegistry {

    private(set) var profiles: [Profile] = []
    private(set) var loadError: String?

    static let shared = ProfileRegistry()

    init() {
        load()
    }

    func profile(id: String) -> Profile? {
        profiles.first { $0.profileId == id }
    }

    /// Heuristic: pick the first profile whose `vehicle_match` lists this
    /// make + (optional) year. Falls back to "generic_obd2".
    func suggestedProfile(make: String?, year: Int?) -> Profile {
        if let make = make?.lowercased() {
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
        return profile(id: "generic_obd2") ?? profiles.first!
    }

    func reload() {
        load()
    }

    // MARK: - Internals

    private func load() {
        loadError = nil
        var loaded: [Profile] = []
        var seenIDs: Set<String> = []

        // 1) Bundled profiles. xcodegen ignores `name:` for folder-reference
        //    resources, so the bundle path is the last component of
        //    `path: ../src/profiles/builtin` → `builtin`.
        if let bundledDir = Bundle.main.url(forResource: "builtin", withExtension: nil) {
            loaded.append(contentsOf: loadJSONs(from: bundledDir, seen: &seenIDs))
        } else {
            // Fallback: If added without "Create folder references", files are in the root bundle
            let rootProfiles = loadJSONs(from: Bundle.main.bundleURL, seen: &seenIDs)
            if rootProfiles.isEmpty {
                loadError = "Profiles directory missing from app bundle. Run xcodegen."
            } else {
                loaded.append(contentsOf: rootProfiles)
            }
        }

        // 2) User-imported profiles in Documents/profiles/. These override
        //    bundled profiles with the same profile_id (so a user can swap
        //    in a tweaked version of a built-in).
        let userDir = AppStorage.shared.url(for: "profiles")
        if FileManager.default.fileExists(atPath: userDir.path) {
            // Re-load user profiles allowing them to take precedence over
            // bundled ones — pre-strip any bundled entries with the same id.
            let userProfiles = loadJSONs(from: userDir, seen: &seenIDs, override: true)
            loaded.removeAll { existing in userProfiles.contains { $0.profileId == existing.profileId } }
            loaded.append(contentsOf: userProfiles)
        }

        // Stable ordering: generic first, then alphabetical by display name.
        loaded.sort { lhs, rhs in
            let lg = lhs.profileId.hasPrefix("generic_")
            let rg = rhs.profileId.hasPrefix("generic_")
            if lg != rg { return lg }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        if loaded.isEmpty && loadError == nil {
            loadError = "No valid profiles could be loaded."
        }

        profiles = loaded
    }

    private func loadJSONs(
        from dir: URL,
        seen: inout Set<String>,
        override: Bool = false
    ) -> [Profile] {
        var out: [Profile] = []
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return out
        }
        for url in entries where url.pathExtension.lowercased() == "json" {
            // Skip the template marker file from community-profiles/.
            if url.lastPathComponent.hasPrefix("_") { continue }
            // Skip DTC language databases
            if url.lastPathComponent.hasPrefix("dtc_") { continue }
            var parsedProfile: Profile?
            do {
                let data = try Data(contentsOf: url)
                do {
                    parsedProfile = try JSONDecoder().decode(Profile.self, from: data)
                } catch {
                    // Fallback: try parsing as a DDT2000 JSON file
                    parsedProfile = try? DDT2000Parser.parse(fileURL: url)
                    if parsedProfile == nil { throw error }
                }
                
                if let profile = parsedProfile {
                    if override || !seen.contains(profile.profileId) {
                        out.append(profile)
                        seen.insert(profile.profileId)
                    }
                }
            } catch {
                NSLog("Failed to parse \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return out
    }
}
