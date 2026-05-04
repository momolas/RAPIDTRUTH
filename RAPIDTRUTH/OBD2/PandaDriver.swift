import Foundation

@MainActor
final class PandaDriver: VehicleInterface {
    let transport: PandaTransport
    var txID: UInt32 = 0x7E0
    var rxID: UInt32 = 0x7E8 // Usually txID + 8, but for Renault it can be different

    // We keep track of the in-flight continuation for the response
    private var inFlight: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?

    // Buffer for ISOTP reconstruction
    private var isotpBuffer: Data = Data()
    private var expectedLength: Int = 0
    private var consecutiveFrameIndex: UInt8 = 0
    
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
        }
    }

    func detach() {
        if let inFlight {
            inFlight.resume(throwing: NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Detached"]))
            self.inFlight = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
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
            // Default Renault/Standard mapping. If it's standard 11-bit, rx is tx + 0x08.
            // But wait, in standard CAN UDS, it's + 0x08. For extended (29-bit), it's more complex.
            // Assuming 11-bit standard + 0x08. If the header is 745 (UCH), response is 765 (+0x20).
            // It's safer to explicitly provide rxID in the managers.
            // For now, if rxID is nil, we default to +0x08 unless it's a known Renault header.
            if tx == 0x745 { self.rxID = 0x765 }
            else if tx == 0x743 { self.rxID = 0x763 }
            else if tx == 0x7A1 { self.rxID = 0x7C1 }
            else if tx == 0x7A0 { self.rxID = 0x7C0 }
            else { self.rxID = tx + 0x08 }
        }
    }

    func sendDiagnosticRequest(_ hexString: String, timeout: TimeInterval) async throws -> String {
        if inFlight != nil {
            throw NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Busy"])
        }

        // 1. Prepare ISO-TP Frames from the hex payload
        let payload = dataFromHexString(hexString)
        let frames = fragmentISOTP(payload: payload)

        isotpBuffer.removeAll()
        expectedLength = 0
        
        return try await withCheckedThrowingContinuation { continuation in
            self.inFlight = continuation
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                guard let self, let in0 = self.inFlight else { return }
                self.inFlight = nil
                in0.resume(throwing: NSError(domain: "PandaDriver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"]))
            }
            
            Task {
                do {
                    // Send frames. If it's multi-frame, we should ideally wait for flow control.
                    // For simplicity, we just send all frames. Real ISOTP waits for FC.
                    // But if it's just 1 frame (most requests), it sends immediately.
                    for frame in frames {
                        let packed = self.packPandaCAN(address: self.txID, data: frame, bus: 0)
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
    }

    private func consume(_ data: Data) {
        // Parse Panda UDP packet which might contain multiple CAN frames
        let frames = unpackPandaCAN(data: data)
        for frame in frames {
            if frame.address == self.rxID {
                handleISOTPFrame(frame.data)
            }
        }
    }

    private func handleISOTPFrame(_ data: Data) {
        guard data.count > 0 else { return }
        let pci = data[0] >> 4
        
        if pci == 0 { // Single Frame
            let length = Int(data[0] & 0x0F)
            guard data.count >= length + 1 else { return }
            let payload = data[1...(length)]
            deliver(payload)
        } 
        else if pci == 1 { // First Frame
            let length = Int((UInt16(data[0] & 0x0F) << 8) | UInt16(data[1]))
            expectedLength = length
            isotpBuffer = data[2...]
            consecutiveFrameIndex = 1
            
            // Send Flow Control: 30 00 00 (Clear to send, block size 0, STmin 0)
            Task {
                let fcData = Data([0x30, 0x00, 0x00])
                let packed = packPandaCAN(address: txID, data: fcData, bus: 0)
                try? await transport.send(packed)
            }
        }
        else if pci == 2 { // Consecutive Frame
            // let index = data[0] & 0x0F
            isotpBuffer.append(data[1...])
            if isotpBuffer.count >= expectedLength {
                deliver(isotpBuffer.prefix(expectedLength))
            }
        }
        else if pci == 3 { // Flow Control
            // We ignore incoming Flow Control for now (we just sent all CFs at once above).
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
        let word_4b: UInt32 = (address << 3) | (extended << 2)
        
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
            let address = (word1 | word2 | word3 | word4) >> 3
            
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
            // pad with 00 to 8 bytes if desired, or let Panda send partial DLC
            return [frame]
        }
        
        var frames: [Data] = []
        // First Frame
        var ff = Data([UInt8(0x10 | ((payload.count >> 8) & 0x0F)), UInt8(payload.count & 0xFF)])
        ff.append(payload.prefix(6))
        frames.append(ff)
        
        // Consecutive Frames
        var offset = 6
        var index: UInt8 = 1
        while offset < payload.count {
            let chunk = payload[offset..<min(offset+7, payload.count)]
            var cf = Data([0x20 | (index & 0x0F)])
            cf.append(chunk)
            frames.append(cf)
            offset += chunk.count
            index += 1
        }
        return frames
    }

    private func dataFromHexString(_ hex: String) -> Data {
        var data = Data()
        var hexStr = hex.replacingOccurrences(of: " ", with: "")
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
}
