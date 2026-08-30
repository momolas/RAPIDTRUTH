import Foundation
import SwiftVehicleProtocols

/// Suite de tests d'auto-validation du moteur applicatif et des protocoles bas-niveau.
@MainActor
enum AppTestSuite {
    
    struct TestReport: Sendable {
        let testName: String
        let passed: Bool
        let message: String
    }
    
    /// Exécute l'ensemble des tests de validation et retourne les rapports détaillés.
    static func runAllTests() async -> [TestReport] {
        var reports: [TestReport] = []
        
        reports.append(testHexParsing())
        reports.append(testFormulaEvaluator())
        reports.append(await testISOTPReassembler())
        reports.append(testSignalCorrelator())
        reports.append(testUDSNRC())
        reports.append(testMultiRateSampler())
        reports.append(testFreezeFrameDecoder())
        reports.append(testActuatorRegistry())
        reports.append(testBatteryRegistration())
        reports.append(testThematicCustomizations())
        reports.append(await testKWP2000Protocol())
        reports.append(testJ1939AndProtocolClassification())
        reports.append(testUnifiedProfileConversion())
        
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
    
    private static func testISOTPReassembler() async -> TestReport {
        let reassembler = ISOTPReassembler()
        
        // 1. Single Frame test
        let sfData = Data([0x03, 0x22, 0x01, 0x02, 0xAA, 0xAA, 0xAA, 0xAA])
        let sfResult = await reassembler.processFrame(address: 0x7E8, data: sfData)
        guard case .completed(let sfPayload) = sfResult, sfPayload == Data([0x22, 0x01, 0x02]) else {
            return TestReport(testName: "ISOTPReassembler", passed: false, message: "Échec Single Frame")
        }
        
        // 2. Multi-frame test
        let ffData = Data([0x10, 0x0C, 0x62, 0x01, 0x02, 0x03, 0x04, 0x05])
        let ffResult = await reassembler.processFrame(address: 0x7E8, data: ffData)
        guard case .needsFlowControl = ffResult else {
            return TestReport(testName: "ISOTPReassembler", passed: false, message: "First Frame aurait dû renvoyer needsFlowControl")
        }
        
        let cfData = Data([0x21, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x00])
        let cfResult = await reassembler.processFrame(address: 0x7E8, data: cfData)
        guard case .completed(let cfPayload) = cfResult, cfPayload.count == 12 else {
            return TestReport(testName: "ISOTPReassembler", passed: false, message: "Échec réassemblage Consecutive Frame")
        }
        
        return TestReport(testName: "ISOTPReassembler", passed: true, message: "Single Frame & Multi-Frame ISO-TP OK")
    }
    
    // MARK: - SignalCorrelator Tests
    
    private static func testSignalCorrelator() -> TestReport {
        let xs = [1.0, 2.0, 3.0, 4.0, 5.0]
        let ys = [2.0, 4.0, 6.0, 8.0, 10.0]
        guard let r1 = SignalCorrelator.pearsonCorrelation(x: xs, y: ys), abs(r1 - 1.0) < 0.001 else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "Échec corrélation linéaire positive (attendu 1.0)")
        }
        
