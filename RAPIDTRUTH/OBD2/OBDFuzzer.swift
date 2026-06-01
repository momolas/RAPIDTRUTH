import Foundation
import Observation

struct FuzzResult: Identifiable {
    let id = UUID()
    let did: String
    let response: String
}

@MainActor
@Observable
final class OBDFuzzer {
    var isRunning: Bool = false
    var currentProgress: Float = 0.0
    var discoveredECUs: [String] = []
    var results: [FuzzResult] = []
    var supportedLIDs: [String: [String]] = [:]
    var currentScanTarget: String = ""
    var actionError: String? = nil
    
    // Real-time correlation properties
    var correlations: [SliceCorrelation] = []
    var analyzedFrameCount: Int = 0
    private let correlator = SignalCorrelator()
    
    /// Balaye les LIDs KWP2000 possibles (Service 21)
    func fuzzKWP2000LIDs(interface: VehicleInterface, ecu: String, startLid: Int = 0, endLid: Int = 255) async {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil
        results.removeAll()
        currentScanTarget = "KWP2000 ECU: \(ecu)"
        
        let total = endLid - startLid + 1
        
        // Initialize or get the existing list of LIDs for this ECU
        if supportedLIDs[ecu] == nil {
            supportedLIDs[ecu] = []
        }
        
        do {
            try await interface.setTarget(txID: ecu, rxID: nil)
            
            for lid in startLid...endLid {
                try Task.checkCancellation()
                if !isRunning { break }
                
                let lidString = String(format: "%02X", lid)
                currentProgress = Float(lid - startLid) / Float(total > 0 ? total : 1)
                
                // Commande KWP2000 ReadLocalIdentifier : 21 + LID
                let req = "21" + lidString
                let resp = try await interface.sendDiagnosticRequest(req, timeout: 0.3)
                
                let cleanResp = resp.replacing(" ", with: "").uppercased()
                if !cleanResp.isEmpty, !cleanResp.hasPrefix("7F"), cleanResp != "NO_DATA", !cleanResp.contains("ERROR") {
                    // Valid response found
                    results.append(FuzzResult(did: "LID \(lidString)", response: cleanResp))
                    if !(supportedLIDs[ecu]?.contains(lidString) ?? false) {
                        supportedLIDs[ecu]?.append(lidString)
                    }
                }
                
                // Small delay to prevent CAN/K-Line flooding
                try await Task.sleep(for: .milliseconds(15))
            }
        } catch is CancellationError {
            // Clean exit
        } catch {
            actionError = "Fuzzing KWP2000 arrêté: \(error.localizedDescription)"
        }
        
        isRunning = false
        currentProgress = 1.0
    }
    
    func scanNetwork(interface: VehicleInterface, range: [String]) async {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil
        discoveredECUs.removeAll()
        currentScanTarget = "Scan Réseau..."
        
        let total = range.count
        
        do {
            for (index, ecu) in range.enumerated() {
                try Task.checkCancellation()
                if !isRunning { break }
                
                currentProgress = Float(index) / Float(total)
                
                try await interface.setTarget(txID: ecu, rxID: nil)
                
                // 1. Tester Present (KWP2000)
                let respKwp = try await interface.sendDiagnosticRequest("3E", timeout: 0.2)
                if !respKwp.isEmpty && !respKwp.contains("ERROR") && respKwp != "NO_DATA" {
                    discoveredECUs.append(ecu)
                    continue
                }
                
                // 2. Tester Present (UDS) fallback
                let resp1 = try await interface.sendDiagnosticRequest("3E00", timeout: 0.2)
                if !resp1.isEmpty && !resp1.contains("ERROR") && resp1 != "NO_DATA" {
                    discoveredECUs.append(ecu)
                    continue
                }
                
                // 3. Read Supported PIDs (OBD-II) fallback
                let resp2 = try await interface.sendDiagnosticRequest("0100", timeout: 0.2)
                if !resp2.isEmpty && !resp2.contains("ERROR") && resp2 != "NO_DATA" {
                    discoveredECUs.append(ecu)
                }
                
                try await Task.sleep(for: .milliseconds(20))
            }
        } catch is CancellationError {
            // Clean exit on cooperative task cancellation
        } catch {
            actionError = "Scan arrêté: \(error.localizedDescription)"
        }
        
        isRunning = false
        currentProgress = 1.0
    }
    
    func cancel() {
        isRunning = false
    }
    
    // MARK: - Real-Time Correlation Analysis
    
    func analyzeLIDCorrelation(interface: VehicleInterface, ecu: String, lidHex: String) async {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil
        correlations.removeAll()
        analyzedFrameCount = 0
        correlator.reset()
        currentScanTarget = "Corrélation: LID \(lidHex)"
        
        do {
            try await interface.setTarget(txID: ecu, rxID: nil)
            
            while isRunning {
                try Task.checkCancellation()
                if !isRunning { break }
                
                // 1. Query targeted KWP2000 LID (Service 21)
                let req = "21" + lidHex
                guard let resp = try? await interface.sendDiagnosticRequest(req, timeout: 0.5),
                      !resp.isEmpty, !resp.hasPrefix("7F"), !resp.contains("ERROR"), resp != "NO_DATA" else {
                    try await Task.sleep(for: .milliseconds(100))
                    continue
                }
                
                // 2. Query standard OBD-II RPM (010C)
                var rpmVal = 0.0
                if let rpmResp = try? await interface.sendDiagnosticRequest("010C", timeout: 0.3),
                   let rpm = decodeRPM(rpmResp) {
                    rpmVal = rpm
                }
                
                // 3. Query standard OBD-II Speed (010D)
                var speedVal = 0.0
                if let speedResp = try? await interface.sendDiagnosticRequest("010D", timeout: 0.3),
                   let speed = decodeSpeed(speedResp) {
                    speedVal = speed
                }
                
                // 4. Update the correlator engine
                let results = correlator.record(hexResponse: resp, rpm: rpmVal, speed: speedVal)
                if !results.isEmpty {
                    self.correlations = results
                    self.analyzedFrameCount += 1
                }
                
                // 30ms inter-command delay to respect CAN bus
                try await Task.sleep(for: .milliseconds(30))
            }
        } catch is CancellationError {
            // Clean exit
        } catch {
            actionError = "Analyse arrêtée: \(error.localizedDescription)"
        }
        
        isRunning = false
    }
    
    private func decodeRPM(_ hex: String) -> Double? {
        let clean = hex.replacing(" ", with: "").uppercased()
        guard clean.hasPrefix("410C"), clean.count >= 8 else { return nil }
        guard let a = UInt8(clean.dropFirst(4).prefix(2), radix: 16),
              let b = UInt8(clean.dropFirst(6).prefix(2), radix: 16) else { return nil }
        return (Double(a) * 256.0 + Double(b)) / 4.0
    }
    
    private func decodeSpeed(_ hex: String) -> Double? {
        let clean = hex.replacing(" ", with: "").uppercased()
        guard clean.hasPrefix("410D"), clean.count >= 6 else { return nil }
        guard let a = UInt8(clean.dropFirst(4).prefix(2), radix: 16) else { return nil }
        return Double(a)
    }
}
