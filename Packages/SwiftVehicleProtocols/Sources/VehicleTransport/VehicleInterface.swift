import Foundation
import VehicleCore

public protocol VehicleInterface: Sendable {
    func sendRawCAN(id: UInt32, data: Data, bus: UInt8) async throws
    func sendDiagnosticRequest(_ requestHex: String, timeout: TimeInterval) async throws -> String
    func setTarget(txID: String, rxID: String?) async throws
}
