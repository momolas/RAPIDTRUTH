import Foundation
import Observation

struct LINSniffedPacket: Identifiable, Sendable {
    var id: UInt8 { rawID }
    let rawID: UInt8
    let pid: UInt8
    var lastData: Data
    var packetCount: Int
    var lastTimestamp: Date
    var periodMs: Double
    var isClassicChecksumValid: Bool
    var isEnhancedChecksumValid: Bool
}

@MainActor
@Observable
final class LINFuzzer {
    var isRunning: Bool = false
    var currentProgress: Float = 0.0
    var currentScanTarget: String = ""
    var actionError: String? = nil
    
    var sniffedPackets: [UInt8: LINSniffedPacket] = [:]
    var discoveredPIDs: [UInt8] = []
    
    var sniffedPacketList: [LINSniffedPacket] {
        sniffedPackets.values.sorted { $0.rawID < $1.rawID }
    }
    
    private var scanTask: Task<Void, Never>?
    private var scanResponses: [UInt8: Data] = [:]
    
    // MARK: - Helpers
    
    /// Calcule le Protected Identifier (PID) LIN à partir d'un identifiant brut de 6 bits (0-63).
    static func protectedID(from rawID: UInt8) -> UInt8 {
        let id = rawID & 0x3F
        let id0 = (id >> 0) & 1
        let id1 = (id >> 1) & 1
        let id2 = (id >> 2) & 1
        let id3 = (id >> 3) & 1
        let id4 = (id >> 4) & 1
        let id5 = (id >> 5) & 1
        
        let p0 = id0 ^ id1 ^ id2 ^ id4
        let p1 = 1 ^ (id1 ^ id3 ^ id4 ^ id5)
        
        return id | (p0 << 6) | (p1 << 7)
    }
    
    /// Calcule le Checksum LIN (Classique ou Amélioré).
    static func calculateChecksum(pid: UInt8, data: Data, enhanced: Bool) -> UInt8 {
        guard !data.isEmpty else { return 0 }
        var sum: UInt32 = 0
        if enhanced {
            sum += UInt32(pid)
        }
        for byte in data {
            sum += UInt32(byte)
            if sum > 0xFF {
                sum = (sum & 0xFF) + 1
            }
        }
        return UInt8(~sum & 0xFF)
    }
    
    // MARK: - Passive Sniffing
    
    func startSniffing(driver: PandaDriver, uartPort: UInt16, baudRate: UInt32) async {
        stop()
        isRunning = true
        actionError = nil
        sniffedPackets.removeAll()
        currentScanTarget = "Sniffing passif LIN..."
        
        do {
            // Mode silencieux pour écoute passive uniquement
            try await driver.setSafetyModel(.silent)
            try await driver.configureLIN(uartPort: uartPort, baudRate: baudRate)
            
            driver.linFrameHandler = { [weak self] frame in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.processIncomingFrame(frame)
                }
            }
        } catch {
            actionError = "Erreur de configuration LIN : \(error.localizedDescription)"
            isRunning = false
        }
    }
    
    private func processIncomingFrame(_ frame: LINFrame) {
        let rawID = frame.rawID
        let pid = UInt8(frame.address & 0xFF)
        let now = Date()
        
        let isClassic = LINFuzzer.calculateChecksum(pid: pid, data: frame.data, enhanced: false) == 0
        let isEnhanced = LINFuzzer.calculateChecksum(pid: pid, data: frame.data, enhanced: true) == 0
        
        if var existing = sniffedPackets[rawID] {
            let interval = now.timeIntervalSince(existing.lastTimestamp) * 1000.0
            existing.lastData = frame.data
            existing.packetCount += 1
            existing.periodMs = interval
            existing.lastTimestamp = now
            existing.isClassicChecksumValid = isClassic
            existing.isEnhancedChecksumValid = isEnhanced
            sniffedPackets[rawID] = existing
        } else {
            sniffedPackets[rawID] = LINSniffedPacket(
                rawID: rawID,
                pid: pid,
                lastData: frame.data,
                packetCount: 1,
                lastTimestamp: now,
                periodMs: 0.0,
                isClassicChecksumValid: isClassic,
                isEnhancedChecksumValid: isEnhanced
            )
        }
    }
    
    // MARK: - Active PID Discovery Scan
    
    func startPIDScan(driver: PandaDriver, uartPort: UInt16, baudRate: UInt32) async {
        stop()
        isRunning = true
        actionError = nil
        discoveredPIDs.removeAll()
        sniffedPackets.removeAll()
        scanResponses.removeAll()
        currentScanTarget = "Balayage des 64 PIDs LIN..."
        
        let bus: UInt8 = uartPort == 1 ? 3 : 4
        
        do {
            // Requiert le mode ALLOUTPUT pour pouvoir envoyer les en-têtes Master
            try await driver.setSafetyModel(.allOutput)
            try await driver.configureLIN(uartPort: uartPort, baudRate: baudRate)
            
            driver.linFrameHandler = { [weak self] frame in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let pid = UInt8(frame.address & 0xFF)
                    let rawID = pid & 0x3F
                    if !frame.data.isEmpty {
                        self.scanResponses[rawID] = frame.data
                    }
                }
            }
            
            scanTask = Task {
                for rawID in UInt8(0)...UInt8(63) {
                    guard isRunning else { break }
                    
                    self.currentProgress = Float(rawID) / 64.0
                    let pid = LINFuzzer.protectedID(from: rawID)
                    
                    // Envoi d'une trame sans données = Master Header Request
                    try? await driver.sendLINFrame(bus: bus, address: UInt32(pid), data: Data())
                    
                    // Attente de la réponse de l'esclave
                    try? await Task.sleep(for: .milliseconds(50))
                    
                    if let responseData = self.scanResponses[rawID] {
                        self.discoveredPIDs.append(rawID)
                        self.processIncomingFrame(LINFrame(bus: bus, address: UInt32(pid), data: responseData))
                    }
                }
                
                self.isRunning = false
                self.currentProgress = 1.0
                driver.linFrameHandler = nil
            }
        } catch {
            actionError = "Erreur d'initialisation du scan : \(error.localizedDescription)"
            isRunning = false
        }
    }
    
    // MARK: - Frame Injection
    
    func injectFrame(driver: PandaDriver, uartPort: UInt16, baudRate: UInt32, rawID: UInt8, data: Data) async {
        actionError = nil
        let bus: UInt8 = uartPort == 1 ? 3 : 4
        let pid = LINFuzzer.protectedID(from: rawID)
        
        do {
            try await driver.setSafetyModel(.allOutput)
            try await driver.configureLIN(uartPort: uartPort, baudRate: baudRate)
            try await driver.sendLINFrame(bus: bus, address: UInt32(pid), data: data)
        } catch {
            actionError = "Injection échouée : \(error.localizedDescription)"
        }
    }
    
    func stop() {
        isRunning = false
        scanTask?.cancel()
        scanTask = nil
    }
}
