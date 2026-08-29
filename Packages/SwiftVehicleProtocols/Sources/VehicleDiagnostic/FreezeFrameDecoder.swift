import Foundation
import VehicleCore

public struct FreezeFrameData: Sendable {
    public let dtcCode: String
    public var timestampKm: Int?
    public var rpm: Double?
    public var coolantTemp: Double?
    public var vehicleSpeed: Double?
    public var batteryVoltage: Double?
    public var rawHex: String

    public init(
        dtcCode: String,
        timestampKm: Int? = nil,
        rpm: Double? = nil,
        coolantTemp: Double? = nil,
        vehicleSpeed: Double? = nil,
        batteryVoltage: Double? = nil,
        rawHex: String = ""
    ) {
        self.dtcCode = dtcCode
        self.timestampKm = timestampKm
        self.rpm = rpm
        self.coolantTemp = coolantTemp
        self.vehicleSpeed = vehicleSpeed
        self.batteryVoltage = batteryVoltage
        self.rawHex = rawHex
    }
}

public enum FreezeFrameDecoder: Sendable {
    public static func parseKWP(responseHex: String, dtcCode: String) -> FreezeFrameData {
        var freezeFrame = FreezeFrameData(dtcCode: dtcCode, rawHex: responseHex)
        guard let bytes = HexParsing.bytes(responseHex), bytes.count >= 4 else {
            return freezeFrame
        }

        // KWP Service 18 positive response: 0x58 [DTC_H] [DTC_L] [DATA...]
        if bytes[0] == 0x58 && bytes.count >= 7 {
            // Kilométrage sur 3 octets (bytes 3..5)
            let km = (Int(bytes[3]) << 16) | (Int(bytes[4]) << 8) | Int(bytes[5])
            if km > 0 && km < 2_000_000 {
                freezeFrame.timestampKm = km
            }

            // Régime moteur (bytes 6..7)
            if bytes.count >= 8 {
                let rpmRaw = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
                let rpm = Double(rpmRaw) / 4.0
                if rpm >= 0 && rpm <= 9000 {
                    freezeFrame.rpm = rpm
                }
            }

            // Température d'eau (byte 8)
            if bytes.count >= 9 {
                freezeFrame.coolantTemp = Double(bytes[8]) - 40.0
            }

            // Vitesse véhicule (byte 9)
            if bytes.count >= 10 {
                freezeFrame.vehicleSpeed = Double(bytes[9])
            }
        }

        return freezeFrame
    }
}
