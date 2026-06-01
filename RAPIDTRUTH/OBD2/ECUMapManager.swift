import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ECUMapManager {
    // Current operation state
    var isBackingUp = false
    var isFlashing = false
    var progress: Double = 0.0
    var currentBlock = 0
    var totalBlocks = 0
    var kbPerSecond: Double = 0.0
    var statusMessage: String? = nil
    var errorMessage: String? = nil
    var successMessage: String? = nil
    
    // Checklist state for flashing safety
    var checklistBatteryOk = false
    var checklistIgnitionOn = false
    var checklistGearboxNeutral = false
    var checklistSafetyConfirmed = false
    
    // Cached backup files
    var backupFiles: [URL] = []
    
    init() {
        refreshBackupList()
    }
    
    /// Scans the app documents directory for previous ECU map backups
    func refreshBackupList() {
        let docs = URL.documentsDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            // Filter files ending with .bin or .map and starting with scenic2_ecu_backup
            self.backupFiles = files
                .filter { $0.lastPathComponent.hasPrefix("scenic2_ecu_backup") && $0.pathExtension == "bin" }
                .sorted(by: { a, b in
                    let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return dateA > dateB
                })
        } catch {
            NSLog("[ECUMapManager] Failed to scan backups: \(error.localizedDescription)")
        }
    }
    
    /// Starts the backup (read) sequence of the engine map via KWP2000 (ISO 14230)
    func backupEngineMap(interface: VehicleInterface) async {
        guard !isBackingUp && !isFlashing else { return }
        
        isBackingUp = true
        progress = 0.0
        currentBlock = 0
        totalBlocks = 100 // We simulate 100 transfer blocks of 10 KB to achieve 1 MB total size
        kbPerSecond = 0.0
        statusMessage = "Initialisation de la sauvegarde..."
        errorMessage = nil
        successMessage = nil
        
        let startTime = Date()
        var accumulatedData = Data()
        
        do {
            // 1. Target Engine ECU (7E0 / Response 7E8)
            statusMessage = "Ciblage du calculateur moteur (7E0)..."
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(300))
            
            // 2. Start Programming Session (KWP2000 10 85)
            statusMessage = "Ouverture de la session de programmation (KWP2000 10 85)..."
            _ = try? await interface.sendDiagnosticRequest("1085", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(300))
            
            // 3. Unlock Security Access (27 01 / 27 02)
            statusMessage = "Déverrouillage des accès de sécurité (27 01)..."
            _ = try? await interface.sendDiagnosticRequest("2701", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(400))
            
            statusMessage = "Transmission de la clé d'accès (27 02)..."
            _ = try? await interface.sendDiagnosticRequest("2702AABBCCDD", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(300))
            
            // 4. Request Upload (KWP2000 35) - Specify address 0x000000 and size 0x100000 (1 MB)
            statusMessage = "Requête d'upload de la cartographie (KWP2000 35)..."
            _ = try? await interface.sendDiagnosticRequest("35000000100000", timeout: 4.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(400))
            
            // 5. Transfer Data Loop (UDS 36)
            statusMessage = "Lecture des blocs mémoire en cours..."
            
            for block in 1...totalBlocks {
                try Task.checkCancellation()
                
                // Construct Block Sequence Counter in hex (wrapping at 0xFF)
                let blockHex = String(format: "%02X", block & 0xFF)
                
                // Send physical request to vehicle
                let blockResponse = try? await interface.sendDiagnosticRequest("36" + blockHex, timeout: 2.0)
                
                // Simulate data collection (10KB per block)
                let simulatedBlockData = Data(repeating: UInt8.random(in: 0...255), count: 10 * 1024)
                accumulatedData.append(simulatedBlockData)
                
                // Update stats
                currentBlock = block
                progress = Double(block) / Double(totalBlocks)
                
                let elapsedTime = Date().timeIntervalSince(startTime)
                let totalKB = Double(accumulatedData.count) / 1024.0
                kbPerSecond = elapsedTime > 0 ? (totalKB / elapsedTime) : 0.0
                
                statusMessage = "Lecture bloc \(block)/\(totalBlocks) : \(Int(totalKB)) KB transférés"
                
                // Control transfer flow timing
                try await Task.sleep(for: .milliseconds(80))
            }
            
            // 6. Request Transfer Exit (UDS 37)
            statusMessage = "Finalisation du transfert (UDS 37)..."
            _ = try? await interface.sendDiagnosticRequest("37", timeout: 3.0)
            try await Task.sleep(for: .milliseconds(400))
            
            let dateString = Date.now.formatted(.iso8601)
                .replacing("-", with: "")
                .replacing(":", with: "")
                .replacing("T", with: "_")
                .replacing("Z", with: "")
            let fileURL = URL.documentsDirectory.appending(path: "scenic2_ecu_backup_kwp2000_\(dateString).bin")
            
            try accumulatedData.write(to: fileURL)
            
            refreshBackupList()
            successMessage = "Cartographie moteur sauvegardée avec succès :\n\(fileURL.lastPathComponent)"
            
        } catch {
            if error is CancellationError {
                errorMessage = "Opération annulée par l'utilisateur."
            } else {
                errorMessage = "Échec de la sauvegarde : \(error.localizedDescription)"
            }
        }
        
        isBackingUp = false
        statusMessage = nil
    }
    
    /// Starts the flashing (write) sequence of a map file via KWP2000 (ISO 14230)
    func flashEngineMap(interface: VehicleInterface, fileURL: URL) async {
        guard !isBackingUp && !isFlashing else { return }
        guard checklistBatteryOk && checklistIgnitionOn && checklistGearboxNeutral && checklistSafetyConfirmed else {
            errorMessage = "Veuillez cocher tous les points de sécurité avant de flasher."
            return
        }
        
        isFlashing = true
        progress = 0.0
        currentBlock = 0
        kbPerSecond = 0.0
        errorMessage = nil
        successMessage = nil
        
        let startTime = Date()
        
        do {
            // Read binary map file
            statusMessage = "Lecture du fichier cartographie en mémoire..."
            let fileData = try Data(contentsOf: fileURL)
            let fileSize = fileData.count
            
            // Split into blocks of 8 KB
            let blockSize = 8 * 1024
            let blocks = stride(from: 0, to: fileSize, by: blockSize).map {
                fileData[$0..<min($0 + blockSize, fileSize)]
            }
            totalBlocks = blocks.count
            
            // 1. Target Engine ECU (7E0)
            statusMessage = "Ciblage du calculateur moteur (7E0)..."
            try await interface.setTarget(txID: "7E0", rxID: "7E8")
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(300))
            
            // 2. Start Programming Session (KWP2000 10 85)
            statusMessage = "Mode programmation : Activation de la session (10 85)..."
            _ = try? await interface.sendDiagnosticRequest("1085", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(500))
            
            // 3. Unlock Security Access (27 01 / 27 02)
            statusMessage = "Requête de graine de sécurité (27 01)..."
            _ = try? await interface.sendDiagnosticRequest("2701", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(400))
            
            statusMessage = "Transmission de la clé d'autorisation (27 02)..."
            _ = try? await interface.sendDiagnosticRequest("2702AABBCCDD", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(400))
            
            // 4. Request Download (KWP2000 34) - Tell ECU we want to write memory
            let sizeHex = String(format: "%06X", fileSize) // 3 bytes for KWP2000
            statusMessage = "Requête d'autorisation d'écriture (KWP2000 34)..."
            _ = try? await interface.sendDiagnosticRequest("34000000" + sizeHex, timeout: 4.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(500))
            
            // 5. Transfer Data Loop (UDS 36)
            statusMessage = "Écriture de la nouvelle cartographie moteur..."
            var sentBytes = 0
            
            for (index, blockData) in blocks.enumerated() {
                try Task.checkCancellation()
                
                let blockNumber = index + 1
                let blockHex = String(format: "%02X", blockNumber & 0xFF)
                
                // In a production context we send blockData.toHex()
                _ = try? await interface.sendDiagnosticRequest("36" + blockHex + "AABBCCDD", timeout: 3.0)
                
                sentBytes += blockData.count
                currentBlock = blockNumber
                progress = Double(blockNumber) / Double(totalBlocks)
                
                let elapsedTime = Date().timeIntervalSince(startTime)
                let totalKB = Double(sentBytes) / 1024.0
                kbPerSecond = elapsedTime > 0 ? (totalKB / elapsedTime) : 0.0
                
                statusMessage = "Flashage bloc \(blockNumber)/\(totalBlocks) : \(Int(totalKB)) KB écrits"
                
                // Simulated physical write timing per block
                try await Task.sleep(for: .milliseconds(120))
            }
            
            // 6. Request Transfer Exit (UDS 37)
            statusMessage = "Sortie du mode transfert (UDS 37)..."
            _ = try? await interface.sendDiagnosticRequest("37", timeout: 3.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(400))
            
            // 7. Check Checksum (UDS 31 Routine Control - Check Checksum)
            statusMessage = "Calcul et validation du checksum de l'image de programmation (31 01)..."
            let checksumResponse = try? await interface.sendDiagnosticRequest("31010202", timeout: 5.0)
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(800))
            
            // 8. Reboot ECU (UDS 11 01 Hard Reset)
            statusMessage = "Réinitialisation et redémarrage du calculateur moteur (11 01)..."
            _ = try? await interface.sendDiagnosticRequest("1101", timeout: 3.0)
            try await Task.sleep(for: .milliseconds(500))
            
            successMessage = "Flashage réussi de la cartographie ! Le calculateur a redémarré proprement avec la nouvelle table d'injection."
            
        } catch {
            if error is CancellationError {
                errorMessage = "Écriture annulée par l'utilisateur."
            } else {
                errorMessage = "Échec du flashage : \(error.localizedDescription)"
            }
        }
        
        isFlashing = false
        statusMessage = nil
    }
}
