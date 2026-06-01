import Foundation
import SwiftData

@Model
final class Vehicle: Identifiable {
    var slug: String = ""
    var owner: String = ""
    var displayName: String = ""
    var year: Int?
    var make: String?
    var model: String?
    var trim: String?
    var vin: String?
    var profileId: String = ""
    var profileVersion: String = ""
    var createdAtUTC: String = ""
    var lastUsedUTC: String?
    var supportedStandardPIDs: [String] = []
    var supportedProfilePIDs: [String] = []
    var disabledPIDs: [String] = []

    var id: String { slug }

    init(
        slug: String,
        owner: String,
        displayName: String,
        year: Int? = nil,
        make: String? = nil,
        model: String? = nil,
        trim: String? = nil,
        vin: String? = nil,
        profileId: String,
        profileVersion: String,
        createdAtUTC: String,
        lastUsedUTC: String? = nil,
        supportedStandardPIDs: [String] = [],
        supportedProfilePIDs: [String] = [],
        disabledPIDs: [String] = []
    ) {
        self.slug = slug
        self.owner = owner
        self.displayName = displayName
        self.year = year
        self.make = make
        self.model = model
        self.trim = trim
        self.vin = vin
        self.profileId = profileId
        self.profileVersion = profileVersion
        self.createdAtUTC = createdAtUTC
        self.lastUsedUTC = lastUsedUTC
        self.supportedStandardPIDs = supportedStandardPIDs
        self.supportedProfilePIDs = supportedProfilePIDs
        self.disabledPIDs = disabledPIDs
    }

    static func makeSlug(year: Int?, make: String?, model: String?) -> String {
        var parts: [String] = []
        if let year = year, year > 0 { parts.append(String(year)) }
        if let make = make, !make.isEmpty { parts.append(make) }
        if let model = model, !model.isEmpty { parts.append(model) }
        let joined = parts.joined(separator: "-").lowercased()
        let cleaned = joined
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-")).inverted)
            .joined()
        // Collapse multiple dashes, trim leading/trailing.
        let collapsed = cleaned.replacing(try! Regex("-+"), with: "-")
        return String(collapsed.trimmingCharacters(in: .init(charactersIn: "-")).prefix(64))
    }

    static func makeDisplayName(year: Int?, make: String?, model: String?, trim: String?) -> String {
        var parts: [String] = []
        if let year = year, year > 0 { parts.append(String(year)) }
        if let make = make, !make.isEmpty { parts.append(make) }
        if let model = model, !model.isEmpty { parts.append(model) }
        if let trim = trim, !trim.isEmpty { parts.append(trim) }
        return parts.joined(separator: " ")
    }
}
