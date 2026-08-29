import Foundation

public enum PidCategory: String, Sendable, Codable, CaseIterable {
    case engine = "engine"
    case speed = "speed"
    case temperature = "temperature"
    case electrical = "electrical"
    case fuel = "fuel"
    case air = "air"
    case pressure = "pressure"
    case other = "other"
}

public struct PidDef: Sendable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let ecu: String
    public let mode: String
    public let pid: String
    public let unit: String
    public let formula: String
    public let category: PidCategory

    public init(
        id: String,
        displayName: String,
        ecu: String,
        mode: String,
        pid: String,
        unit: String,
        formula: String,
        category: PidCategory = .other
    ) {
        self.id = id
        self.displayName = displayName
        self.ecu = ecu
        self.mode = mode
        self.pid = pid
        self.unit = unit
        self.formula = formula
        self.category = category
    }
}

public struct DTCDef: Sendable, Codable, Identifiable {
    public let id: String
    public let code: String
    public let description: String
    public let ecu: String
    public let status: String?

    public init(id: String, code: String, description: String, ecu: String, status: String? = nil) {
        self.id = id
        self.code = code
        self.description = description
        self.ecu = ecu
        self.status = status
    }
}

public struct CANFrame: Sendable {
    public let address: UInt32
    public let data: Data
    public let bus: UInt8

    public init(address: UInt32, data: Data, bus: UInt8 = 0) {
        self.address = address
        self.data = data
        self.bus = bus
    }
}
