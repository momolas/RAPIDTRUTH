import Foundation
import Network
import Observation

// MARK: - Protocol d'Abstraction
/// Permet l'injection de dépendances pour mocker le dongle dans les tests unitaires
@MainActor
protocol PandaTransporting: AnyObject {
    var state: PandaState { get }
    var discoveredPandas: [String] { get }
    var inboundStream: AsyncStream<Data> { get }
    
    func scanForPandas()
    func stopScan()
    func connect(host: String?, port: UInt16)
    func disconnect()
    func send(_ data: Data) async throws
    func sendControlWrite(requestType: UInt16, request: UInt16, value: UInt16, index: UInt16, data: Data) async throws
    func setUARTBaudRate(uart: UInt16, baud: UInt32) async throws
    func setUARTParity(uart: UInt16, parity: UInt16) async throws
}

enum PandaState: Equatable {
    case idle
    case connecting
    case connected
    case error(String)
}

// MARK: - Implémentation
@MainActor
@Observable
final class PandaTransport: PandaTransporting {
    private(set) var state: PandaState = .idle
    private(set) var discoveredPandas: [String] = []
    var isSimulationMode: Bool = false
    
    let inboundStream: AsyncStream<Data>
    private let inboundContinuation: AsyncStream<Data>.Continuation
    
