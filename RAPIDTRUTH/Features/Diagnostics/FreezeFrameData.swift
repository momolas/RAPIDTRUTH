import Foundation

/// Données du Freeze Frame (Trame gelée / Contexte d'apparition d'un DTC)
public struct FreezeFrameData: Identifiable, Sendable, Equatable {
    public var id: String { triggerDTC + (rawHex.isEmpty ? UUID().uuidString : rawHex) }
    
    public let triggerDTC: String
    public let timestampKm: Int?
    public let rpm: Int?
    public let vehicleSpeed: Int?
    public let coolantTemp: Int?
    public let engineLoad: Double?
    public let intakePressureKPa: Int?
    public let intakeAirTemp: Int?
    public let fuelPressureKPa: Int?
    public let batteryVoltage: Double?
    public let throttlePosition: Double?
    public let rawHex: String
    public let additionalAttributes: [String: String]
    
    public init(
        triggerDTC: String,
        timestampKm: Int? = nil,
        rpm: Int? = nil,
        vehicleSpeed: Int? = nil,
        coolantTemp: Int? = nil,
        engineLoad: Double? = nil,
        intakePressureKPa: Int? = nil,
        intakeAirTemp: Int? = nil,
        fuelPressureKPa: Int? = nil,
        batteryVoltage: Double? = nil,
        throttlePosition: Double? = nil,
        rawHex: String = "",
        additionalAttributes: [String: String] = [:]
    ) {
        self.triggerDTC = triggerDTC
        self.timestampKm = timestampKm
        self.rpm = rpm
        self.vehicleSpeed = vehicleSpeed
        self.coolantTemp = coolantTemp
        self.engineLoad = engineLoad
        self.intakePressureKPa = intakePressureKPa
        self.intakeAirTemp = intakeAirTemp
        self.fuelPressureKPa = fuelPressureKPa
        self.batteryVoltage = batteryVoltage
        self.throttlePosition = throttlePosition
        self.rawHex = rawHex
        self.additionalAttributes = additionalAttributes
    }
}
