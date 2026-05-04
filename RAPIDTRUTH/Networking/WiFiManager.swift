import Foundation
import Network
import Observation

enum WiFiState: Equatable {
    case idle
    case connecting
    case connected
    case error(String)
}

@MainActor
@Observable
final class WiFiManager: OBDTransport {
    private(set) var state: WiFiState = .idle
    private(set) var demoMode: Bool = false
    
    let inboundStream: AsyncStream<Data>
    private let inboundContinuation: AsyncStream<Data>.Continuation
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "obd.wifi.queue")
    
    static let shared = WiFiManager()
    
    init() {
        let stream = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.inboundStream = stream.stream
        self.inboundContinuation = stream.continuation
    }
    
    func enterDemoMode() {
        demoMode = true
        state = .connected
    }
    
    func connect(host: String = "192.168.0.10", port: UInt16 = 35000) {
        if demoMode { return }
        disconnect()
        
        state = .connecting
        let endpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        let connection = NWConnection(host: endpoint, port: nwPort, using: .tcp)
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
                    self.state = .error(error.localizedDescription)
                case .cancelled:
                    if self.state != .idle { self.state = .idle }
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    func disconnect() {
        if demoMode {
            demoMode = false
            state = .idle
            return
        }
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
                
                if !isComplete && self.connection != nil {
                    self.startReceiveLoop() // Read next chunk
                }
            }
        }
    }
    
    func send(_ data: Data) async throws {
        if demoMode { return }
        guard let connection = connection, state == .connected else {
            throw NSError(domain: "WiFiManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected to Wi-Fi adapter"])
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
}
