import Foundation

struct DDT2000Database: Decodable {
    let ecuname: String?
    let obd: DDT2000OBD?
    let data: [String: DDT2000Data]?
    let requests: [DDT2000Request]?
}

struct DDT2000OBD: Decodable {
    let protocolName: String?
    let send_id: String?
    let recv_id: String?
    let baudrate: Int?
    let funcaddr: String?
    
    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case send_id
        case recv_id
        case baudrate
        case funcaddr
    }
}

struct DDT2000Data: Decodable {
    let bitscount: Int?
    let bytescount: Int?
    let scaled: Bool?
    let signed: Bool?
    let step: Double?
    let offset: Double?
    let format: String?
    let unit: String?
    let comment: String?
}

struct DDT2000Request: Decodable {
    let sentbytes: String
    let name: String
    let receivebyte_dataitems: [String: DDT2000ReceiveByteDataItem]?
}

struct DDT2000ReceiveByteDataItem: Decodable {
    let firstbyte: Int
    let bitoffset: Int?
    let ref: Bool?
}

enum DDT2000Parser {
    
    /// Parses a RenoLink/PyREN JSON file and converts it into a RAPIDTRUTH `Profile`.
    static func parse(fileURL: URL) throws -> Profile {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let db = try decoder.decode(DDT2000Database.self, from: data)
        
        var pids: [PidDef] = []
        let txHeader = db.obd?.send_id ?? "7E0"
        let rxHeader = db.obd?.recv_id ?? "7E8"
        let ecuId = db.ecuname ?? "ECU_DDT"
        
        let requests = db.requests ?? []
        let dataDefs = db.data ?? [:]
        
        for req in requests {
            let sentBytes = req.sentbytes.replacing(" ", with: "").uppercased()
            // We assume a Mode + PID format if length is at least 4 chars (e.g. "21A0")
            // For DDT2000, we'll store the whole `sentbytes` as the PID id or mode/pid combo.
            var mode = "22"
            var pid = sentBytes
            if sentBytes.count >= 4 {
                mode = String(sentBytes.prefix(2))
                pid = String(sentBytes.suffix(sentBytes.count - 2))
            } else if sentBytes.count == 2 {
                mode = sentBytes
                pid = ""
            }
            
            // The command echo is usually the command bytes.
            let echoByteCount = sentBytes.count / 2
            
            guard let items = req.receivebyte_dataitems else { continue }
            
            for (dataName, itemRef) in items {
                guard let dataDef = dataDefs[dataName] else { continue }
                
                // 1-based byte index in the raw CAN frame payload (including echo)
                let firstbyte = itemRef.firstbyte
                
                // Calculate 0-based index of the data in the STRIPPED payload.
                // In RAPIDTRUTH, the payload byte 0 is variable A.
                // The echo bytes are already stripped by VehicleInterface/Sampler.
                // Usually echo size + 1 is PyREN's l_SentBytes.
                let dataByteIndex = firstbyte - (echoByteCount + 1)
                guard dataByteIndex >= 0 && dataByteIndex < 60 else { continue }
                
                let formula = buildFormula(
                    byteIndex: dataByteIndex,
                    bitscount: dataDef.bitscount,
                    bytescount: dataDef.bytescount,
                    bitoffset: itemRef.bitoffset,
                    signed: dataDef.signed ?? false,
                    step: dataDef.step,
                    offset: dataDef.offset
                )
                
                // PyREN generates PID IDs based on the data name
                let id = dataName.lowercased().replacing(" ", with: "_").replacing("'", with: "")
                
                let pidDef = PidDef(
                    id: id,
                    displayName: dataName,
                    ecu: ecuId,
                    mode: mode,
                    pid: pid,
                    unit: dataDef.unit ?? "",
                    formula: formula,
                    category: .diagnostics,
                    min: nil,
                    max: nil
                )
                pids.append(pidDef)
            }
        }
        
        let ecuDef = EcuDef(
            requestHeader: txHeader,
            responseHeader: rxHeader
        )
        
        return Profile(
            profileId: UUID().uuidString,
            profileVersion: "1.0",
            displayName: db.ecuname ?? "DDT2000 Imported Profile",
            description: "Imported from DDT2000 JSON",
            vehicleMatch: nil,
            ecus: [ecuId: ecuDef],
            pids: pids,
            sources: ["DDT2000"],
            validatedAgainst: nil
        )
    }
    
    private static func buildFormula(
        byteIndex: Int,
        bitscount: Int?,
        bytescount: Int?,
        bitoffset: Int?,
        signed: Bool,
        step: Double?,
        offset: Double?
    ) -> String {
        let vars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let totalVars = vars.map { String($0) } + vars.map { "A\($0)" } + vars.map { "B\($0)" }
        
        let bytesCount = bytescount ?? 1
        
        // Build the raw byte accumulation
        var rawFormula = ""
        if bytesCount == 1 {
            let v = totalVars[byteIndex]
            rawFormula = v
        } else if bytesCount == 2 {
            let v1 = totalVars[byteIndex]
            let v2 = totalVars[byteIndex + 1]
            rawFormula = "((\(v1)*256)+\(v2))"
        } else if bytesCount == 3 {
            let v1 = totalVars[byteIndex]
            let v2 = totalVars[byteIndex + 1]
            let v3 = totalVars[byteIndex + 2]
            rawFormula = "((\(v1)*65536)+(\(v2)*256)+\(v3))"
        } else if bytesCount == 4 {
            let v1 = totalVars[byteIndex]
            let v2 = totalVars[byteIndex + 1]
            let v3 = totalVars[byteIndex + 2]
            let v4 = totalVars[byteIndex + 3]
            rawFormula = "(((\(v1)<<24)>>>0)+((\(v2)<<16)>>>0)+((\(v3)<<8)>>>0)+\(v4))"
        } else {
            rawFormula = totalVars[byteIndex] // Fallback
        }
        
        // Handle bit offset and masking if necessary
        // Wait, if it's a bitfield, we should shift and mask.
        // For simplicity, if we have bitoffset or bitscount < 8 * bytescount
        let bits = bitscount ?? (bytesCount * 8)
        let sbit = bitoffset ?? 0
        if bits < (bytesCount * 8) || sbit > 0 {
            // Need to shift and mask.
            // Example: bytes=1, bits=1, sbit=3. Shift right by 3, mask with (2^1 - 1) = 1.
            let mask = (1 << bits) - 1
            // PyREN does something more complex for big endian, but normally we can just use standard shift and mask.
            // Since we don't have the full PyREN Endianness logic here, we'll do a basic shift and mask for now.
            // A simple implementation:
            if sbit > 0 {
                rawFormula = "((\(rawFormula)>>\(sbit))&\(mask))"
            } else {
                rawFormula = "(\(rawFormula)&\(mask))"
            }
        }
        
        if signed {
            // For signed values, sign extend it.
            // In JavaScript, bitwise operators operate on 32-bit signed integers.
            // We can shift left and then right to sign extend.
            let shiftAmount = 32 - bits
            if shiftAmount > 0 {
                rawFormula = "((\(rawFormula)<<\(shiftAmount))>>\(shiftAmount))"
            }
        }
        
        // Apply step and offset
        var finalFormula = rawFormula
        if let s = step, s != 1.0 {
            finalFormula = "(\(finalFormula)*\(s))"
        }
        if let o = offset, o != 0.0 {
            if o > 0 {
                finalFormula = "(\(finalFormula)+\(o))"
            } else {
                finalFormula = "(\(finalFormula)\(o))" // o is already negative
            }
        }
        
        return finalFormula
    }
}
