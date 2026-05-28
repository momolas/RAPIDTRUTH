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
    var supportedDIDs: [String: [String]] = [:]
    var currentScanTarget: String = ""
    var actionError: String? = nil
    
    // Real-time correlation properties
    var correlations: [SliceCorrelation] = []
    var analyzedFrameCount: Int = 0
    private let correlator = SignalCorrelator()
    
    // We only use safe read services (Service 22: Read Data By Identifier)
    func fuzzService22(interface: VehicleInterface, ecu: String, startDid: Int, endDid: Int) async {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil
        results.removeAll()
        currentScanTarget = "ECU: \(ecu)"
        
        // Initialize or get the existing list of DIDs for this ECU
        if supportedDIDs[ecu] == nil {
            supportedDIDs[ecu] = []
        }
        
        let total = endDid - startDid + 1
        
        do {
            try await interface.setTarget(txID: ecu, rxID: nil)
            
            for i in 0..<total {
                try Task.checkCancellation()
                if !isRunning { break } // Allows cancellation
                
                let didValue = startDid + i
                let didString = String(format: "%04X", didValue)
                currentProgress = Float(i) / Float(total)
                
                // Send diagnostic request: 22 (Service) + DID
                let req = "22" + didString
                let resp = try await interface.sendDiagnosticRequest(req, timeout: 0.5)
                
                // Exclude NRC (7F)
                if !resp.isEmpty, !resp.hasPrefix("7F"), resp != "NO_DATA", !resp.contains("ERROR") {
                    // Valid response found
                    results.append(FuzzResult(did: didString, response: resp))
                    if !(supportedDIDs[ecu]?.contains(didString) ?? false) {
                        supportedDIDs[ecu]?.append(didString)
                    }
                }
                
                // Small delay to prevent CAN bus flooding
                try await Task.sleep(for: .milliseconds(20)) // 20ms
            }
        } catch is CancellationError {
            // Clean exit on cooperative task cancellation
        } catch {
            actionError = "Fuzzing stopped: \(error.localizedDescription)"
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
                
                // 1. Tester Present (UDS)
                let resp1 = try await interface.sendDiagnosticRequest("3E00", timeout: 0.2)
                if !resp1.isEmpty && !resp1.contains("ERROR") && resp1 != "NO_DATA" {
                    discoveredECUs.append(ecu)
                    continue
                }
                
                // 2. Read Supported PIDs (OBD-II) fallback
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
    
    func analyzeDIDCorrelation(interface: VehicleInterface, ecu: String, didHex: String) async {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil
        correlations.removeAll()
        analyzedFrameCount = 0
        correlator.reset()
        currentScanTarget = "Corrélation: \(didHex)"
        
        do {
            try await interface.setTarget(txID: ecu, rxID: nil)
            
            while isRunning {
                try Task.checkCancellation()
                if !isRunning { break }
                
                // 1. Query targeted UDS DID (Service 22)
                let req = "22" + didHex
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
        let clean = hex.replacingOccurrences(of: " ", with: "").uppercased()
        guard clean.hasPrefix("410C"), clean.count >= 8 else { return nil }
        guard let a = UInt8(clean.dropFirst(4).prefix(2), radix: 16),
              let b = UInt8(clean.dropFirst(6).prefix(2), radix: 16) else { return nil }
        return (Double(a) * 256.0 + Double(b)) / 4.0
    }
    
    private func decodeSpeed(_ hex: String) -> Double? {
        let clean = hex.replacingOccurrences(of: " ", with: "").uppercased()
        guard clean.hasPrefix("410D"), clean.count >= 6 else { return nil }
        guard let a = UInt8(clean.dropFirst(4).prefix(2), radix: 16) else { return nil }
        return Double(a)
    }
}
