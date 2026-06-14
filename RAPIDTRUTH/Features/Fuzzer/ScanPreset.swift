import Foundation

enum ScanPreset: String, CaseIterable, Identifiable {
    case rapid = "Rapide (Standard + Renault)"
    case standard11bit = "Exhaustif 11-bit (700-7EF)"
    case standard29bit = "Exhaustif 29-bit (18DAxxF1)"
    
    var id: String { self.rawValue }
}
