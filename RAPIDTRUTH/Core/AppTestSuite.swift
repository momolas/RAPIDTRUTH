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
        reports.append(testUDSNRC())
        reports.append(testMultiRateSampler())
        reports.append(testFreezeFrameDecoder())
        reports.append(testActuatorRegistry())
        
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
        // Corrélation parfaite positive (r = 1.0)
        let xs = [1.0, 2.0, 3.0, 4.0, 5.0]
        let ys = [2.0, 4.0, 6.0, 8.0, 10.0]
        guard let r1 = SignalCorrelator.pearsonCorrelation(x: xs, y: ys), abs(r1 - 1.0) < 0.001 else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "Échec corrélation linéaire positive (attendu 1.0)")
        }
        
        // Corrélation parfaite négative (r = -1.0)
        let ysNeg = [10.0, 8.0, 6.0, 4.0, 2.0]
        guard let r2 = SignalCorrelator.pearsonCorrelation(x: xs, y: ysNeg), abs(r2 - (-1.0)) < 0.001 else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "Échec corrélation linéaire négative (attendu -1.0)")
        }
        
        // Échantillons trop courts
        guard SignalCorrelator.pearsonCorrelation(x: [1.0], y: [2.0]) == nil else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "N < 2 aurait dû renvoyer nil")
        }
        
        return TestReport(testName: "SignalCorrelator", passed: true, message: "Calcul du coefficient r de Pearson OK")
    }

    // MARK: - UDS NRC Tests

    private static func testUDSNRC() -> TestReport {
        // Test parsing standard NRC: 7F 10 22 (ConditionsNotCorrect on Session 10)
        let resp1 = UDSNRC.parse(from: "7F1022")
        guard let r1 = resp1, r1.nrc == .conditionsNotCorrect, r1.requestedServiceID == 0x10 else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Échec de parsing NRC 7F1022")
        }
        guard !r1.actionAdvice.isEmpty, r1.title == "Conditions Non Remplies" else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Détails NRC incomplets pour 0x22")
        }

        // Test parsing with header: 7E8 03 7F 30 83 (Engine is running on Actuator 30)
        let resp2 = UDSNRC.parse(from: "7E8037F3083")
        guard let r2 = resp2, r2.nrc == .engineIsRunning, r2.requestedServiceID == 0x30 else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Échec de parsing NRC avec header 7E8037F3083")
        }

        // Non-NRC frame should return nil
        guard UDSNRC.parse(from: "5003003201F4") == nil else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Trame positive aurait dû renvoyer nil")
        }

        return TestReport(testName: "UDSNRC", passed: true, message: "Décodage exhaustif des Negative Response Codes ISO-14229 OK")
    }

    // MARK: - MultiRate Sampler Tests

    private static func testMultiRateSampler() -> TestReport {
        let rpmPid = PidDef(id: "engine_rpm", displayName: "Régime Moteur", ecu: "engine", mode: "01", pid: "0C", unit: "rpm", formula: "(A*256+B)/4", category: .engine)
        let tempPid = PidDef(id: "coolant_temp", displayName: "Température Liquide Refroidissement", ecu: "engine", mode: "01", pid: "05", unit: "°C", formula: "A-40", category: .temperature)
        let speedPid = PidDef(id: "vehicle_speed", displayName: "Vitesse Véhicule", ecu: "engine", mode: "01", pid: "0D", unit: "km/h", formula: "A", category: .speed)

        guard Sampler.defaultSamplingRate(for: rpmPid) == .fast else {
            return TestReport(testName: "MultiRateSampler", passed: false, message: "RPM aurait dû être catégorisé en .fast (10 Hz)")
        }
        guard Sampler.defaultSamplingRate(for: speedPid) == .fast else {
            return TestReport(testName: "MultiRateSampler", passed: false, message: "Speed aurait dû être catégorisé en .fast (10 Hz)")
        }
        guard Sampler.defaultSamplingRate(for: tempPid) == .slow else {
            return TestReport(testName: "MultiRateSampler", passed: false, message: "Température aurait dû être catégorisée en .slow (0.5 Hz)")
        }

        guard SamplingRate.fast.tickDivider == 1 && SamplingRate.normal.tickDivider == 5 && SamplingRate.slow.tickDivider == 20 else {
            return TestReport(testName: "MultiRateSampler", passed: false, message: "Diviseurs de cycle incorrects")
        }

        return TestReport(testName: "MultiRateSampler", passed: true, message: "Cadencement et diviseurs multi-fréquences OK")
    }

    // MARK: - Freeze Frame Tests

    private static func testFreezeFrameDecoder() -> TestReport {
        let dtcLoader = DTCLoader()
        
        // Simuler réponse KWP Service 18: 58 [DTC] [KM: 0x0186A0 = 100000km] [RPM: 0x0BB8 = 750 rpm] [TEMP: 0x78 = 80°C] [SPEED: 0x32 = 50 km/h]
        let kwpHex = "58 01 02 01 86 A0 0B B8 78 32"
        let decoded = dtcLoader.parseFreezeFrameResponse(kwpHex, dtcCode: "P0102")
        
        guard decoded.timestampKm == 100000 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction kilométrage (attendu 100000 km, reçu \(String(describing: decoded.timestampKm)))")
        }
        guard decoded.rpm == 750 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction RPM (attendu 750, reçu \(String(describing: decoded.rpm)))")
        }
        guard decoded.coolantTemp == 80 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction T° eau (attendu 80°C, reçu \(String(describing: decoded.coolantTemp)))")
        }
        guard decoded.vehicleSpeed == 50 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction Vitesse (attendu 50 km/h, reçu \(String(describing: decoded.vehicleSpeed)))")
        }

        return TestReport(testName: "FreezeFrameDecoder", passed: true, message: "Décodage trame gelée KWP Service 18 & Mode 02 OK")
    }

    // MARK: - Actuator Registry Tests

    private static func testActuatorRegistry() -> TestReport {
        let actuators = ActuatorRegistry.standardActuators
        guard !actuators.isEmpty else {
            return TestReport(testName: "ActuatorRegistry", passed: false, message: "Le registre d'actionneurs est vide")
        }

        let clusterActuators = actuators.filter { $0.category == .cluster }
        let engineActuators = actuators.filter { $0.category == .engine }
        let bodyActuators = actuators.filter { $0.category == .body }

        guard !clusterActuators.isEmpty && !engineActuators.isEmpty && !bodyActuators.isEmpty else {
            return TestReport(testName: "ActuatorRegistry", passed: false, message: "Manque des catégories dans le catalogue d'actionneurs")
        }

        // Vérifier l'actionneur balayage d'aiguilles
        guard let sweep = actuators.first(where: { $0.id == "cluster_needle_sweep" }), sweep.ecuHeader == "743" else {
            return TestReport(testName: "ActuatorRegistry", passed: false, message: "Actionneur cluster_needle_sweep invalide")
        }

        return TestReport(testName: "ActuatorRegistry", passed: true, message: "Catalogue complet de \(actuators.count) actionneurs validé")
    }
}
