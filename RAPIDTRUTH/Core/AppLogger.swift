import Foundation
import Observation

public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let message: String
    public let level: LogLevel
}

public enum LogLevel: String, Sendable, CaseIterable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERR"
    case command = "TX/RX"
}

@MainActor
@Observable
public final class AppLogger {
    public static let shared = AppLogger()
    
    public private(set) var entries: [LogEntry] = []
    
    private init() {}
    
    public func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        if entries.count >= 1000 {
            entries.removeFirst()
        }
        entries.append(entry)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = formatter.string(from: entry.timestamp)
        NSLog("[\(timeStr)] [\(level.rawValue)] \(message)")
    }
    
    public func clear() {
        entries.removeAll()
    }
}
