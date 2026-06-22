import SwiftUI


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
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("SAUVEGARDE & PERSISTANCE")
                                            .font(.cardTitle)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            
                                        if let vehicle = activeVehicle, let profile = activeProfile {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Véhicule actif : \(vehicle.displayName)")
                                                    .font(.bodyText)
                                                    .bold()
                                                Text("Profil : \(profile.displayName) (v\(profile.profileVersion))")
                                                    .font(.captionText)
                                                    .foregroundStyle(.secondary)
                                                
                                                HStack(spacing: 12) {
                                                    Button("Enrichir le profil", systemImage: "plus.square.dashed", action: enrichActiveProfile)
                                                        .glassActionButton(prominent: true)
                                                    
                                                    Button("Exporter JSON", systemImage: "doc.badge.plus", action: exportCANFuzzResults)
                                                        .glassActionButton(prominent: false)
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding(12)
                                            .background(Color.white.opacity(0.02))
                                            .clipShape(.rect(cornerRadius: 8))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                            }
                                        } else {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Aucun véhicule sélectionné comme actif")
                                                    .font(.bodyText)
                                                    .foregroundStyle(.secondary)
                                                Text("Veuillez sélectionner un véhicule dans le garage de l'application pour activer l'enrichissement de profil et l'export.")
                                                    .font(.captionTiny)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(12)
                                            .background(Color.white.opacity(0.02))
                                            .clipShape(.rect(cornerRadius: 8))
                                        }
                                        
                                        saveMessagePanel
                                    }
                                    .padding(.vertical, 8)
                                }
                            } else {
                                // Section d'analyse de signaux en temps réel
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Configuration du LID")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                    
                                    HStack {
                                        Text("ECU Cible (Hex)")
                                            .font(.bodyText)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        TextField("7E0", text: $targetEcu)
                                            .textFieldStyle(.roundedBorder)
                                            .multilineTextAlignment(.trailing)
                                            .font(.monoSmall)
                                            .frame(width: 100)
                                            .foregroundStyle(.white)
                                    }
                                    HStack {
                                        Text("LID Cible (Hex)")
                                            .font(.bodyText)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        TextField("01", text: $targetLidHex)
                                            .textFieldStyle(.roundedBorder)
                                            .multilineTextAlignment(.trailing)
                                            .font(.monoSmall)
                                            .frame(width: 100)
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Analyse de Corrélation")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                    
                                    if fuzzer.isRunning {
                                        Button(action: stopCorrelation) {
                                            HStack {
                                                Spacer()
                                                ProgressView()
                                                    .padding(.trailing, 8)
                                                Text("Arrêter l'Analyse")
                                                Spacer()
                                            }
                                            .font(.appButton)
                                        }
                                        .glassActionButton(prominent: true)
                                        .foregroundStyle(.red)
                                    } else {
                                        Button(action: startCorrelation) {
                                            Text("Démarrer l'Analyse")
                                                .font(.appButton)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .glassActionButton(prominent: true)
                                    }
                                    
                                    if fuzzer.analyzedFrameCount > 0 {
                                        HStack {
                                            Text("Trames analysées")
                                                .font(.captionText)
                                            Spacer()
                                            Text("\(fuzzer.analyzedFrameCount)")
                                                .font(.valueNumber)
                                                .foregroundStyle(Color.appAccent)
                                        }
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Rapports de Pearson (Temps Réel)")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                    
                                    if fuzzer.correlations.isEmpty {
                                        VStack(alignment: .center, spacing: 8) {
                                            Image(systemName: "waveform.path.ecg")
                                                .font(.largeTitle)
                                                .foregroundStyle(.tertiary)
                                            Text("En attente d'acquisition...")
                                                .font(.statusText)
                                                .foregroundStyle(.secondary)
                                            Text("Accélérez ou faites varier l'état pour corréler les signaux.")
                                                .font(.captionTiny)
                                                .foregroundStyle(.tertiary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                    } else {
                                        ForEach(fuzzer.correlations) { result in
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text("Tranche \(result.sliceName)")
                                                        .font(.monoSmall)
                                                        .bold()
                                                        .foregroundStyle(.white)
                                                    Spacer()
                                                    Text(result.classification)
                                                        .font(.captionTiny)
                                                        .bold()
                                                        .foregroundStyle(colorForClassification(result.classification))
                                                }
                                                
                                                HStack(spacing: 8) {
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .fill(Color.white.opacity(0.1))
                                                            .frame(height: 6)
                                                        
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .fill(colorForCoefficient(result.coefficient))
                                                            .frame(height: 6)
                                                            .visualEffect { content, geometry in
                                                                content.scaleEffect(x: CGFloat(abs(result.coefficient)), y: 1.0, anchor: .leading)
                                                            }
                                                    }
                                                    .frame(height: 6)
                                                    
                                                    Text("\((result.coefficient * 100).formatted(.number.precision(.fractionLength(1))))%")
                                                        .font(.valueNumber)
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 55, alignment: .trailing)
                                                }
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.white.opacity(0.02))
                                            .clipShape(.rect(cornerRadius: 8))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // LIN Bus Views
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Configuration LIN")
                                    .font(.cardTitle)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text("Ligne LIN (Matériel)")
                                        .font(.bodyText)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Picker("Port", selection: $linUartPort) {
                                        Text("LIN 1 (USART3)").tag(UInt16(1))
                                        Text("LIN 2 (UART5)").tag(UInt16(2))
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                HStack {
                                    Text("Vitesse (Baudrate)")
                                        .font(.bodyText)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Picker("Baudrate", selection: $linBaudRate) {
                                        Text("19200 bps").tag(UInt32(19200))
                                        Text("10400 bps").tag(UInt32(10400))
                                        Text("9600 bps").tag(UInt32(9600))
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                HStack {
                                    Text("Mode Somme de Contrôle")
                                        .font(.bodyText)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Picker("Checksum", selection: $useEnhancedChecksum) {
                                        Text("Amélioré (LIN 2.0)").tag(true)
                                        Text("Classique (LIN 1.3)").tag(false)
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Picker("Mode LIN", selection: $linSubTab) {
                                Text("Sniffer").tag(0)
                                Text("Balayage").tag(1)
                                Text("Injecteur").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 8)
                            
                            if linSubTab == 0 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Écoute passive du Bus")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                    
                                    if linFuzzer.isRunning {
                                        Button(action: stopLINSniffing) {
                                            HStack {
                                                Spacer()
                                                ProgressView()
                                                    .padding(.trailing, 8)
                                                Text("Arrêter le Sniffing")
                                                Spacer()
                                            }
                                            .font(.appButton)
                                        }
                                        .glassActionButton(prominent: true)
                                        .foregroundStyle(.red)
                                    } else {
                                        Button(action: startLINSniffing) {
                                            Text("Démarrer le Sniffing")
                                                .font(.appButton)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .glassActionButton(prominent: true)
                                    }
                                    
                                    if let error = linFuzzer.actionError {
                                        Text(error)
                                            .font(.statusText)
                                            .foregroundStyle(.red)
                                    }
                                    
                                    if linFuzzer.sniffedPacketList.isEmpty {
                                        VStack(spacing: 8) {
                                            Image(systemName: "waveform.path")
                                                .font(.largeTitle)
                                                .foregroundStyle(.tertiary)
                                            Text("Aucune trame capturée")
                                                .font(.statusText)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                    } else {
                                        ScrollView(.horizontal) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(spacing: 12) {
                                                    Text("ID").font(.monoSmall).bold().frame(width: 40, alignment: .leading)
                                                    Text("PID").font(.monoSmall).bold().frame(width: 40, alignment: .leading)
                                                    Text("Données (Hex)").font(.monoSmall).bold().frame(width: 140, alignment: .leading)
                                                    Text("Période").font(.monoSmall).bold().frame(width: 60, alignment: .trailing)
                                                    Text("Trames").font(.monoSmall).bold().frame(width: 50, alignment: .trailing)
                                                    Text("CS").font(.monoSmall).bold().frame(width: 40, alignment: .center)
                                                }
                                                .foregroundStyle(.secondary)
                                                
                                                Divider().background(Color.white.opacity(0.1))
                                                
                                                ForEach(linFuzzer.sniffedPacketList) { packet in
                                                    HStack(spacing: 12) {
                                                        Text("0x" + (packet.rawID < 16 ? "0" : "") + String(packet.rawID, radix: 16, uppercase: true))
                                                            .font(.monoSmall)
                                                            .frame(width: 40, alignment: .leading)
                                                            .foregroundStyle(Color.appAccent)
                                                        
                                                        Text("0x" + (packet.pid < 16 ? "0" : "") + String(packet.pid, radix: 16, uppercase: true))
                                                            .font(.monoSmall)
                                                            .frame(width: 40, alignment: .leading)
                                                            .foregroundStyle(.secondary)
                                                        
                                                        Text(packet.lastData.map { ($0 < 16 ? "0" : "") + String($0, radix: 16, uppercase: true) }.joined(separator: " "))
                                                            .font(.monoSmall)
                                                            .frame(width: 140, alignment: .leading)
                                                            .lineLimit(1)
                                                        
                                                        Text(packet.periodMs > 0 ? "\(packet.periodMs.formatted(.number.precision(.fractionLength(1)))) ms" : "—")
                                                            .font(.monoSmall)
                                                            .frame(width: 60, alignment: .trailing)
                                                            .foregroundStyle(.secondary)
                                                        
                                                        Text("\(packet.packetCount)")
                                                            .font(.monoSmall)
                                                            .frame(width: 50, alignment: .trailing)
                                                        
                                                        let isValid = useEnhancedChecksum ? packet.isEnhancedChecksumValid : packet.isClassicChecksumValid
                                                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                                            .foregroundStyle(isValid ? Color.green : Color.orange)
                                                            .frame(width: 40, alignment: .center)
                                                    }
                                                    .padding(.vertical, 4)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else if linSubTab == 1 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Balayage d'Identifiants LIN")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Envoie séquentiellement des en-têtes LIN Master (PIDs 0x00-0x3F) pour provoquer et écouter les réponses des esclaves connectés.")
                                        .font(.captionText)
                                        .foregroundStyle(.secondary)
                                    
                                    if linFuzzer.isRunning {
                                        VStack(spacing: 8) {
                                            Button(action: stopLINFuzzer) {
                                                HStack {
                                                    Spacer()
                                                    ProgressView()
                                                        .padding(.trailing, 8)
                                                    Text("Arrêter le Balayage")
                                                    Spacer()
                                                }
                                                .font(.appButton)
                                            }
                                            .glassActionButton(prominent: true)
                                            .foregroundStyle(.red)
                                            
                                            ProgressView(value: linFuzzer.currentProgress)
                                                .tint(Color.appAccent)
                                        }
                                    } else {
                                        Button(action: startLINPIDScan) {
                                            Text("Démarrer le Balayage")
                                                .font(.appButton)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .glassActionButton(prominent: true)
                                    }
                                    
                                    if let error = linFuzzer.actionError {
                                        Text(error)
                                            .font(.statusText)
                                            .foregroundStyle(.red)
                                    }
                                    
                                    if !linFuzzer.discoveredPIDs.isEmpty {
                                        Text("Identifiants actifs détectés (\(linFuzzer.discoveredPIDs.count))")
                                            .font(.captionText)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                        
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                                            ForEach(linFuzzer.discoveredPIDs, id: \.self) { rawID in
                                                Text("0x" + (rawID < 16 ? "0" : "") + String(rawID, radix: 16, uppercase: true))
                                                    .font(.monoSmall)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 10)
                                                    .background(Color.appAccent.opacity(0.1))
                                                    .clipShape(.rect(cornerRadius: 6))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                                                    }
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Injecteur de Trames Master")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                    
                                    HStack {
                                        Text("ID brut (Hex, 00-3F)")
                                            .font(.bodyText)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        TextField("00", text: $injectRawIdHex)
                                            .textFieldStyle(.roundedBorder)
                                            .multilineTextAlignment(.trailing)
                                            .font(.monoSmall)
                                            .frame(width: 80)
                                            .foregroundStyle(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Données (Hex, octets séparés par des espaces)")
                                            .font(.captionText)
                                            .foregroundStyle(.secondary)
                                        TextField("11 22 33 44", text: $injectDataHex)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.monoSmall)
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Button(action: injectLINFrame) {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "paperplane.fill")
                                            Text("Injecter la Trame")
                                            Spacer()
                                        }
                                        .font(.appButton)
                                    }
                                    .glassActionButton(prominent: true)
                                    .padding(.top, 8)
                                    
                                    if let error = linFuzzer.actionError {
                                        Text(error)
                                            .font(.statusText)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            
                            if !linFuzzer.sniffedPacketList.isEmpty || !linFuzzer.discoveredPIDs.isEmpty {
                                Divider().background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("SAUVEGARDE & PERSISTANCE")
                                        .font(.cardTitle)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        
                                    if let vehicle = activeVehicle {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Véhicule actif : \(vehicle.displayName)")
                                                .font(.bodyText)
                                                .bold()
                                            
                                            Button("Exporter les trames LIN (JSON)", systemImage: "doc.badge.plus", action: exportLINFuzzResults)
                                                .glassActionButton(prominent: true)
                                                .padding(.top, 4)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.02))
                                        .clipShape(.rect(cornerRadius: 8))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Aucun véhicule sélectionné comme actif")
                                                .font(.bodyText)
                                                .foregroundStyle(.secondary)
                                            Text("Veuillez sélectionner un véhicule dans le garage de l'application pour activer l'export des trames LIN.")
                                                .font(.captionTiny)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.02))
                                        .clipShape(.rect(cornerRadius: 8))
                                    }
                                    
                                    saveMessagePanel
                                }
                                .padding(.vertical, 8)
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
        .onChange(of: selectedLidPreset) { oldValue, newValue in
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
    
    private func colorForClassification(_ classification: String) -> Color {
        if classification.contains("FORT") {
            return Color.green
        } else if classification.contains("potentiel") {
            return Color.appAccent
        } else if classification.contains("Constant") {
            return Color.secondary
        }
        return Color.secondary
    }
    
    @ViewBuilder
    private var saveMessagePanel: some View {
        if let msg = saveSuccessMessage {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(msg)
                    .font(.captionText)
                    .foregroundStyle(.green)
            }
            .padding(10)
            .background(Color.green.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
            .padding(.top, 8)
        }
        
        if let err = saveErrorMessage {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(err)
                    .font(.captionText)
                    .foregroundStyle(.red)
            }
            .padding(10)
            .background(Color.red.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
            .padding(.top, 8)
        }
    }
    
    private func colorForCoefficient(_ coef: Double) -> Color {
        if coef >= 0.75 {
            return Color.green
        } else if coef <= -0.75 {
            return Color.orange
        } else if coef >= 0.50 {
            return Color.appAccent
        }
        return Color.secondary
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
        
        guard let vehicle = activeVehicle, let profile = activeProfile else {
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
