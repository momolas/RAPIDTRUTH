import Foundation

enum LidPreset: String, CaseIterable, Identifiable {
    case all = "Exhaustif (00-FF)"
    case renault = "Renault Standard (01-AF)"
    case custom = "Personnalisé"
    
    var id: String { self.rawValue }
    
    var startHex: String {
        switch self {
        case .all: return "00"
        case .renault: return "01"
        case .custom: return ""
        }
    }
    
    var endHex: String {
        switch self {
        case .all: return "FF"
        case .renault: return "AF"
        case .custom: return ""
        }
    }
}