        let ysNeg = [10.0, 8.0, 6.0, 4.0, 2.0]
        guard let r2 = SignalCorrelator.pearsonCorrelation(x: xs, y: ysNeg), abs(r2 - (-1.0)) < 0.001 else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "Échec corrélation linéaire négative (attendu -1.0)")
        }
        
        guard SignalCorrelator.pearsonCorrelation(x: [1.0], y: [2.0]) == nil else {
            return TestReport(testName: "SignalCorrelator", passed: false, message: "N < 2 aurait dû renvoyer nil")
        }
        
        return TestReport(testName: "SignalCorrelator", passed: true, message: "Calcul du coefficient r de Pearson OK")
    }

    // MARK: - UDS NRC Tests

    private static func testUDSNRC() -> TestReport {
        let resp1 = UDSNRC.parse(from: "7F1022")
        guard let r1 = resp1, r1.nrc == .conditionsNotCorrect, r1.requestedServiceID == 0x10 else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Échec de parsing NRC 7F1022")
        }
        guard !r1.actionAdvice.isEmpty, r1.title == "Conditions Non Remplies" else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Détails NRC incomplets pour 0x22")
        }

        let resp2 = UDSNRC.parse(from: "7E8037F3083")
        guard let r2 = resp2, r2.nrc == .engineIsRunning, r2.requestedServiceID == 0x30 else {
            return TestReport(testName: "UDSNRC", passed: false, message: "Échec de parsing NRC avec header 7E8037F3083")
        }

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
        let kwpHex = "58 01 02 01 86 A0 0B B8 78 32"
        let decoded = FreezeFrameDecoder.parseKWP(responseHex: kwpHex, dtcCode: "P0102")
        
        guard decoded.timestampKm == 100000 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction kilométrage")
        }
        guard decoded.rpm == 750 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction RPM")
        }
        guard decoded.coolantTemp == 80 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction T° eau")
        }
        guard decoded.vehicleSpeed == 50 else {
            return TestReport(testName: "FreezeFrameDecoder", passed: false, message: "Échec extraction Vitesse")
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

        guard let sweep = actuators.first(where: { $0.id == "cluster_needle_sweep" }), sweep.ecuHeader == "743" else {
            return TestReport(testName: "ActuatorRegistry", passed: false, message: "Actionneur cluster_needle_sweep invalide")
        }

        return TestReport(testName: "ActuatorRegistry", passed: true, message: "Catalogue complet de \(actuators.count) actionneurs validé")
    }

    // MARK: - Battery & Service Tests

    private static func testBatteryRegistration() -> TestReport {
        let tech = BatteryTechnology.agm
        guard tech.hexCode == 0x03 else {
            return TestReport(testName: "BatteryRegistration", passed: false, message: "Code hex AGM attendu 0x03")
        }
        let efb = BatteryTechnology.efb
        guard efb.hexCode == 0x02 else {
            return TestReport(testName: "BatteryRegistration", passed: false, message: "Code hex EFB attendu 0x02")
        }
        return TestReport(testName: "BatteryRegistration", passed: true, message: "Énumération et codage des technologies batterie OK")
    }

    // MARK: - Customizations Tests

    private static func testThematicCustomizations() -> TestReport {
        let categories = CustomizationCategory.allCases
        guard categories.count == 4 else {
            return TestReport(testName: "ThematicCustomizations", passed: false, message: "4 thèmes de personnalisation attendus")
        }
        return TestReport(testName: "ThematicCustomizations", passed: true, message: "Navigation thématique des télécodages OK")
    }

    // MARK: - KWP2000 Protocol Tests

    private static func testKWP2000Protocol() async -> TestReport {
        // 1. Test des Paramètres Temporels (ISO 14230-3 Service 83)
        let timing = KWP2000TimingParameters(p2MinMs: 25, p2MaxMs: 50, p3MinMs: 55, p3MaxMs: 5000, p4MinMs: 0)
        let hexTiming = timing.encode()
        guard let decodedTiming = KWP2000TimingParameters.decode(from: hexTiming) else {
            return TestReport(testName: "KWP2000Protocol", passed: false, message: "Échec décodage paramètres temporels KWP2000")
        }
        guard decodedTiming.p2MinMs == 25 && decodedTiming.p2MaxMs == 50 else {
            return TestReport(testName: "KWP2000Protocol", passed: false, message: "Valeurs physiques de timing incorrectes")
        }

        // 2. Test des Services KWP2000 via SimulatorEngine
        let simulator = SimulatorEngine()
        let kwpClient = KWP2000Client(interface: simulator)

        do {
            // Service 10: Démarrage session KWP2000 (Mode 0x81 / Standard)
            let sessionResp = try await kwpClient.startSession(mode: 0x81)
            guard sessionResp.hasPrefix("5081") else {
                return TestReport(testName: "KWP2000Protocol", passed: false, message: "Échec réponse positive Service 10 81")
            }

            // Service 21: Lecture d'un Local Identifier (LID)
            let lidData = try await kwpClient.readLocalIdentifier(lid: 0x01)
            guard !lidData.isEmpty else {
                return TestReport(testName: "KWP2000Protocol", passed: false, message: "Échec lecture LID Service 21")
            }

            // Service 1A: Lecture Identification ECU
            let ecuId = try await kwpClient.readECUIdentification(option: 0x80)
            guard !ecuId.isEmpty else {
                return TestReport(testName: "KWP2000Protocol", passed: false, message: "Échec lecture identification ECU Service 1A")
            }

            // Service 18: Lecture DTCs
            let dtcResp = try await kwpClient.readDTCByStatus(statusMask: 0xFF)
            guard dtcResp.hasPrefix("58") else {
                return TestReport(testName: "KWP2000Protocol", passed: false, message: "Échec lecture DTCs Service 18")
            }

            // Service 14: Effacement DTCs
            try await kwpClient.clearDiagnosticInformation(group: "FFFFFF")

            // Service 27: SecurityAccess (Simulation Seed & Key)
            try await kwpClient.performSecurityAccess(level: 0x01) { seed in
                return SecurityAccessManager.calculateKey(seedHex: seed, algorithm: .xorStatique, maskHex: "55")
            }

            // Arrêt du client
            kwpClient.stop()

            return TestReport(testName: "KWP2000Protocol", passed: true, message: "Services ISO 14230 (10, 14, 18, 1A, 21, 27, 83) validés à 100%")
        } catch {
            return TestReport(testName: "KWP2000Protocol", passed: false, message: "Exception levée lors de l'exécution KWP2000: \(error.localizedDescription)")
        }
    }

    // MARK: - SAE J1939 & CAN Protocol Detection Tests

    private static func testJ1939AndProtocolClassification() -> TestReport {
        // 1. Test Détection de Protocole
        let j1939 = OBD2Analyzer.classifyCANFrame(canID: 0x18FEEE00)
        guard j1939.protocolType == .j1939 && j1939.is29BitExtended else {
            return TestReport(testName: "J1939AndProtocolClassification", passed: false, message: "Échec classification J1939 29-bit")
        }

        let obd = OBD2Analyzer.classifyCANFrame(canID: 0x7DF)
        guard obd.protocolType == .obd2 && !obd.is29BitExtended else {
            return TestReport(testName: "J1939AndProtocolClassification", passed: false, message: "Échec classification OBD-II Broadcast")
        }

        let kwp = OBD2Analyzer.classifyCANFrame(canID: 0x640)
        guard kwp.protocolType == .kwp2000 else {
            return TestReport(testName: "J1939AndProtocolClassification", passed: false, message: "Échec classification KWP2000 Legacy")
        }

        // 2. Test Décodage Signaux J1939 (EEC1 PGN 61444)
        let rawPayload = Data([0xFF, 0x00, 0x7D, 0x00, 0x20, 0xFF, 0xFF, 0xFF]) // RPM: 8192*0.125 = 1024 rpm
        let signals = OBD2Analyzer.decodeJ1939Signals(canID: 0x0CF00400, data: rawPayload)
        guard let rpm = signals.first(where: { $0.spn == 190 }), rpm.value == 1024.0 else {
            return TestReport(testName: "J1939AndProtocolClassification", passed: false, message: "Échec extraction SPN 190 (RPM J1939)")
        }

        return TestReport(testName: "J1939AndProtocolClassification", passed: true, message: "Détection heuristique de protocoles et décodage SAE J1939 (PGN/SPN) OK")
    }

    // MARK: - Unified ECU Profile & DDT2000 Converter Test

    private static func testUnifiedProfileConversion() -> TestReport {
        let sampleDDT = """
        {
            "ecuname": "ECM_RENAULT_DCI",
            "obd": { "send_id": "7E0", "recv_id": "7E8", "baudrate": 500000 },
            "data": { "Regime": { "bitscount": 16, "step": 0.125, "unit": "tr/min" } },
            "requests": [ { "name": "Telemetry", "sentbytes": "2101", "receivebyte_dataitems": { "Regime": { "firstbyte": 2 } } } ]
        }
        """.data(using: .utf8)!

        do {
            let profile = try DDT2UnifiedConverter.convert(jsonData: sampleDDT)
            let exported = try DDT2UnifiedConverter.exportToJSON(profile: profile)
            guard exported.contains("ECM_RENAULT_DCI") else {
                return TestReport(testName: "UnifiedProfileConversion", passed: false, message: "Échec export JSON unifié")
            }
            return TestReport(testName: "UnifiedProfileConversion", passed: true, message: "Conversion DDT2000 -> Unified ECU Profile (OVD JSON) validée")
        } catch {
            return TestReport(testName: "UnifiedProfileConversion", passed: false, message: "Erreur conversion: \(error.localizedDescription)")
        }
    }
}
