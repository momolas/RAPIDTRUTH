import Foundation

struct DBAutoIdent: Codable, Hashable {
    let supplier_code: String?
    let version: String?
    let diagnostic_version: String?
    let soft_version: String?
}

struct DatabaseECU: Codable, Hashable, Identifiable {
    var id: String { fileName }
    var fileName: String = "" // Injected after decoding

    let `protocol`: String?
    let autoidents: [DBAutoIdent]?
    let ecuname: String
    let address: String
    let group: String
    let projects: [String]

    enum CodingKeys: String, CodingKey {
        case `protocol`
        case autoidents
        case ecuname
        case address
        case group
        case projects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Optional decoding with fallbacks to prevent entire DB failure
        self.protocol = try container.decodeIfPresent(String.self, forKey: .protocol)
        self.autoidents = try container.decodeIfPresent([DBAutoIdent].self, forKey: .autoidents)
        self.ecuname = try container.decodeIfPresent(String.self, forKey: .ecuname) ?? "Unknown ECU"
        self.address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.group = try container.decodeIfPresent(String.self, forKey: .group) ?? "Misc"
        self.projects = try container.decodeIfPresent([String].self, forKey: .projects) ?? []
    }

    // Default init for manual creation if needed
    init(fileName: String, protocol: String?, autoidents: [DBAutoIdent]?, ecuname: String, address: String, group: String, projects: [String]) {
        self.fileName = fileName
        self.protocol = `protocol`
        self.autoidents = autoidents
        self.ecuname = ecuname
        self.address = address
        self.group = group
        self.projects = projects
    }
}
