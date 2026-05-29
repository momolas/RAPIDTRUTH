import Foundation
import SwiftData

@Model
final class SessionRecord: Identifiable {
    @Attribute(.unique) var sessionID: String
    var startUTC: String
    var endUTC: String
    var durationMs: Int
    var sampleRateHz: Double
    var rowCount: Int
    var profileID: String
    var profileVersion: String
    var pidCount: Int
    var file: String
    var endedReason: String
    var meanPidCompletionPct: Double
    var rawMode: Bool

    var vehicle: Vehicle?

    var id: String { sessionID }

    init(
        sessionID: String,
        startUTC: String,
        endUTC: String,
        durationMs: Int,
        sampleRateHz: Double,
        rowCount: Int,
        profileID: String,
        profileVersion: String,
        pidCount: Int,
        file: String,
        endedReason: String,
        meanPidCompletionPct: Double,
        rawMode: Bool,
        vehicle: Vehicle? = nil
    ) {
        self.sessionID = sessionID
        self.startUTC = startUTC
        self.endUTC = endUTC
        self.durationMs = durationMs
        self.sampleRateHz = sampleRateHz
        self.rowCount = rowCount
        self.profileID = profileID
        self.profileVersion = profileVersion
        self.pidCount = pidCount
        self.file = file
        self.endedReason = endedReason
        self.meanPidCompletionPct = meanPidCompletionPct
        self.rawMode = rawMode
        self.vehicle = vehicle
    }
}

enum SessionID {
    /// 8-char Crockford-style ID; matches the format used by the web app.
    static func generate() -> String {
        let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")
        var bytes = [UInt8](repeating: 0, count: 5)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        var out = ""
        for b in bytes {
            out.append(alphabet[Int(b) % alphabet.count])
        }
        // Pad to 8 characters with random alphabet chars.
        for _ in 0..<3 {
            out.append(alphabet[Int.random(in: 0..<alphabet.count)])
        }
        return out
    }

    static func sessionFilename(startISO: String, sessionID: String) -> String {
        let safe = startISO.replacing(":", with: "-")
        let stripped = safe.replacing(try! Regex("\\.\\d{3}Z"), with: "Z")
        return "\(stripped)__\(sessionID).csv"
    }
}
