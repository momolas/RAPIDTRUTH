import SwiftUI
import SwiftVehicleProtocols

struct FuzzerView: View {
    let interface: VehicleInterface
    @Environment(SettingsStore.self) private var settings
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(ProfileRegistry.self) private var profileRegistry
    
    @State private var fuzzer = OBDFuzzer()
    
    @State private var targetEcu: String = "7E0"
    @State private var startLidHex: String = "00"
    @State private var endLidHex: String = "FF"
    @State private var agreedToRisks: Bool = false
    @State private var selectedPreset: ScanPreset = .rapid
    @State private var selectedLidPreset: LidPreset = .all
    
    @State private var saveSuccessMessage: String? = nil
    @State private var saveErrorMessage: String? = nil
    
    // Reverse Engineering state properties
    @State private var selectedTab: Int = 0 // 0: Balayage LIDs (Fuzzer), 1: Corrélation (Reverse Engineering)
    @State private var targetLidHex: String = "01"

    // LIN states
    @State private var fuzzerMode = 0 // 0: CAN / OBD, 1: LIN
    @State private var linFuzzer = LINFuzzer()
    @State private var linUartPort: UInt16 = 1
    @State private var linBaudRate: UInt32 = 19200
    @State private var useEnhancedChecksum = true
    @State private var linSubTab = 0 // 0: Sniffer, 1: Balayage, 2: Injecteur
    @State private var injectRawIdHex = "00"
    @State private var injectDataHex = "00 00 00 00"

