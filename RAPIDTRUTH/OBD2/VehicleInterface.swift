import Foundation

@MainActor
protocol VehicleInterface: AnyObject {
    /// Sets the target ECU's transmit ID (and optionally expects a specific receive ID).
    /// For ELM327, this maps to `ATSH`.
    func setTarget(txID: String, rxID: String?) async throws

    /// Sends a diagnostic payload (e.g., "17FF00") and waits for the response.
    func sendDiagnosticRequest(_ hexString: String, timeout: TimeInterval) async throws -> String
}

