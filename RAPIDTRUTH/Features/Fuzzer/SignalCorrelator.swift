import Foundation
import Observation
import SwiftVehicleProtocols

/// Moteur de corrélation en temps réel calculant la corrélation linéaire de Pearson
/// entre des tranches de données candidates unilatérales (8-bit) ou bilatérales (16-bit)
/// et des signaux de télémétrie de référence (RPM / Vitesse).
@MainActor
@Observable
final class SignalCorrelator {
    private let maxBufferSize = 80 // Tampon glissant d'échantillons
    
    // Historique des signaux de référence
    private(set) var rpmHistory: [Double] = []
    private(set) var speedHistory: [Double] = []
    
    // Historique des trames brutes collectées pour le DID cible
    private var rawByteRows: [[UInt8]] = []

    /// Réinitialise l'historique d'acquisition pour démarrer une nouvelle corrélation.
    func reset() {
        rpmHistory.removeAll()
        speedHistory.removeAll()
        rawByteRows.removeAll()
    }

    /// Calcule le coefficient de corrélation linéaire de Pearson via SwiftVehicleProtocols
    static func pearsonCorrelation(x: [Double], y: [Double]) -> Double? {
        SwiftVehicleProtocols.SignalCorrelator.pearsonCorrelation(x: x, y: y)
    }

    /// Enregistre les références physiques courantes et la trame reçue du calculateur.
    /// Calcule instantanément les corrélations de Pearson pour chaque tranche.
    func record(hexResponse: String, rpm: Double, speed: Double) -> [SliceCorrelation] {
        guard let bytes = HexParsing.bytes(hexResponse), bytes.count >= 2 else {
            return []
        }
        
        // 1. Ajouter les données aux tampons circulaires
        rpmHistory.append(rpm)
        if rpmHistory.count > maxBufferSize { rpmHistory.removeFirst() }
        
        speedHistory.append(speed)
        if speedHistory.count > maxBufferSize { speedHistory.removeFirst() }
        
        rawByteRows.append(bytes)
        if rawByteRows.count > maxBufferSize { rawByteRows.removeFirst() }
        
        // 2. Déléguer le calcul vectoriel au package SwiftVehicleProtocols
        return SwiftVehicleProtocols.SignalCorrelator.correlateSlices(
            byteRows: rawByteRows,
            references: [
                "RPM": rpmHistory,
                "Vitesse": speedHistory
            ],
            minimumSamples: 6
        )
    }
}
