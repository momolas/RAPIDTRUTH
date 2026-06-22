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
    private var udpConnection: NWConnection?
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
        connectToHost(targetHost, port: port, allowFallback: host == nil)
    }
    
    private func connectToHost(_ targetHost: String, port: UInt16, allowFallback: Bool) {
        let endpoint = NWEndpoint.Host(targetHost)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.prohibitExpensivePaths = false
        parameters.prohibitConstrainedPaths = false
        
        let connection = NWConnection(host: endpoint, port: nwPort, using: parameters)
        self.connection = connection
        
        let udpOptions = NWProtocolUDP.Options()
        let udpParameters = NWParameters(dtls: nil, udp: udpOptions)
        udpParameters.prohibitExpensivePaths = false
        udpParameters.prohibitConstrainedPaths = false
        
        let udpConnection = NWConnection(host: endpoint, port: NWEndpoint.Port(rawValue: 1338)!, using: udpParameters)
        self.udpConnection = udpConnection
        
        udpConnection.stateUpdateHandler = { [weak self] udpState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch udpState {
                case .failed(let error):
                    NSLog("[PandaTransport] UDP Control Connection failed: \(error.localizedDescription)")
                    self.udpConnection?.cancel()
                    self.udpConnection = nil
                default:
                    break
                }
            }
        }
        udpConnection.start(queue: queue)
        
        var fallbackTriggered = false
        
        connection.stateUpdateHandler = { [weak self] nwState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch nwState {
                case .ready:
                    self.state = .connected
                    self.startReceiveLoop()
                case .failed(let error):
                    if allowFallback && !fallbackTriggered {
                        fallbackTriggered = true
                        self.triggerFallback(failedHost: targetHost, port: port)
                    } else {
                        self.state = .error(error.localizedDescription)
                        self.disconnect()
                    }
                case .waiting(let error):
                    NSLog("[PandaTransport] Connection waiting on \(targetHost): \(error.localizedDescription)")
                    // Trigger fallback if connection is stuck waiting for 4.5 seconds (allowing ARP/local network authorization)
                    Task {
                        try? await Task.sleep(for: .milliseconds(4500))
                        if self.state == .connecting && !fallbackTriggered && self.connection === connection {
                            fallbackTriggered = true
                            self.triggerFallback(failedHost: targetHost, port: port)
                        }
                    }
                case .cancelled:
                    if self.state != .idle && !fallbackTriggered { self.state = .idle }
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func triggerFallback(failedHost: String, port: UInt16) {
        let components = failedHost.components(separatedBy: ".")
        guard components.count == 4 else { return }
        let base = "\(components[0]).\(components[1]).\(components[2])"
        let lastDigit = components[3]
        
        let alternativeHost = (lastDigit == "10") ? "\(base).1" : "\(base).10"
        NSLog("[PandaTransport] Connection to \(failedHost) timed out or failed. Trying alternative IP: \(alternativeHost)")
        
        self.connection?.cancel()
        self.connection = nil
        self.udpConnection?.cancel()
        self.udpConnection = nil
        
        // Attempt connection to the fallback IP without allowing further nested fallbacks
        connectToHost(alternativeHost, port: port, allowFallback: false)
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
        udpConnection?.cancel()
        udpConnection = nil
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
        var packet = Data()
        packet.append(contentsOf: withUnsafeBytes(of: requestType.littleEndian) { Array($0) })
        packet.append(contentsOf: withUnsafeBytes(of: request.littleEndian) { Array($0) })
        packet.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
        packet.append(contentsOf: withUnsafeBytes(of: index.littleEndian) { Array($0) })
        packet.append(data)
        
        let activeUdpConnection: NWConnection
        if let existing = self.udpConnection {
            activeUdpConnection = existing
        } else {
            let targetHost = discoverPandaIP()
            let endpoint = NWEndpoint.Host(targetHost)
            let nwPort = NWEndpoint.Port(rawValue: 1338)!
            let udpOptions = NWProtocolUDP.Options()
            let udpParameters = NWParameters(dtls: nil, udp: udpOptions)
            udpParameters.prohibitExpensivePaths = false
            udpParameters.prohibitConstrainedPaths = false
            #if !targetEnvironment(simulator)
            udpParameters.requiredInterfaceType = .wifi
            #endif
            
            let connection = NWConnection(host: endpoint, port: nwPort, using: udpParameters)
            self.udpConnection = connection
            
            connection.stateUpdateHandler = { [weak self] udpState in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch udpState {
                    case .failed(let error):
                        NSLog("[PandaTransport] UDP Control Connection failed: \(error.localizedDescription)")
                        self.udpConnection?.cancel()
                        self.udpConnection = nil
                    default:
                        break
                    }
                }
            }
            connection.start(queue: self.queue)
            activeUdpConnection = connection
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            activeUdpConnection.send(content: packet, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    /// Sets the baud rate of the specified UART/LIN device (request 0xe1 / 225)
    func setUARTBaudRate(uart: UInt16, baud: UInt32) async throws {
        // requestType: 0x40 (Vendor request out), request: 225, value: lower 16-bits of baudrate, index: uart_device
        try await sendControlWrite(requestType: 0x40, request: 225, value: UInt16(baud & 0xFFFF), index: uart)
    }
    
    /// Sets the parity of the specified UART/LIN device (request 0xe2 / 226)
    func setUARTParity(uart: UInt16, parity: UInt16) async throws {
        // parity: 0 = none, 1 = even, 2 = odd
        try await sendControlWrite(requestType: 0x40, request: 226, value: parity, index: uart)
    }
}

