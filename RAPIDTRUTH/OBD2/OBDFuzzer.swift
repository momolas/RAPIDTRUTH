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
    var currentScanTarget: String = ""
    var actionError: String? = nil
    
    // We only use safe read services (Service 22: Read Data By Identifier)
    func fuzzService22(interface: VehicleInterface, ecu: String, startDid: Int, endDid: Int) async {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil
        results.removeAll()
        currentScanTarget = "ECU: \(ecu)"
        
        let total = endDid - startDid + 1
        
        do {
            try await interface.setTarget(txID: ecu, rxID: nil)
            
            for i in 0..<total {
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
                }
                
                // Small delay to prevent CAN bus flooding
                try await Task.sleep(nanoseconds: 20_000_000) // 20ms
            }
        } catch {
            actionError = "Fuzzing stopped: \(error.localizedDescription)"
        }
        
        isRunning = false
        currentProgress = 1.0
    }
    
    func cancel() {
        isRunning = false
    }
}
