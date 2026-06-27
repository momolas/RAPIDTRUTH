import Foundation
import SwiftData

@Model
final class AuditRecord: Identifiable {
    var id: UUID = UUID()
    var vehicleSlug: String = ""
    var timestamp: Date = Date()
    var vinMoteur: String = ""
    var vinTDB: String = ""
    var vinUCH: String = ""
    var kmTDB: Int = 0
    var maxKmHistoriquePanne: Int = 0
    var riskLevel: String = ""
    var isVinConsistent: Bool = false
    var isKmTampered: Bool = false
    
    init(
        id: UUID = UUID(),
        vehicleSlug: String,
        timestamp: Date = Date(),
        vinMoteur: String = "",
        vinTDB: String = "",
        vinUCH: String = "",
        kmTDB: Int = 0,
        maxKmHistoriquePanne: Int = 0,
        riskLevel: String = "",
        isVinConsistent: Bool = false,
        isKmTampered: Bool = false
    ) {
        self.id = id
        self.vehicleSlug = vehicleSlug
        self.timestamp = timestamp
        self.vinMoteur = vinMoteur
        self.vinTDB = vinTDB
        self.vinUCH = vinUCH
        self.kmTDB = kmTDB
        self.maxKmHistoriquePanne = maxKmHistoriquePanne
        self.riskLevel = riskLevel
        self.isVinConsistent = isVinConsistent
        self.isKmTampered = isKmTampered
    }
}
