//
//  ECUDefinition.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import Foundation

// MARK: - Root
struct ECUDefinition: Codable {
    let obd: ECUObdInfo
    let devices: [ECUDTC]
    let ecuname: String
    let autoidents: [ECUAutoIdent]?
    let endian: String?
    let requests: [ECURequest]
    let data: [String: ECUDataItem]
}

// MARK: - OBD Info
struct ECUObdInfo: Codable {
    let fastinit: Bool?
    let funcname: String?
    let kw1: String?
    let kw2: String?
    let protocolName: String?
    let funcaddr: String?

    enum CodingKeys: String, CodingKey {
        case fastinit, funcname, kw1, kw2, funcaddr
        case protocolName = "protocol"
    }
}

// MARK: - DTC (Devices)
struct ECUDTC: Codable, Identifiable {
    var id: Int { dtc }
    let dtc: Int
    let dtctype: Int
    let name: String
    // devicedata is empty in example, using AnyCodable pattern or ignoring for now
}

// MARK: - Auto Ident
struct ECUAutoIdent: Codable {
    let diagversion: String?
    let supplier: String?
    let version: String?
    let soft: String?
}

// MARK: - Request
struct ECURequest: Codable, Identifiable {
    var id: String { name }
    let name: String
    let manualsend: Bool?
    let sentbytes: String
    let minbytes: Int?
    let replybytes: String?
    let receivebyte_dataitems: [String: ECUBinding]?
    let sendbyte_dataitems: [String: ECUBinding]?
    let deny_sds: [String]? // Using String for array elements based on empty array in example

    struct ECUBinding: Codable {
        let firstbyte: Int
        let bitoffset: Int?
        let ref: Bool?
    }
}

// MARK: - Data Definition
struct ECUDataItem: Codable {
    let scaled: Bool?
    let byte: Bool?
    let bytesascii: Bool?
    let signed: Bool?
    let bytescount: Int?
    let bitscount: Int?
    let divideby: Double?
    let step: Double?
    let offset: Double?
    let unit: String?
    let lists: [String: String]?

    // Helper to decode numeric keys in lists which are strings in JSON
    // e.g. "2": "Volume faible"
}
