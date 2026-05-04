import Foundation
import Observation

@MainActor
@Observable
final class ConfigurationManager {
    var dashboardLanguage: String = "FR" // "FR" or "EN"
    var autoLockDoors: Bool = true
    var seatbeltWarning: Bool = true
    
    var isReading = false
    var isWriting = false
    var actionError: String?
    var showSuccessMessage = false

    func readConfig(elm: ELM327) async {
        isReading = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Read UCH config (Auto Lock Doors)
            // ATSH 745 (UCH), then we simulate 22 21 00
            _ = try await elm.send("ATSH745", timeout: 0.8)
            let uchRes = try await elm.send("222100", timeout: 4.0)
            
            // Expected mock response: 62 21 00 [Flags]
            // We'll mock that bit 0 of the first byte is autoLockDoors
            if uchRes.contains("62 21 00") {
                // If it ends with "01", it's true, else false. We'll simplify.
                autoLockDoors = uchRes.contains("01")
            }
            
            // Read TdB config (Language, Seatbelt)
            _ = try await elm.send("ATSH743", timeout: 0.8)
            let tdbRes = try await elm.send("222101", timeout: 4.0)
            
            if tdbRes.contains("62 21 01") {
                // Language mapping mock: "00" = FR, "01" = EN
                dashboardLanguage = tdbRes.contains("01") ? "EN" : "FR"
                seatbeltWarning = !tdbRes.contains("NOBEEP")
            }
            
        } catch {
            actionError = "Failed to read configuration: \(error.localizedDescription)"
        }
        
        isReading = false
    }

    func writeConfig(elm: ELM327) async {
        isWriting = true
        actionError = nil
        showSuccessMessage = false
        
        do {
            // Write UCH
            _ = try await elm.send("ATSH745", timeout: 0.8)
            let uchPayload = autoLockDoors ? "01" : "00"
            _ = try await elm.send("2E2100\(uchPayload)", timeout: 4.0)
            
            // Write TdB
            _ = try await elm.send("ATSH743", timeout: 0.8)
            let langPayload = dashboardLanguage == "EN" ? "01" : "00"
            let beepPayload = seatbeltWarning ? "BEEP" : "NOBEEP"
            _ = try await elm.send("2E2101\(langPayload)\(beepPayload)", timeout: 4.0)
            
            // Show success for 2 seconds
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
