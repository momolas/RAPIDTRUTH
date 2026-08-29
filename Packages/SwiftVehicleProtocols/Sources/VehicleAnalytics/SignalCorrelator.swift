import Foundation
import VehicleCore

public enum SignalCorrelator: Sendable {
    public static func pearsonCorrelation(x: [Double], y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 1 else { return nil }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n

        var num = 0.0
        var denX = 0.0
        var denY = 0.0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }

        let den = sqrt(denX * denY)
        guard den > 1e-9 else { return 0.0 }
        return num / den
    }
}
