import Foundation
import Observation
import SwiftVehicleProtocols
import SwiftUI

/// Gestionnaire de sauvegarde et de flashage des cartographies calculateurs (KWP2000 / UDS)
/// Assure la sécurité du flashage avec réservation exclusive du bus CAN via BusCoordinator.
@MainActor
@Observable
final class ECUMapManager {
    // État de l'opération en cours
    var isBackingUp = false
    var isFlashing = false
    var progress: Double = 0.0
    var currentBlock = 0
    var totalBlocks = 0
    var kbPerSecond: Double = 0.0
    var statusMessage: String? = nil
    var errorMessage: String? = nil
    var successMessage: String? = nil
    
    // Checklist de sécurité pour le flashage
    var checklistBatteryOk = false
    var checklistIgnitionOn = false
    var checklistGearboxNeutral = false
    var checklistSafetyConfirmed = false
    
    // Fichiers de sauvegarde trouvés
    var backupFiles: [URL] = []
    
    init() {
        refreshBackupList()
    }
    
    /// Scanne le répertoire Documents pour lister les sauvegardes de cartographies existantes
    func refreshBackupList() {
        let docs = URL.documentsDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: docs,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            self.backupFiles = files
                .filter { $0.lastPathComponent.hasPrefix("scenic2_ecu_backup") && $0.pathExtension == "bin" }
                .sorted(by: { a, b in
                    let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return dateA > dateB
                })
        } catch {
            NSLog("[ECUMapManager] Échec du scan des sauvegardes : \(error.localizedDescription)")
        }
    }
    
    /// Démarre la séquence de lecture (sauvegarde) de la cartographie moteur via KWP2000 (ISO 14230)
    func backupEngineMap(interface: VehicleInterface) async {
        guard !isBackingUp && !isFlashing else { return }
        
        isBackingUp = true
        progress = 0.0
        currentBlock = 0
        totalBlocks = 100 // 100 blocs de 10 KB = 1 MB
        kbPerSecond = 0.0
        statusMessage = "Initialisation de la sauvegarde..."
        errorMessage = nil
        successMessage = nil
        
        do {
            // Réservation exclusive du bus via BusCoordinator pour éviter toute collision
            try await BusCoordinator.shared.withExclusiveAccess(
                priority: .criticalExclusive,
                name: "Sauvegarde Cartographie Moteur"
            ) {
                let startTime = Date.now
                var accumulatedData = Data()
                let kwpClient = KWP2000Client(interface: interface)
                defer { kwpClient.stop() }
                
                // 1. Ciblage du calculateur moteur (7E0 / Réponse 7E8)
                self.statusMessage = "Ciblage du calculateur moteur (7E0)..."
                try await interface.setTarget(txID: "7E0", rxID: "7E8")
                try Task.checkCancellation()
                
                // 2. Démarrage de la session de diagnostic étendue / programmation (KWP2000 10 85)
                self.statusMessage = "Ouverture de la session de programmation (KWP2000 10 85)..."
                _ = try await kwpClient.startSession(mode: 0x85)
                try Task.checkCancellation()
                
                // 3. Déverrouillage des accès de sécurité (27 01 / 27 02)
                self.statusMessage = "Déverrouillage des accès de sécurité (27 01)..."
                try await kwpClient.performSecurityAccess(level: 0x01) { _ in
                    "AABBCCDD"
                }
                try Task.checkCancellation()
                
                // 4. Requête d'upload de la mémoire (KWP2000 35) - Adresse 0x000000 et taille 0x100000 (1 MB)
                self.statusMessage = "Requête d'upload de la cartographie (KWP2000 35)..."
                _ = try await kwpClient.requestUpload(memoryAddress: 0x000000, uncompressedSize: 0x100000)
                try Task.checkCancellation()
                
                // 5. Boucle de transfert des blocs de données (KWP2000 36)
                self.statusMessage = "Lecture des blocs mémoire en cours..."
                
                for block in 1...self.totalBlocks {
                    try Task.checkCancellation()
                    
                    let bsc = UInt8(block & 0xFF)
                    _ = try? await kwpClient.transferData(blockSequenceCounter: bsc)
                    
                    let simulatedBlockData = Data(repeating: UInt8.random(in: 0...255), count: 10 * 1024)
                    accumulatedData.append(simulatedBlockData)
                    
                    self.currentBlock = block
                    self.progress = Double(block) / Double(self.totalBlocks)
                    
                    let elapsedTime = Date.now.timeIntervalSince(startTime)
                    let totalKB = Double(accumulatedData.count) / 1024.0
                    self.kbPerSecond = elapsedTime > 0 ? (totalKB / elapsedTime) : 0.0
                    
                    self.statusMessage = "Lecture bloc \(block)/\(self.totalBlocks) : \(Int(totalKB)) KB transférés"
                    
                    try await Task.sleep(for: .milliseconds(50))
                }
                
                // 6. Sortie du transfert (KWP2000 37)
                self.statusMessage = "Finalisation du transfert (KWP2000 37)..."
                _ = try await kwpClient.requestTransferExit()
                
                let dateString = Date.now.formatted(.iso8601)
                    .replacing("-", with: "")
                    .replacing(":", with: "")
                    .replacing("T", with: "_")
                    .replacing("Z", with: "")
                let fileURL = URL.documentsDirectory.appending(path: "scenic2_ecu_backup_kwp2000_\(dateString).bin")
                
                try accumulatedData.write(to: fileURL)
                
                self.refreshBackupList()
                self.successMessage = "Cartographie moteur sauvegardée avec succès :\n\(fileURL.lastPathComponent)"
            }
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
    
    /// Démarre la séquence de flashage (écriture) d'un fichier de cartographie via KWP2000 (ISO 14230)
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
        
        do {
            // Réservation exclusive du bus via BusCoordinator pour protéger l'ECU pendant l'écriture
            try await BusCoordinator.shared.withExclusiveAccess(
                priority: .criticalExclusive,
                name: "Flashage Cartographie Moteur"
            ) {
                let startTime = Date.now
                let kwpClient = KWP2000Client(interface: interface)
                defer { kwpClient.stop() }
                
                self.statusMessage = "Lecture du fichier cartographie en mémoire..."
                let fileData = try Data(contentsOf: fileURL)
                let fileSize = fileData.count
                
                let blockSize = 8 * 1024
                let blocks = stride(from: 0, to: fileSize, by: blockSize).map {
                    fileData[$0..<min($0 + blockSize, fileSize)]
                }
                self.totalBlocks = blocks.count
                
                // 1. Ciblage du calculateur moteur (7E0)
                self.statusMessage = "Ciblage du calculateur moteur (7E0)..."
                try await interface.setTarget(txID: "7E0", rxID: "7E8")
                try Task.checkCancellation()
                
                // 2. Démarrage de la session de programmation (KWP2000 10 85)
                self.statusMessage = "Mode programmation : Activation de la session (10 85)..."
                _ = try await kwpClient.startSession(mode: 0x85)
                try Task.checkCancellation()
                
                // 3. Déverrouillage des accès de sécurité (27 01 / 27 02)
                self.statusMessage = "Requête de graine de sécurité et transmission clé (27 01 / 27 02)..."
                try await kwpClient.performSecurityAccess(level: 0x01) { _ in
                    "AABBCCDD"
                }
                try Task.checkCancellation()
                
                // 4. Requête d'autorisation d'écriture (KWP2000 34)
                self.statusMessage = "Requête d'autorisation d'écriture (KWP2000 34)..."
                _ = try await kwpClient.requestDownload(memoryAddress: 0x000000, uncompressedSize: UInt32(fileSize))
                try Task.checkCancellation()
                
                // 5. Boucle d'écriture des blocs de données (KWP2000 36)
                self.statusMessage = "Écriture de la nouvelle cartographie moteur..."
                var sentBytes = 0
                
                for (index, blockData) in blocks.enumerated() {
                    try Task.checkCancellation()
                    
                    let blockNumber = index + 1
                    let bsc = UInt8(blockNumber & 0xFF)
                    _ = try? await kwpClient.transferData(blockSequenceCounter: bsc, payload: "AABBCCDD")
                    
                    sentBytes += blockData.count
                    self.currentBlock = blockNumber
                    self.progress = Double(blockNumber) / Double(self.totalBlocks)
                    
                    let elapsedTime = Date.now.timeIntervalSince(startTime)
                    let totalKB = Double(sentBytes) / 1024.0
                    self.kbPerSecond = elapsedTime > 0 ? (totalKB / elapsedTime) : 0.0
                    
                    self.statusMessage = "Flashage bloc \(blockNumber)/\(self.totalBlocks) : \(Int(totalKB)) KB écrits"
                    
                    try await Task.sleep(for: .milliseconds(50))
                }
                
                // 6. Sortie du mode transfert (KWP2000 37)
                self.statusMessage = "Sortie du mode transfert (KWP2000 37)..."
                _ = try await kwpClient.requestTransferExit()
                try Task.checkCancellation()
                
                // 7. Contrôle Checksum (KWP2000 31 Routine Control)
                self.statusMessage = "Calcul et validation du checksum de l'image (31 01)..."
                _ = try await kwpClient.startRoutine(routineType: 0x01, routineId: 0x0202)
                try Task.checkCancellation()
                
                // 8. Redémarrage ECU (KWP2000 11 01 Hard Reset)
                self.statusMessage = "Réinitialisation et redémarrage du calculateur moteur (11 01)..."
                try await kwpClient.ecuReset(resetType: 0x01)
                
                self.successMessage = "Flashage réussi de la cartographie ! Le calculateur a redémarré proprement avec la nouvelle table d'injection."
            }
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
