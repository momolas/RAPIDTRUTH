import Foundation

@MainActor
final class SimulatorEngine {
    static let shared = SimulatorEngine()
    
    private init() {}
    
    func handleRequest(txID: UInt32, rxID: UInt32, request: String) async -> String {
        let cleanReq = request.replacing(" ", with: "").uppercased()
        
        // 1. Session diagnostic requests
        if cleanReq.hasPrefix("10") {
            let mode = String(cleanReq.dropFirst(2))
            return "50" + mode
        }
        
        // 2. Clear fault codes (UDS/KWP)
        if cleanReq.hasPrefix("14") {
            return "54"
        }
        
        // 3. Routine Control (31) / Write Data (2E)
        if cleanReq.hasPrefix("31") {
            return "71" // Positive Routine Control response
        }
        if cleanReq.hasPrefix("2E") {
            return "6E" // Positive Write response
        }
        
        // 4. VIN request: 2181
        if cleanReq == "2181" {
            // Return VF1BG000012345678 in hex: 5646314247303030303132333435363738
            return "61815646314247303030303132333435363738"
        }
        
        // Standard OBD2 VIN request
        if cleanReq == "0902" {
            // Return 490201 + VF1BG000012345678 in hex
            return "4902015646314247303030303132333435363738"
        }
        
        // Standard OBD2 Bitmask Ping
        if cleanReq == "0100" {
            return "4100BE3FA813"
        }
        
        // 5. Odometer request: 2118 on 743 (TdB)
        if cleanReq == "2118" {
            // 142385 in hex = 022C31
            return "6118022C31"
        }
        
        // 6. DTC scan requests
        if cleanReq == "17FF00" {
            // Return list of Renault specific DTCs (KWP2000)
            if txID == 0x7E0 { // Engine
                return "5702000201002D00"
            } else if txID == 0x743 { // TdB
                return "5701006500" // DF101 + State 00
            } else {
                return "5700" // No DTCs on other ECUs
            }
        }
        
        // Standard OBD2 DTC request (Mode 03, 07, 0A)
        if cleanReq == "03" {
            return "4302011503000000" // P0115 + P0300
        }
        if cleanReq == "07" {
            return "4701010000000000" // P0100
        }
        if cleanReq == "0A" {
            return "4A00000000000000" // No permanent DTCs
        }
        
        // 7. DTC Extended data (Used Car Check freeze frame)
        if cleanReq == "190600000080" {
            // Return 5906... indicating maximum km in freeze frames.
            // Simulate odometer tampering: freeze frame shows 195000 km (02F9C0)
            return "59060102F9C0"
        }
        
        // 8. Live Data sampling requests (Mode 21 or Mode 1)
        if cleanReq.hasPrefix("21") || cleanReq.hasPrefix("01") {
            let pid = String(cleanReq.dropFirst(2))
            
            // Fluctuating engine RPM
            let time = Date().timeIntervalSince1970
            let factor = (cos(time / 5.0) + 1.0) / 2.0 // 0.0 to 1.0
            
            if pid == "A0" { // Scenic II injection common PIDs
                let rpm = 800 + (1400 * factor) // 800 to 2200
                let rawVal = Int(rpm)
                let byte1 = UInt8((rawVal >> 8) & 0xFF)
                let byte2 = UInt8(rawVal & 0xFF)
                
                let temp = 80 + Int(12 * factor) // 80 to 92 °C
                let byte3 = UInt8(temp + 40)
                
                var data = Data()
                data.append(byte1)
                data.append(byte2)
                data.append(byte3)
                for _ in 0..<17 {
                    data.append(UInt8.random(in: 10...100))
                }
                
                let responsePrefix = String(format: "61%@", pid)
                return responsePrefix + data.map { String(format: "%02X", $0) }.joined()
            }
            
            let responsePrefix = cleanReq.hasPrefix("21") ? "61" + pid : "41" + pid
            var dummyData = Data()
            for _ in 0..<8 {
                dummyData.append(UInt8.random(in: 20...150))
            }
            return responsePrefix + dummyData.map { String(format: "%02X", $0) }.joined()
        }
        
        return ""
    }
}
