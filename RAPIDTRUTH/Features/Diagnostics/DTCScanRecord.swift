import Foundation
import SwiftData

@Model
final class DTCScanRecord: Identifiable {
    var id: UUID = UUID()
    var vehicleSlug: String = ""
    var timestamp: Date = Date()
    var codes: [String] = []
    var ecus: [String] = []
    
    init(
        id: UUID = UUID(),
        vehicleSlug: String,
        timestamp: Date = Date(),
        codes: [String],
        ecus: [String]
    ) {
        self.id = id
        self.vehicleSlug = vehicleSlug
        self.timestamp = timestamp
        self.codes = codes
        self.ecus = ecus
    }
}
