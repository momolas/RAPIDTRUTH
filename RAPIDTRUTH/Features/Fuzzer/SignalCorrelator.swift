import Foundation
import Observation

/// Représente le résultat d'une corrélation sur une tranche de données hexadécimales.
struct SliceCorrelation: Identifiable, Equatable {
    let id = UUID()
    let sliceName: String
    let referenceSignal: String
    let coefficient: Double
    let range: Double
    let classification: String

    static func == (lhs: SliceCorrelation, rhs: SliceCorrelation) -> Bool {
        lhs.sliceName == rhs.sliceName &&
        lhs.referenceSignal == rhs.referenceSignal &&
        lhs.coefficient == rhs.coefficient &&
        lhs.range == rhs.range &&
        lhs.classification == rhs.classification
    }
}

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
        
        // 2. Lancer les corrélations
        return calculateCorrelations()
    }

    private func calculateCorrelations() -> [SliceCorrelation] {
        guard !rawByteRows.isEmpty else { return [] }
        let nBytes = rawByteRows[0].count
        
        // S'assurer de la cohérence de taille des tampons de données
        let count = min(rawByteRows.count, rpmHistory.count, speedHistory.count)
        guard count >= 6 else {
            // Trop peu de données pour faire un calcul de Pearson statistiquement viable (minimum 6 trames)
            return []
        }
        
        let alignedRows = Array(rawByteRows.suffix(count))
        let alignedRpm = Array(rpmHistory.suffix(count))
        let alignedSpeed = Array(speedHistory.suffix(count))
        
        var slices: [String: [Double]] = [:]
        
        // Génération des tranches 8-bit (A, B, C...)
        let labels = (0..<nBytes).map { String(Character(UnicodeScalar(UInt8(65 + $0)))) }
        for i in 0..<nBytes {
            slices[labels[i]] = alignedRows.map { Double($0[i]) }
        }
        
        // Génération des tranches 16-bit Big-Endian (AB, BC...)
        for i in 0..<(nBytes - 1) {
            let label16 = "\(labels[i])\(labels[i+1])"
            slices[label16] = alignedRows.map { Double((Int($0[i]) << 8) | Int($0[i+1])) }
        }

        var results: [SliceCorrelation] = []

        for (sliceName, sVals) in slices {
            let sMin = sVals.min() ?? 0.0
            let sMax = sVals.max() ?? 0.0
            let sRange = sMax - sMin
            
            // Corrélation avec les RPM
            if let rRpm = pearson(sVals, alignedRpm) {
                let classification = classify(range: sRange, r: rRpm, refName: "RPM")
                results.append(SliceCorrelation(
                    sliceName: sliceName,
                    referenceSignal: "RPM",
                    coefficient: rRpm,
                    range: sRange,
                    classification: classification
                ))
            }
            
            // Corrélation avec la Vitesse
            if let rSpeed = pearson(sVals, alignedSpeed) {
                let classification = classify(range: sRange, r: rSpeed, refName: "Vitesse")
                results.append(SliceCorrelation(
                    sliceName: sliceName,
                    referenceSignal: "VITESSE",
                    coefficient: rSpeed,
                    range: sRange,
                    classification: classification
                ))
            }
        }
        
        // Trier en priorité absolue par force de corrélation
        return results.sorted { abs($0.coefficient) > abs($1.coefficient) }
    }

    /// Calcule le coefficient de corrélation linéaire de Pearson
    private func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        
        var num = 0.0
        var dx2 = 0.0
        var dy2 = 0.0
        
        for i in 0..<xs.count {
            let xDiff = xs[i] - mx
            let yDiff = ys[i] - my
            num += xDiff * yDiff
            dx2 += xDiff * xDiff
            dy2 += yDiff * yDiff
        }
        
        if dx2 == 0 || dy2 == 0 { return nil }
        return num / sqrt(dx2 * dy2)
    }

    /// Classification heuristique basée sur les résultats observés dans le script Python
    private func classify(range: Double, r: Double, refName: String) -> String {
        if range == 0 { return "MARKER (Constant)" }
        let absR = abs(r)
        if absR >= 0.75 {
            return "🔥 SIGNAL FORT (\(refName))"
        } else if absR >= 0.50 {
            return "⚡️ Signal potentiel (\(refName))"
        } else if range <= 5 {
            return "Compteur / Dérive"
        }
        return "—"
    }
}
