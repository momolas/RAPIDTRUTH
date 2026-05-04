import Foundation
import Observation

enum ConnectionType: String, CaseIterable, Identifiable {
    case ble = "Bluetooth (BLE)"
    case wifi = "Wi-Fi (TCP)"
    var id: String { rawValue }
}

enum GlobalConnectionState: Equatable {
    case idle
    case connecting(String)
    case connected(String)
    case error(String)
}

@MainActor
@Observable
final class ConnectionManager: OBDTransport {
    static let shared = ConnectionManager()
    
    var connectionType: ConnectionType {
        get {
            let saved = UserDefaults.standard.string(forKey: "connection_type") ?? ConnectionType.ble.rawValue
            return ConnectionType(rawValue: saved) ?? .ble
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "connection_type")
            disconnect() // Disconnect old transport when switching
        }
    }
    
    var state: GlobalConnectionState {
        switch connectionType {
        case .ble:
            switch BLEManager.shared.connectionState {
            case .idle: return .idle
            case .scanning, .connecting, .discovering: return .connecting("Bluetooth")
            case .connected(let name, _): return .connected(name)
            case .error(let msg): return .error(msg)
            }
        case .wifi:
            switch WiFiManager.shared.state {
            case .idle: return .idle
            case .connecting: return .connecting("Wi-Fi")
            case .connected: return .connected("Wi-Fi Adapter")
            case .error(let msg): return .error(msg)
            }
        }
    }


    var activeTransport: OBDTransport {
        switch connectionType {
        case .ble: return BLEManager.shared
        case .wifi: return WiFiManager.shared
        }
    }
    
    let inboundStream: AsyncStream<Data>
    private let inboundContinuation: AsyncStream<Data>.Continuation
    
    init() {
        let stream = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.inboundStream = stream.stream
        self.inboundContinuation = stream.continuation
        
        Task {
            for await data in BLEManager.shared.inboundStream {
                if self.connectionType == .ble { self.inboundContinuation.yield(data) }
            }
        }
        Task {
            for await data in WiFiManager.shared.inboundStream {
                if self.connectionType == .wifi { self.inboundContinuation.yield(data) }
            }
        }
    }
    
    func send(_ data: Data) async throws {
        try await activeTransport.send(data)
    }
    

    func disconnect() {
        activeTransport.disconnect()
    }
}
