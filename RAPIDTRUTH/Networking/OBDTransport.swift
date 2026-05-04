import Foundation

@MainActor
protocol OBDTransport: AnyObject {
    var inboundStream: AsyncStream<Data> { get }
    
    func send(_ data: Data) async throws
    func disconnect()
}