    init(interface: VehicleInterface) {
        self.interface = interface
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    if !agreedToRisks {
                        FuzzerSafetyWarningView(agreedToRisks: $agreedToRisks)
                    } else {
                        Picker("Sélection Bus", selection: $fuzzerMode) {
                            Text("CAN / OBD").tag(0)
                            Text("LIN Bus").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)
                        
                        if fuzzerMode == 0 {
                            Picker("Mode Fuzzer", selection: $selectedTab) {
                                Text("Balayage LIDs").tag(0)
                                Text("Corrélation TR").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
                            
                            if selectedTab == 0 {
                                FuzzerNetworkDiscoverySection(
                                    interface: interface,
                                    fuzzer: fuzzer,
                                    selectedPreset: $selectedPreset,
                                    targetEcu: $targetEcu
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                FuzzerConfigSection(
                                    selectedLidPreset: $selectedLidPreset,
                                    targetEcu: $targetEcu,
                                    startLidHex: $startLidHex,
                                    endLidHex: $endLidHex
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                FuzzerExecutionSection(
                                    fuzzer: fuzzer,
                                    onStartFuzzing: startFuzzing
                                )
                                
                                FuzzerResultsSection(fuzzer: fuzzer)
                                
                                if !fuzzer.results.isEmpty || !fuzzer.discoveredECUs.isEmpty {
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    FuzzerPersistenceSection(
                                        vehicle: activeVehicle,
                                        profile: activeProfile,
                                        hasCANResults: !fuzzer.results.isEmpty || !fuzzer.discoveredECUs.isEmpty,
                                        hasLINResults: false,
                                        isLINMode: false,
                                        saveSuccessMessage: saveSuccessMessage,
                                        saveErrorMessage: saveErrorMessage,
                                        onEnrichProfile: enrichActiveProfile,
                                        onExportCAN: exportCANFuzzResults,
                                        onExportLIN: exportLINFuzzResults
                                    )
                                }
                            } else {
                                FuzzerSignalCorrelationSection(
                                    interface: interface,
                                    fuzzer: fuzzer,
                                    targetEcu: $targetEcu,
                                    targetLidHex: $targetLidHex,
                                    onStartCorrelation: startCorrelation,
                                    onStopCorrelation: stopCorrelation
                                )
                            }
                        } else {
                            FuzzerLINSection(
                                interface: interface,
                                linFuzzer: linFuzzer,
                                linUartPort: $linUartPort,
                                linBaudRate: $linBaudRate,
                                useEnhancedChecksum: $useEnhancedChecksum,
                                linSubTab: $linSubTab,
                                injectRawIdHex: $injectRawIdHex,
                                injectDataHex: $injectDataHex,
                                onStartSniffing: startLINSniffing,
                                onStopSniffing: stopLINSniffing,
                                onStartScan: startLINPIDScan,
                                onStopScan: stopLINFuzzer,
                                onInjectFrame: injectLINFrame
                            )
                            
                            if !linFuzzer.sniffedPacketList.isEmpty || !linFuzzer.discoveredPIDs.isEmpty {
                                Divider().background(Color.white.opacity(0.1))
                                
                                FuzzerPersistenceSection(
                                    vehicle: activeVehicle,
                                    profile: activeProfile,
                                    hasCANResults: false,
                                    hasLINResults: !linFuzzer.sniffedPacketList.isEmpty || !linFuzzer.discoveredPIDs.isEmpty,
                                    isLINMode: true,
                                    saveSuccessMessage: saveSuccessMessage,
                                    saveErrorMessage: saveErrorMessage,
                                    onEnrichProfile: enrichActiveProfile,
                                    onExportCAN: exportCANFuzzResults,
                                    onExportLIN: exportLINFuzzResults
                                )
                            }
                        }
                    }
                }
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(fuzzerMode == 0 ? "Fuzzer OBD & Corrélation" : "LIN Sniffer & Fuzzer")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedLidPreset) { _, newValue in
            if newValue != .custom {
                startLidHex = newValue.startHex
                endLidHex = newValue.endHex
            }
        }
        .task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
                NSLog("[FuzzerView] Switched Panda safety model to ALLOUTPUT for coding")
            }
        }
        .onDisappear {
            fuzzer.isRunning = false
            linFuzzer.stop()
            if let panda = interface as? PandaDriver {
                Task {
                    try? await panda.setSafetyModel(.silent)
                    NSLog("[FuzzerView] Switched Panda safety model back to SILENT")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startFuzzing() {
        guard let start = Int(startLidHex, radix: 16),
              let end = Int(endLidHex, radix: 16),
              start <= end else {
            fuzzer.actionError = "Valeurs hexadécimales invalides."
            return
        }
        
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            await fuzzer.fuzzKWP2000LIDs(interface: interface, ecu: targetEcu, startLid: start, endLid: end)
        }
    }
    
    private func startCorrelation() {
        guard targetLidHex.count == 2, Int(targetLidHex, radix: 16) != nil else {
            fuzzer.actionError = "Le LID cible doit être de 2 caractères hexadécimaux."
            return
        }
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            await fuzzer.analyzeLIDCorrelation(interface: interface, ecu: targetEcu, lidHex: targetLidHex)
        }
    }
    
    private func stopCorrelation() {
        fuzzer.cancel()
    }
    
    private func startLINSniffing() {
        guard let panda = interface as? PandaDriver else { return }
        Task {
            await linFuzzer.startSniffing(driver: panda, uartPort: linUartPort, baudRate: linBaudRate)
        }
    }
    
    private func stopLINSniffing() {
        linFuzzer.stop()
    }
    
    private func startLINPIDScan() {
        guard let panda = interface as? PandaDriver else { return }
        Task {
            await linFuzzer.startPIDScan(driver: panda, uartPort: linUartPort, baudRate: linBaudRate)
        }
    }
    
    private func stopLINFuzzer() {
        linFuzzer.stop()
    }
    
    private func injectLINFrame() {
        guard let panda = interface as? PandaDriver else { return }
        let cleanId = injectRawIdHex.replacing("0x", with: "").trimmingCharacters(in: .whitespaces)
        guard let rawID = UInt8(cleanId, radix: 16), rawID <= 0x3F else {
            linFuzzer.actionError = "ID LIN invalide (doit être entre 00 et 3F)."
            return
        }
        
        let hexBytes = injectDataHex.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var data = Data()
        for hex in hexBytes {
            let cleanHex = hex.replacing("0x", with: "")
            if let byte = UInt8(cleanHex, radix: 16) {
                data.append(byte)
            } else {
                linFuzzer.actionError = "Octet de données hexadécimal invalide : \(hex)"
                return
            }
        }
        
        Task {
            await linFuzzer.injectFrame(driver: panda, uartPort: linUartPort, baudRate: linBaudRate, rawID: rawID, data: data)
        }
    }
    
    // MARK: - Active Vehicle & Profile Helpers

    private var activeVehicle: Vehicle? {
        guard let slug = settings.activeVehicleSlug else { return nil }
        return vehicleStore.vehicles.first { $0.slug == slug }
    }
    
    private var activeProfile: Profile? {
        guard let vehicle = activeVehicle else { return nil }
        return profileRegistry.profile(id: vehicle.profileId)
    }

    // MARK: - Save and Export Actions

    private func enrichActiveProfile() {
        saveSuccessMessage = nil
        saveErrorMessage = nil
        
        guard activeVehicle != nil, let profile = activeProfile else {
            saveErrorMessage = "Aucun véhicule ou profil actif sélectionné."
            return
        }
        
        guard !fuzzer.discoveredECUs.isEmpty || !fuzzer.supportedLIDs.isEmpty else {
            saveErrorMessage = "Aucun résultat de fuzzing à enregistrer."
            return
        }
        
        do {
            let enriched = ProfileEnricher.enrich(
                profile: profile,
                discoveredECUs: fuzzer.discoveredECUs,
                supportedLIDs: fuzzer.supportedLIDs
            )
            
            let tempURL = FileManager.default.temporaryDirectory.appending(path: "\(profile.profileId)_temp.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(enriched)
            try data.write(to: tempURL, options: .atomic)
            
            _ = try ProfileImporter.importProfile(from: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            
            profileRegistry.reload()
            saveSuccessMessage = "Profil « \(profile.displayName) » enrichi avec succès ! Les nouveaux PIDs sont disponibles en Temps Réel."
        } catch {
            saveErrorMessage = "Erreur lors de la sauvegarde : \(error.localizedDescription)"
        }
    }

    private func exportCANFuzzResults() {
        saveSuccessMessage = nil
        saveErrorMessage = nil
        
        guard let vehicle = activeVehicle else {
            saveErrorMessage = "Aucun véhicule actif sélectionné."
            return
        }
        
        guard !fuzzer.discoveredECUs.isEmpty || !fuzzer.supportedLIDs.isEmpty || !fuzzer.results.isEmpty else {
            saveErrorMessage = "Aucun résultat de fuzzing CAN à exporter."
            return
        }
        
        let timestamp = Date.now.formatted(.iso8601)
            .replacing("-", with: "")
            .replacing(":", with: "")
            .replacing("T", with: "_")
            .replacing("Z", with: "")
        
        let filename = "fuzzer_can_results_\(timestamp).json"
        let relativePath = AppPath.vehicleDir(vehicle.owner, vehicle.slug) + "/\(filename)"
        
        struct CANExportData: Codable {
            let timestamp: String
            let vehicleSlug: String
            let vehicleName: String
            let discoveredECUs: [String]
            let supportedLIDs: [String: [String]]
            let results: [FuzzExportResult]
        }
        
        struct FuzzExportResult: Codable {
            let did: String
            let response: String
        }
        
        let exportResults = fuzzer.results.map { FuzzExportResult(did: $0.did, response: $0.response) }
        
        let exportData = CANExportData(
            timestamp: Date.now.formatted(.iso8601),
            vehicleSlug: vehicle.slug,
            vehicleName: vehicle.displayName,
            discoveredECUs: fuzzer.discoveredECUs,
            supportedLIDs: fuzzer.supportedLIDs,
            results: exportResults
        )
        
        do {
            try AppStorage.shared.writeJSON(exportData, to: relativePath)
            saveSuccessMessage = "Résultats CAN exportés avec succès :\n\(filename)"
        } catch {
            saveErrorMessage = "Échec de l'export : \(error.localizedDescription)"
        }
    }

    private func exportLINFuzzResults() {
        saveSuccessMessage = nil
        saveErrorMessage = nil
        
        guard let vehicle = activeVehicle else {
            saveErrorMessage = "Aucun véhicule actif sélectionné."
            return
        }
        
        guard !linFuzzer.sniffedPacketList.isEmpty || !linFuzzer.discoveredPIDs.isEmpty else {
            saveErrorMessage = "Aucun résultat de fuzzing/sniffing LIN à exporter."
            return
        }
        
        let timestamp = Date.now.formatted(.iso8601)
            .replacing("-", with: "")
            .replacing(":", with: "")
            .replacing("T", with: "_")
            .replacing("Z", with: "")
            
        let filename = "fuzzer_lin_results_\(timestamp).json"
        let relativePath = AppPath.vehicleDir(vehicle.owner, vehicle.slug) + "/\(filename)"
        
        struct LINExportPacket: Codable {
            let rawID: UInt8
            let pid: UInt8
            let lastDataHex: String
            let packetCount: Int
            let periodMs: Double
            let isClassicChecksumValid: Bool
            let isEnhancedChecksumValid: Bool
        }
        
        struct LINExportData: Codable {
            let timestamp: String
            let vehicleSlug: String
            let vehicleName: String
            let discoveredPIDs: [UInt8]
            let sniffedPackets: [LINExportPacket]
        }
        
        let exportPackets = linFuzzer.sniffedPacketList.map { packet in
            LINExportPacket(
                rawID: packet.rawID,
                pid: packet.pid,
                lastDataHex: packet.lastData.map { String(format: "%02X", $0) }.joined(separator: " "),
                packetCount: packet.packetCount,
                periodMs: packet.periodMs,
                isClassicChecksumValid: packet.isClassicChecksumValid,
                isEnhancedChecksumValid: packet.isEnhancedChecksumValid
            )
        }
        
        let exportData = LINExportData(
            timestamp: Date.now.formatted(.iso8601),
            vehicleSlug: vehicle.slug,
            vehicleName: vehicle.displayName,
            discoveredPIDs: linFuzzer.discoveredPIDs,
            sniffedPackets: exportPackets
        )
        
        do {
            try AppStorage.shared.writeJSON(exportData, to: relativePath)
            saveSuccessMessage = "Résultats LIN exportés avec succès :\n\(filename)"
        } catch {
            saveErrorMessage = "Échec de l'export : \(error.localizedDescription)"
        }
    }
}
