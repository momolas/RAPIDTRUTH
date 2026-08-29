import Foundation

/// Suite de tests d'auto-validation du moteur applicatif et des protocoles bas-niveau.
@MainActor
enum AppTestSuite {
    
    struct TestReport: Sendable {
        let testName: String
        let passed: Bool
        let message: String
    }
    
    /// Exécute l'ensemble des tests de validation et retourne les rapports détaillés.
    static func runAllTests() -> [TestReport] {
        var reports: [TestReport] = []
        
        reports.append(testHexParsing())
        reports.append(testFormulaEvaluator())
        reports.append(testISOTPReassembler())
        reports.append(testSignalCorrelator())
        
        for report in reports {
            let prefix = report.passed ? "✅ [TEST PASSED]" : "❌ [TEST FAILED]"
            AppLogger.shared.log("\(prefix) \(report.testName): \(report.message)", level: report.passed ? .info : .error)
        }
        
        return reports
    }
    
    // MARK: - HexParsing Tests
    
    private static func testHexParsing() -> TestReport {
        let validHex = "62 01 02 FF"
        let parsed = HexParsing.bytes(validHex)
        guard parsed == [0x62, 0x01, 0x02, 0xFF] else {
            return TestReport(testName: "HexParsing", passed: false, message: "Échec de conversion d'une chaîne hex valide")
        }
        
        guard HexParsing.bytes("62010") == nil else {
            return TestReport(testName: "HexParsing", passed: false, message: "Une chaîne de longueur impaire aurait dû renvoyer nil")
        }
        
        guard HexParsing.hex([0x00, 0x7E, 0x80, 0xFF]) == "007E80FF" else {
            return TestReport(testName: "HexParsing", passed: false, message: "Échec de formatage bytes -> hex")
        }
        
        return TestReport(testName: "HexParsing", passed: true, message: "Validation conversion hex/octets OK")
    }
    
    // MARK: - FormulaEvaluator Tests
    
    private static func testFormulaEvaluator() -> TestReport {
        let evaluator = FormulaEvaluator()
        
        guard let singleByte = evaluator.evaluate(formula: "A", bytes: [0x42]), singleByte == 66.0 else {
            return TestReport(testName: "FormulaEvaluator", passed: false, message: "Échec formule simple A")
        }
        
        guard let twoBytes = evaluator.evaluate(formula: "(A*256+B)/4", bytes: [0x0B, 0xB8]), twoBytes == 750.0 else {
            return TestReport(testName: "FormulaEvaluator", passed: false, message: "Échec formule 2 octets (A*256+B)/4")
        }
        
        guard let bitwise = evaluator.evaluate(formula: "A AND 15", bytes: [0xF3]), bitwise == 3.0 else {
            return TestReport(testName: "FormulaEvaluator", passed: false, message: "Échec opérateur bitwise AND")
        }
        
        guard evaluator.evaluate(formula: "A*256+B", bytes: [0x01]) == nil else {
            return TestReport(testName: "FormulaEvaluator", passed: false, message: "Octet manquant aurait dû renvoyer nil")
        }
        
        return TestReport(testName: "FormulaEvaluator", passed: true, message: "Évaluation JavaScriptCore & opérateurs OK")
    }
    
    // MARK: - ISOTPReassembler Tests
    
    private static func testISOTPReassembler() -> TestReport {
        let reassembler = ISOTPReassembler()
        
        // 1. Single Frame test
        let sfData = Data([0x03, 0x22, 0x01, 0x02, 0xAA, 0xAA, 0xAA, 0xAA])
        let sfResult = reassembler.processFrame(address: 0x7E8, data: sfData)
        guard case .completed(let sfPayload) = sfResult, sfPayload == Data([0x22, 0x01, 0x02]) else {
            return TestReport(testName: "ISOTPReassembler", passed: false, message: "Échec Single Frame")
        }
        
        // 2. Multi-frame test
        let ffData = Data([0x10, 0x0C, 0x62, 0x01, 0x02, 0x03, 0x04, 0x05])
        let ffResult = reassembler.processFrame(address: 0x7E8, data: ffData)
        guard case .needsFlowControl = ffResult else {
            return TestReport(testName: "ISOTPReassembler", passed: false, message: "First Frame aurait dû renvoyer needsFlowControl")
        }
        
        let cfData = Data([0x21, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x00])
        let cfResult = reassembler.processFrame(address: 0x7E8, data: cfData)
        guard case .completed(let cfPayload) = cfResult, cfPayload.count == 12 else {
            return TestReport(testName: "ISOTPReassembler", passed: false, message: "Échec réassemblage Consecutive Frame")
        }
        
        return TestReport(testName: "ISOTPReassembler", passed: true, message: "Single Frame & Multi-Frame ISO-TP OK")
    }
    
    // MARK: - SignalCorrelator Tests
    
    private static func testSignalCorrelator() -> TestReport {
        let correlator = SignalCorrelator()
        let rpms = [800.0, 900.0, 1000.0, 1200.0, 1500.0, 2000.0, 2500.0, 3000.0]
        var lastResults: [SliceCorrelation] = []
        
        for rpm in rpms {
            let byteA = UInt8(min(255, Int(rpm / 20.0)))
            let hex = String(format: "%02X 00", byteA)
            lastResults = correlator.record(hexResponse: hex, rpm: rpm, speed: 0.0)
        }
        
        guard let topResult = lastResults.first(where: { $0.sliceName == "A" && $0.referenceSignal == "RPM" }),
              topResult.coefficient > 0.95 else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "Échec corrélation linéaire avec signal de référence")
        }
        
        return TestReport(testName: "SignalCorrelator", passed: true, message: "Calculs de Pearson & classification OK")
    }
}
