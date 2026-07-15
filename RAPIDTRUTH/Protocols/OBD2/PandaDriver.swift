import Foundation

struct LINFrame: Sendable, Identifiable {
    let id = UUID()
    let timestamp = Date()
    let bus: UInt8
    let address: UInt32 // Protected Identifier (PID)
    let data: Data
    
    var rawID: UInt8 {
        return UInt8(address & 0x3F)
    }
}

@MainActor
final class PandaDriver: VehicleInterface {
    let transport: PandaTransport
    var linFrameHandler: (@Sendable (LINFrame) -> Void)?
    var txID: UInt32 = 0x7E0
    var rxID: UInt32 = 0x7E8 // Usually txID + 8, but for Renault it can be different
    var bus: UInt8 = 0
    var isKWP2000Mode: Bool = true
    private var simulatedLINTask: Task<Void, Never>?

    // We keep track of the in-flight continuation for the response
    private var inFlight: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    
    // Serialized execution task queue to prevent "Busy" errors
    private var lastRequestTask: Task<String, Error>?

    // Multi-stream ISO-TP reassembler
    private let isotpReassembler = ISOTPReassembler()
    
    // Task reading from transport
    private var inboundTask: Task<Void, Never>?

    init(transport: PandaTransport) {
        self.transport = transport
    }

    convenience init() {
        self.init(transport: .shared)
    }

    func attach() {
        if inboundTask != nil { return }
        inboundTask = Task { [weak self] in
            for await data in self?.transport.inboundStream ?? AsyncStream.makeStream(of: Data.self).stream {
                guard let self else { break }
                self.consume(data)
            }
            guard let self else { return }
            self.handleStreamTermination()
        }
    }

