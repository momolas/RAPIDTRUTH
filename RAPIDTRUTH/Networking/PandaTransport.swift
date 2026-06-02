import Foundation
import Network
import Observation

enum PandaState: Equatable {
    case idle
    case connecting
    case connected
    case error(String)
}

@MainActor
@Observable
final class PandaTransport {
    private(set) var state: PandaState = .idle
    private(set) var discoveredPandas: [String] = []
    
    let inboundStream: AsyncStream<Data>
    private let inboundContinuation: AsyncStream<Data>.Continuation
    
    private var connection: NWConnection?
    private var scanTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "obd.panda.queue")
    
    static let shared = PandaTransport()

    var localIP: String? {
        getWiFiAddress()
    }

    var targetIP: String {
        discoverPandaIP()
    }
    
    init() {
        let stream = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.inboundStream = stream.stream
        self.inboundContinuation = stream.continuation
    }

    func scanForPandas() {
        scanTask?.cancel()
        discoveredPandas.removeAll()
        // Wait a small delay to simulate scan
        scanTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            let deducedIP = discoverPandaIP()
            if !self.discoveredPandas.contains(deducedIP) {
                self.discoveredPandas.append(deducedIP)
            }
        }
    }
    
    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    func connect(host: String? = nil, port: UInt16 = 1337) {
        disconnect()
        
        state = .connecting
        let targetHost = host ?? discoverPandaIP()
        let endpoint = NWEndpoint.Host(targetHost)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        // Panda uses TCP on port 1337
        let parameters = NWParameters.tcp
        let connection = NWConnection(host: endpoint, port: nwPort, using: parameters)
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] nwState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch nwState {
                case .ready:
                    self.state = .connected
                    self.startReceiveLoop()
                case .failed(let error):
                    self.state = .error(error.localizedDescription)
                    self.disconnect()
                case .waiting(let error):
                    // Log transient waiting, but do not set .error state since this is temporary
                    NSLog("[PandaTransport] Connection is waiting for path: \(error.localizedDescription)")
                case .cancelled:
                    if self.state != .idle { self.state = .idle }
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func discoverPandaIP() -> String {
        guard let localIP = getWiFiAddress() else {
            return "192.168.0.10" // Default fallback
        }
        
        let components = localIP.components(separatedBy: ".")
        guard components.count == 4 else { return "192.168.0.10" }
        
        let baseIP = "\(components[0]).\(components[1]).\(components[2])"
        
        // If it's a 192.168.43.x network (Android hotspot style), Panda is usually .1
        if baseIP == "192.168.43" {
            return "\(baseIP).1"
        }
        
        // By default, white Panda acts as DHCP server and sets itself to .10
        return "\(baseIP).10"
    }
    
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) { // IPv4
                    if let name = String(cString: (interface?.ifa_name)!, encoding: .utf8), name == "en0" { // Wi-Fi
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        state = .idle
    }
    
    private func startReceiveLoop() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    if self.state != .idle {
                        self.state = .error(error.localizedDescription)
                        self.disconnect()
                    }
                    return
                }
                
                if let data, !data.isEmpty {
                    self.inboundContinuation.yield(data)
                }
                
                if isComplete {
                    if self.state != .idle {
                        self.state = .error("La connexion a été fermée par le dongle.")
                        self.disconnect()
                    }
                    return
                }
                
                if self.connection != nil {
                    self.startReceiveLoop() // Read next chunk
                }
            }
        }
    }
    
    func send(_ data: Data) async throws {
        guard let connection = connection, state == .connected else {
            throw NSError(domain: "PandaTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected to Panda adapter"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    /// Sends a vendor control transfer write request to the Panda via UDP port 1338 (Wi-Fi).
    func sendControlWrite(requestType: UInt16, request: UInt16, value: UInt16, index: UInt16, data: Data = Data()) async throws {
        let targetHost = discoverPandaIP()
        let endpoint = NWEndpoint.Host(targetHost)
        let nwPort = NWEndpoint.Port(rawValue: 1338)!
        
        let parameters = NWParameters.udp
        let connection = NWConnection(host: endpoint, port: nwPort, using: parameters)
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var packet = Data()
                    packet.append(contentsOf: withUnsafeBytes(of: requestType.littleEndian) { Array($0) })
                    packet.append(contentsOf: withUnsafeBytes(of: request.littleEndian) { Array($0) })
                    packet.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
                    packet.append(contentsOf: withUnsafeBytes(of: index.littleEndian) { Array($0) })
                    packet.append(data)
                    
                    connection.send(content: packet, completion: .contentProcessed { error in
                        connection.cancel()
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    })
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
    }
}
