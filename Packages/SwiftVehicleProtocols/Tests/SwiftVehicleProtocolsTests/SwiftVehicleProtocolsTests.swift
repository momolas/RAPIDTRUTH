import Testing
import Foundation
@testable import SwiftVehicleProtocols

@Suite("SwiftVehicleProtocols Unit Tests")
struct SwiftVehicleProtocolsTests {

    @Test("Hex Parsing & Formatting")
    func testHexParsing() {
        let bytes = HexParsing.bytes("62 01 02 FF")
        #expect(bytes == [0x62, 0x01, 0x02, 0xFF])
        #expect(HexParsing.bytes("123") == nil)
        #expect(HexParsing.hex([0x00, 0x7E, 0x80, 0xFF]) == "007E80FF")
    }

    @Test("Formula Evaluator Fast Paths & JavaScript")
    func testFormulaEvaluator() {
        let evaluator = FormulaEvaluator()
        #expect(evaluator.evaluate(formula: "A", bytes: [0x42]) == 66.0)
        #expect(evaluator.evaluate(formula: "(A*256+B)/4", bytes: [0x0B, 0xB8]) == 750.0)
        #expect(evaluator.evaluate(formula: "A-40", bytes: [0x78]) == 80.0)
        #expect(evaluator.evaluate(formula: "A AND 15", bytes: [0xF3]) == 3.0)
    }

    @Test("UDS NRC Parsing")
    func testUDSNRC() {
        let nrcResult = UDSNRC.parse(from: "7F1022")
        #expect(nrcResult != nil)
        #expect(nrcResult?.nrc == .conditionsNotCorrect)
        #expect(nrcResult?.requestedServiceID == 0x10)
        #expect(nrcResult?.title == "Conditions Non Remplies")
    }

    @Test("SecurityAccess Seed & Key Calculation")
    func testSecurityAccess() {
        let keyXor = SecurityAccessManager.calculateKey(seedHex: "12 34", algorithm: .xorStatique, maskHex: "5A 5A")
        #expect(keyXor == "486E")

        let keyRenault = SecurityAccessManager.calculateKey(seedHex: "12 34", algorithm: .renaultStandard, maskHex: "5A 5A")
        #expect(!keyRenault.isEmpty)
    }

    @Test("ISO-TP Multi-Frame Reassembly")
    func testISOTPReassembly() async {
        let reassembler = ISOTPReassembler()

        // 1. Single frame
        let sf = await reassembler.processFrame(address: 0x7E8, data: Data([0x03, 0x22, 0x01, 0x02, 0xAA, 0xAA, 0xAA, 0xAA]))
        #expect(sf == .completed(Data([0x22, 0x01, 0x02])))

        // 2. First frame
        let ff = await reassembler.processFrame(address: 0x7E8, data: Data([0x10, 0x0C, 0x62, 0x01, 0x02, 0x03, 0x04, 0x05]))
        #expect(ff == .needsFlowControl)

        // 3. Consecutive frame
        let cf = await reassembler.processFrame(address: 0x7E8, data: Data([0x21, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x00]))
        if case .completed(let payload) = cf {
            #expect(payload.count == 12)
        } else {
            Issue.record("Consecutive frame did not complete multi-frame reassembly")
        }
    }

    @Test("Pearson Signal Correlation")
    func testSignalCorrelation() {
        let xs = [1.0, 2.0, 3.0, 4.0, 5.0]
        let ys = [2.0, 4.0, 6.0, 8.0, 10.0]
        let r = SignalCorrelator.pearsonCorrelation(x: xs, y: ys)
        #expect(r != nil)
        #expect(abs((r ?? 0) - 1.0) < 0.001)
    }

    @Test("Freeze Frame KWP Decoding")
    func testFreezeFrameDecoder() {
        let kwpHex = "58 01 02 01 86 A0 0B B8 78 32"
        let decoded = FreezeFrameDecoder.parseKWP(responseHex: kwpHex, dtcCode: "P0102")
        #expect(decoded.timestampKm == 100000)
        #expect(decoded.rpm == 750)
        #expect(decoded.coolantTemp == 80)
        #expect(decoded.vehicleSpeed == 50)
    }

    @Test("Simulator Engine Responses")
    func testSimulatorEngine() async throws {
        let sim = SimulatorEngine()
        let sessionResp = try await sim.sendDiagnosticRequest("1085")
        #expect(sessionResp.hasPrefix("5085"))

        let lidResp = try await sim.sendDiagnosticRequest("2100")
        #expect(lidResp.contains("61"))
    }
}
