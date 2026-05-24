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
}