    func detach() {
        simulatedLINTask?.cancel()
        simulatedLINTask = nil
        if let inFlight {
            inFlight.resume(throwing: NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Detached"]))
            self.inFlight = nil
        }
        inboundTask?.cancel()
        inboundTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func handleStreamTermination() {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let continuation = inFlight {
            inFlight = nil
            continuation.resume(throwing: NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transport disconnected"]))
        }
    }

    func setTarget(txID: String, rxID: String?) async throws {
        // Convert hex string to UInt32
        guard let tx = UInt32(txID, radix: 16) else {
            throw NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid txID"])
        }
        self.txID = tx
        
        if let rxID, let rx = UInt32(rxID, radix: 16) {
            self.rxID = rx
        } else {
            // Renault physical CAN diagnostic headers use a +0x20 offset for response mapping (ranges: 74X, 75X, 76X, 79X, 7AX, 7BX)
            if (0x740...0x74F).contains(tx) ||
               (0x750...0x75F).contains(tx) ||
               (0x760...0x76F).contains(tx) ||
               (0x790...0x79F).contains(tx) ||
               (0x7A0...0x7AF).contains(tx) ||
               (0x7B0...0x7BF).contains(tx) {
                self.rxID = tx + 0x20
            } else {
                // Default standard UDS/OBD2 physical request-response mapping (+0x08)
                self.rxID = tx + 0x08
            }
        }
    }

    func sendDiagnosticRequest(_ hexString: String, timeout: TimeInterval) async throws -> String {
        let finalCmd = hexString.replacing(" ", with: "").uppercased()
        
        AppLogger.shared.log("TX: \(finalCmd) on 0x\(String(txID, radix: 16).uppercased())", level: .command)
        
        if transport.isSimulationMode {
            try? await Task.sleep(for: .milliseconds(30))
            let simResponse = try await SimulatorEngine.shared.handleRequest(txID: self.txID, rxID: self.rxID, request: finalCmd)
            AppLogger.shared.log("RX: \(simResponse) on 0x\(String(rxID, radix: 16).uppercased()) [SIM]", level: .command)
            return simResponse
        }
        
        let previousTask = lastRequestTask
        let newTask = Task {
            if let previousTask {
                _ = try? await previousTask.value
            }
            return try await performDiagnosticRequest(finalCmd, timeout: timeout)
        }
        lastRequestTask = newTask
        
        do {
            let rawResponse = try await newTask.value
            AppLogger.shared.log("RX: \(rawResponse) on 0x\(String(rxID, radix: 16).uppercased())", level: .command)
            return rawResponse
        } catch {
            AppLogger.shared.log("ERR: \(error.localizedDescription) on \(finalCmd)", level: .error)
            throw error
        }
    }

    private func performDiagnosticRequest(_ hexString: String, timeout: TimeInterval) async throws -> String {
        if inFlight != nil {
            throw NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Busy"])
        }

        // 1. Prepare ISO-TP Frames from the hex payload
        let payload = dataFromHexString(hexString)
        let frames = fragmentISOTP(payload: payload)

        isotpReassembler.reset(address: self.rxID)
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.inFlight = continuation
                self.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    guard let self, let in0 = self.inFlight else { return }
                    self.inFlight = nil
                    in0.resume(throwing: NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"]))
                }
                
                Task {
                    do {
                        for frame in frames {
                            let packed = self.packPandaCAN(address: self.txID, data: frame, bus: self.bus)
                            try await self.transport.send(packed)
                            // Tiny delay between frames
                            try await Task.sleep(for: .milliseconds(5))
                        }
                    } catch {
                        self.timeoutTask?.cancel()
                        self.timeoutTask = nil
                        if let in0 = self.inFlight {
                            self.inFlight = nil
                            in0.resume(throwing: error)
                        }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.timeoutTask?.cancel()
                self.timeoutTask = nil
                if let continuation = self.inFlight {
                    self.inFlight = nil
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    private func consume(_ data: Data) {
        // Parse Panda UDP packet which might contain multiple CAN frames
        let frames = unpackPandaCAN(data: data)
        for frame in frames {
            if frame.bus == 3 || frame.bus == 4 {
                let linFrame = LINFrame(bus: frame.bus, address: frame.address, data: frame.data)
                linFrameHandler?(linFrame)
            } else if frame.address == self.rxID {
                handleISOTPFrame(frame.data)
            }
        }
    }

    private func handleISOTPFrame(_ data: Data) {
        let result = isotpReassembler.processFrame(address: self.rxID, data: data)
        switch result {
        case .completed(let completedData):
            deliver(completedData)
        case .needsFlowControl:
            // Send Flow Control: 30 00 00 padded to 8 bytes for older KWP2000 strict ECUs (Scenic II / Modus)
            Task {
                let fcData = Data([0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
                let packed = packPandaCAN(address: txID, data: fcData, bus: self.bus)
                try? await transport.send(packed)
            }
        case .error(let errMsg):
            NSLog("[PandaDriver] ISO-TP Error: \(errMsg)")
        case .pending:
            break
        }
    }

    private func deliver(_ data: Data) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let continuation = inFlight {
            inFlight = nil
            // Return uppercase hex string
            let hex = data.map { String(format: "%02X", $0) }.joined()
            continuation.resume(returning: hex)
        }
    }

    // MARK: - Panda USB/UDP Packing (comma.ai protocol)

    struct CANFrame {
        let address: UInt32
        let data: Data
        let bus: UInt8
    }

    private let dlcToLen = [0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 20, 24, 32, 48, 64]
    private func lenToDLC(_ len: Int) -> UInt8 {
        for (i, l) in dlcToLen.enumerated() {
            if l >= len { return UInt8(i) }
        }
        return 0
    }

    private func packPandaCAN(address: UInt32, data: Data, bus: UInt8) -> Data {
        let extended: UInt32 = address >= 0x800 ? 1 : 0
        let dlc = lenToDLC(data.count)
        
        var header = Data(count: 6)
        let word_4b: UInt32 = extended == 1 ? ((address << 3) | (extended << 2)) : ((address << 21) | (extended << 2))
        
        header[0] = (dlc << 4) | (bus << 1) // fd = 0
        header[1] = UInt8(word_4b & 0xFF)
        header[2] = UInt8((word_4b >> 8) & 0xFF)
        header[3] = UInt8((word_4b >> 16) & 0xFF)
        header[4] = UInt8((word_4b >> 24) & 0xFF)
        
        var checksum: UInt8 = 0
        for i in 0..<5 { checksum ^= header[i] }
        for b in data { checksum ^= b }
        header[5] = checksum
        
        return header + data
    }

    private func unpackPandaCAN(data: Data) -> [CANFrame] {
        var ret: [CANFrame] = []
        var offset = 0
        
        while offset + 6 <= data.count {
            let header = data[offset..<offset+6]
            let dlcIdx = Int(header[header.startIndex] >> 4)
            let dataLen = dlcIdx < dlcToLen.count ? dlcToLen[dlcIdx] : 0
            
            if offset + 6 + dataLen > data.count { break }
            
            let bus = (header[header.startIndex] >> 1) & 0x7
            let word1 = UInt32(header[header.startIndex+1])
            let word2 = UInt32(header[header.startIndex+2]) << 8
            let word3 = UInt32(header[header.startIndex+3]) << 16
            let word4 = UInt32(header[header.startIndex+4]) << 24
            let word_4b = word1 | word2 | word3 | word4
            
            let extended = (word_4b >> 2) & 1
            let address = extended == 1 ? (word_4b >> 3) : (word_4b >> 21)
            
            let frameData = data[offset+6..<offset+6+dataLen]
            ret.append(CANFrame(address: address, data: frameData, bus: bus))
            
            offset += 6 + dataLen
        }
        return ret
    }

    // MARK: - Helpers

    private func fragmentISOTP(payload: Data) -> [Data] {
        if payload.count <= 7 {
            var frame = Data([UInt8(payload.count)])
            frame.append(payload)
            // pad with 00 to 8 bytes (Scenic II / Modus KWP2000 ECUs require strict 8-byte frames)
            while frame.count < 8 {
                frame.append(0x00)
            }
            return [frame]
        }
        
        var frames: [Data] = []
        // First Frame
        var ff = Data([UInt8(0x10 | ((payload.count >> 8) & 0x0F)), UInt8(payload.count & 0xFF)])
        ff.append(payload.prefix(6))
        // First frame is already 8 bytes
        frames.append(ff)
        
        // Consecutive Frames
        var offset = 6
        var index: UInt8 = 1
        while offset < payload.count {
            let chunk = payload[offset..<min(offset+7, payload.count)]
            var cf = Data([0x20 | (index & 0x0F)])
            cf.append(chunk)
            // pad with 00 to 8 bytes
            while cf.count < 8 {
                cf.append(0x00)
            }
            frames.append(cf)
            offset += chunk.count
            index += 1
        }
        return frames
    }

    private func dataFromHexString(_ hex: String) -> Data {
        var data = Data()
        var hexStr = hex.replacing(" ", with: "")
        if hexStr.count % 2 != 0 { hexStr = "0" + hexStr }
        var i = hexStr.startIndex
        while i < hexStr.endIndex {
            let next = hexStr.index(i, offsetBy: 2)
            if let b = UInt8(hexStr[i..<next], radix: 16) {
                data.append(b)
            }
            i = next
        }
        return data
    }
    
    // MARK: - Safety Config
    
    enum SafetyMode: UInt16 {
        case silent = 0
        case elm327 = 3
        case allOutput = 17
    }
    
    /// Configures the Panda hardware for active OBD2 communication.
    /// Routes the CAN transceivers to the OBD2 connector, disables heartbeats, disables power-saving,
    /// configures the CAN speed to 500kbps, and resets communications.
    func configureForOBD() async throws {
        // 1. Disable heartbeat checks (request: 0xf8, value: 0, index: 0)
        try await transport.sendControlWrite(requestType: 0x40, request: 0xf8, value: 0, index: 0)
        
        // 2. Disable power save mode (request: 0xe7, value: 0, index: 0)
        try await transport.sendControlWrite(requestType: 0x40, request: 0xe7, value: 0, index: 0)
        
        // 3. Connect OBD2 CAN lines to CAN transceivers (request: 0xdb, value: 1, index: 0)
        try await transport.sendControlWrite(requestType: 0x40, request: 0xdb, value: 1, index: 0)
        
        // 4. Configure CAN speed for buses 0, 1, and 2
        for bus in [UInt16(0), UInt16(1), UInt16(2)] {
            // Disable auto CAN-FD (0xe8)
            try? await transport.sendControlWrite(requestType: 0x40, request: 0xe8, value: bus, index: 0)
            // Set CAN speed to 250 kbps (0xde, value * 10 = 2500) pour Scenic II et Modus
            try? await transport.sendControlWrite(requestType: 0x40, request: 0xde, value: bus, index: 2500)
        }
        
        // 5. Reset CAN communications (request: 0xc0, value: 0, index: 0)
        try? await transport.sendControlWrite(requestType: 0x40, request: 0xc0, value: 0, index: 0)
    }
    
    /// Configures the speed of a specific CAN bus on the Panda hardware.
    func setCANSpeed(bus: UInt8, kbps: Int) async throws {
        // request: 0xde, value: bus, index: kbps * 10
        try await transport.sendControlWrite(requestType: 0x40, request: 0xde, value: UInt16(bus), index: UInt16(kbps * 10))
        isKWP2000Mode = (kbps == 250)
    }
    
    func setSafetyModel(_ mode: SafetyMode) async throws {
        // 0x40 is Vendor Request Out, 0xdc (220) is set_safety_model
        try await transport.sendControlWrite(requestType: 0x40, request: 0xdc, value: mode.rawValue, index: 0)
    }
    
    /// Configures the LIN/UART port on the Panda hardware.
    /// uartPort: 1 for LIN1 (USART3), 2 for LIN2 (UART5)
    /// baud: speed in bps (typically 10400 or 19200)
    func configureLIN(uartPort: UInt16, baudRate: UInt32) async throws {
        if transport.isSimulationMode {
            startSimulatedLINLoop(uartPort: uartPort)
            return
        }
        // 1. Disable heartbeat checks (request: 0xf8, value: 0, index: 0)
        try await transport.sendControlWrite(requestType: 0x40, request: 0xf8, value: 0, index: 0)
        
        // 2. Disable power save mode (request: 0xe7, value: 0, index: 0)
        try await transport.sendControlWrite(requestType: 0x40, request: 0xe7, value: 0, index: 0)
        
        // 3. Set UART baud rate on the specified port
        try await transport.setUARTBaudRate(uart: uartPort, baud: baudRate)
    }
    
    private func startSimulatedLINLoop(uartPort: UInt16) {
        simulatedLINTask?.cancel()
        simulatedLINTask = Task { [weak self] in
            let bus: UInt8 = uartPort == 1 ? 3 : 4
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { break }
                let rawID = UInt8.random(in: 10...30)
                let pid = LINFuzzer.protectedID(from: rawID)
                let dummyData = Data([UInt8.random(in: 0...255), UInt8.random(in: 0...255)])
                let checksum = LINFuzzer.calculateChecksum(pid: pid, data: dummyData, enhanced: true)
                let frameData = dummyData + Data([checksum])
                let frame = LINFrame(bus: bus, address: UInt32(pid), data: frameData)
                self.linFrameHandler?(frame)
            }
        }
    }
    
    /// Sends a LIN frame (encapsulated as a CAN frame on Bus 3 or 4)
    func sendLINFrame(bus: UInt8, address: UInt32, data: Data) async throws {
        let packed = packPandaCAN(address: address, data: data, bus: bus)
        try await transport.send(packed)
    }
    
    isolated deinit {
        inboundTask?.cancel()
        timeoutTask?.cancel()
    }
}
