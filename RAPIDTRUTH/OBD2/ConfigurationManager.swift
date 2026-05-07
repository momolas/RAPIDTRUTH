import Foundation
import Observation

@MainActor
@Observable
final class ConfigurationManager {
    // TdB
    var dashboardLanguage: String = "FR" // "FR" or "EN"
    var seatbeltWarning: Bool = true
    var clockDisplay: Bool = true
    var consumptionUnit: String = "L/100" // "L/100" or "KM/L"
    var overspeedWarning: Bool = false
    
    // UCH
    var autoLockDoors: Bool = true
    var autoRearWiper: Bool = true
    var followMeHome: Bool = false
    var oneTouchTurnSignal: Bool = true
    var deadlocking: Bool = false
    
    // RadNav
    var androidAuto: Bool = false
    var rearViewCamera: Bool = false
    
    var isReading = false
    var isWriting = false
    var actionError: String?
    var showSuccessMessage = false

    func readConfig(interface: VehicleInterface) async {
        isReading = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Read UCH config
            try await interface.setTarget(txID: "745", rxID: nil)
            let uchRes = try await interface.sendDiagnosticRequest("222100", timeout: 4.0)
            
            if uchRes.contains("62 21 00") {
                autoLockDoors = uchRes.contains("01")
                autoRearWiper = !uchRes.contains("NORW")
                followMeHome = uchRes.contains("FMH")
                oneTouchTurnSignal = !uchRes.contains("NOTS")
                deadlocking = uchRes.contains("DLK")
            }
            
            // Read TdB config
            try await interface.setTarget(txID: "743", rxID: nil)
            let tdbRes = try await interface.sendDiagnosticRequest("222101", timeout: 4.0)
            
            if tdbRes.contains("62 21 01") {
                dashboardLanguage = tdbRes.contains("EN") ? "EN" : "FR"
                seatbeltWarning = !tdbRes.contains("NOBEEP")
                clockDisplay = !tdbRes.contains("NOCLK")
                consumptionUnit = tdbRes.contains("KML") ? "KM/L" : "L/100"
                overspeedWarning = tdbRes.contains("120")
            }
            
            // Read RadNav config
            try await interface.setTarget(txID: "756", rxID: nil)
            let radNavRes = try await interface.sendDiagnosticRequest("222102", timeout: 4.0)
            
            if radNavRes.contains("62 21 02") {
                androidAuto = radNavRes.contains("AA")
                rearViewCamera = radNavRes.contains("RVC")
            }
            
        } catch {
            actionError = "Failed to read configuration: \(error.localizedDescription)"
        }
        
        isReading = false
    }

    func writeConfig(interface: VehicleInterface) async {
        isWriting = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Write UCH
            try await interface.setTarget(txID: "745", rxID: nil)
            let uchPayload1 = autoLockDoors ? "01" : "00"
            let uchPayload2 = autoRearWiper ? "" : "NORW"
            let uchPayload3 = followMeHome ? "FMH" : ""
            let uchPayload4 = oneTouchTurnSignal ? "" : "NOTS"
            let uchPayload5 = deadlocking ? "DLK" : ""
            _ = try await interface.sendDiagnosticRequest("2E2100\(uchPayload1)\(uchPayload2)\(uchPayload3)\(uchPayload4)\(uchPayload5)", timeout: 4.0)
            
            // Write TdB
            try await interface.setTarget(txID: "743", rxID: nil)
            let langPayload = dashboardLanguage == "EN" ? "EN" : "FR"
            let beepPayload = seatbeltWarning ? "BEEP" : "NOBEEP"
            let clkPayload = clockDisplay ? "CLK" : "NOCLK"
            let consPayload = consumptionUnit == "KM/L" ? "KML" : "L100"
            let overspeedPayload = overspeedWarning ? "120" : "000"
            _ = try await interface.sendDiagnosticRequest("2E2101\(langPayload)\(beepPayload)\(clkPayload)\(consPayload)\(overspeedPayload)", timeout: 4.0)
            
            // Write RadNav
            try await interface.setTarget(txID: "756", rxID: nil)
            let aaPayload = androidAuto ? "AA" : "NOAA"
            let rvcPayload = rearViewCamera ? "RVC" : "NORVC"
            _ = try await interface.sendDiagnosticRequest("2E2102\(aaPayload)\(rvcPayload)", timeout: 4.0)
            
            // Show success for 3 seconds
            showSuccessMessage = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                showSuccessMessage = false
            }
            
        } catch {
            actionError = "Failed to write configuration: \(error.localizedDescription)"
        }
        
        isWriting = false
    }
}