    private var connection: NWConnection?
    private var udpConnection: NWConnection?
    private var scanTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "obd.panda.queue")
    
    // État pour la reconnexion automatique
    private var isIntentionalDisconnect = false
    private var lastTargetHost: String?
    private var lastTargetPort: UInt16 = 1337
    
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
        isIntentionalDisconnect = false
        lastTargetHost = host
        lastTargetPort = port
        
        cleanupConnections()
        state = .connecting
        
        if isSimulationMode {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                self.state = .connected
            }
            return
        }
        
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
                        self.handleConnectionDrop(error: error.localizedDescription)
                    }
                case .waiting(let error):
                    NSLog("[PandaTransport] Connection waiting: \(error.localizedDescription)")
                    Task {
                        try? await Task.sleep(for: .milliseconds(4500))
                        if self.state == .connecting && !fallbackTriggered && self.connection === connection {
                            fallbackTriggered = true
                            self.triggerFallback(failedHost: targetHost, port: port)
                        }
                    }
                case .cancelled:
                    if self.state != .idle && !fallbackTriggered && self.isIntentionalDisconnect { 
                        self.state = .idle 
                    }
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
        NSLog("[PandaTransport] Fallback IP: \(alternativeHost)")
        
        cleanupConnections()
        connectToHost(alternativeHost, port: port, allowFallback: false)
    }
    
    func disconnect() {
        isIntentionalDisconnect = true
        cleanupConnections()
        state = .idle
    }
    
    private func cleanupConnections() {
        connection?.cancel()
        connection = nil
        udpConnection?.cancel()
        udpConnection = nil
    }
    
    // MARK: - Boucle de réception et Auto-Reconnexion
    
    private func startReceiveLoop() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                if let data, !data.isEmpty {
                    self.inboundContinuation.yield(data)
                }
                
                // Logique d'auto-reconnexion au lieu de la déconnexion directe
                if error != nil || isComplete {
                    self.handleConnectionDrop(error: error?.localizedDescription ?? "Fermeture distante")
                    return
                }
                
                if self.connection != nil {
                    self.startReceiveLoop() // Récursion asynchrone pour lire le prochain chunk
                }
            }
        }
    }
    
    private func handleConnectionDrop(error: String) {
        guard !isIntentionalDisconnect else { return }
        
        NSLog("[PandaTransport] Connexion perdue (\(error)). Tentative de reconnexion dans 2s...")
        self.state = .connecting
        cleanupConnections()
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard !self.isIntentionalDisconnect else { return }
            let host = self.lastTargetHost ?? self.discoverPandaIP()
            self.connectToHost(host, port: self.lastTargetPort, allowFallback: false)
        }
    }
    
    func send(_ data: Data) async throws {
        if isSimulationMode { return }
        guard let connection = connection, state == .connected else {
            throw NSError(domain: "PandaTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Non connecté au Panda"])
        }
        
        try Task.checkCancellation()
        
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                })
            }
        } onCancel: {
            connection.cancel()
        }
    }
    
    // MARK: - Optimisation UDP : Attente de l'état .ready
    
    private var inFlightUDPTask: Task<NWConnection, Error>?
    
    /// Fournit une connexion UDP garantie d'être à l'état `.ready`
    private func getReadyUDPConnection() async throws -> NWConnection {
        if let existing = self.udpConnection, existing.state == .ready {
            return existing
        }
        
        if let task = inFlightUDPTask {
            return try await task.value
        }
        
        let task = Task<NWConnection, Error> { @MainActor in
            defer { self.inFlightUDPTask = nil }
            
            let targetHost = discoverPandaIP()
            let endpoint = NWEndpoint.Host(targetHost)
            guard let nwPort = NWEndpoint.Port(rawValue: 1338) else {
                throw NSError(domain: "PandaTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Port UDP invalide"])
            }
            let udpParameters = NWParameters(dtls: nil, udp: NWProtocolUDP.Options())
            udpParameters.prohibitExpensivePaths = false
            udpParameters.prohibitConstrainedPaths = false
            
            let newConnection = NWConnection(host: endpoint, port: nwPort, using: udpParameters)
            self.udpConnection = newConnection
            
            return try await withCheckedThrowingContinuation { continuation in
                var hasResumed = false
                
                let transport = self
                newConnection.stateUpdateHandler = { [weak transport] udpState in
                    Task { @MainActor [weak transport] in
                        guard let transport else { return }
                        switch udpState {
                        case .ready:
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: newConnection)
                            }
                        case .failed(let error):
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(throwing: error)
                            }
                            transport.udpConnection?.cancel()
                            transport.udpConnection = nil
                        default:
                            break
                        }
                    }
                }
                newConnection.start(queue: self.queue)
            }
        }
        
        self.inFlightUDPTask = task
        return try await task.value
    }
    
    func sendControlWrite(requestType: UInt16, request: UInt16, value: UInt16, index: UInt16, data: Data = Data()) async throws {
        if isSimulationMode { return }
        AppLogger.shared.log("USB CTRL: reqType=0x\(String(requestType, radix: 16).uppercased()), req=0x\(String(request, radix: 16).uppercased()), val=\(value), idx=\(index), len=\(data.count)", level: .info)
        
        var packet = Data()
        // Standard USB control request header (8 bytes):
        // bmRequestType (1 byte) + bRequest (1 byte) + wValue (2 bytes) + wIndex (2 bytes) + wLength (2 bytes)
        packet.append(UInt8(requestType & 0xFF))
        packet.append(UInt8(request & 0xFF))
        packet.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
        packet.append(contentsOf: withUnsafeBytes(of: index.littleEndian) { Array($0) })
        let length = UInt16(data.count)
        packet.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Array($0) })
        packet.append(data)
        
        // On attend que la route UDP soit formellement établie avant d'émettre
        let activeUdpConnection = try await getReadyUDPConnection()
        
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
    
    func setUARTBaudRate(uart: UInt16, baud: UInt32) async throws {
        try await sendControlWrite(requestType: 0x40, request: 225, value: UInt16(baud & 0xFFFF), index: uart)
    }
    
    func setUARTParity(uart: UInt16, parity: UInt16) async throws {
        try await sendControlWrite(requestType: 0x40, request: 226, value: parity, index: uart)
    }
    
    // MARK: - Utilitaires Réseau (Maintenus en C-API pour compatibilité immédiate)
    
    private func discoverPandaIP() -> String {
        guard let localIP = getWiFiAddress() else { return "192.168.0.10" }
        let components = localIP.components(separatedBy: ".")
        guard components.count == 4 else { return "192.168.0.10" }
        let baseIP = "\(components[0]).\(components[1]).\(components[2])"
        return baseIP == "192.168.43" ? "\(baseIP).1" : "\(baseIP).10"
    }
    
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                if let interface = ptr?.pointee,
                   let ifaAddr = interface.ifa_addr,
                   ifaAddr.pointee.sa_family == UInt8(AF_INET),
                   let ifaName = interface.ifa_name,
                   let name = String(cString: ifaName, encoding: .utf8), name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ifaAddr, socklen_t(ifaAddr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
