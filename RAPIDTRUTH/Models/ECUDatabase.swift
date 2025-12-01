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
}
