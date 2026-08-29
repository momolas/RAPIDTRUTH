import Foundation

public enum HexParsing: Sendable {
    public static func bytes(_ hexString: String) -> [UInt8]? {
        let clean = hexString.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard clean.count % 2 == 0 else { return nil }
        var result = [UInt8]()
        result.reserveCapacity(clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let nextIndex = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<nextIndex], radix: 16) else { return nil }
            result.append(byte)
            index = nextIndex
        }
        return result
    }

    public static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}
