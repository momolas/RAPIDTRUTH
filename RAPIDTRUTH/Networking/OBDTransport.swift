import Foundation

@MainActor
protocol OBDTransport: AnyObject {
    var inboundStream: AsyncStream<Data> { get }
    var demoMode: Bool { get }
    
    func send(_ data: Data) async throws
    func enterDemoMode()
    func disconnect()
}
