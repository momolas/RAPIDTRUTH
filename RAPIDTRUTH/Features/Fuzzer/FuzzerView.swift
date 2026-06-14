import SwiftUI


struct FuzzerView: View {
    let interface: VehicleInterface
    @State private var fuzzer = OBDFuzzer()
    
    @State private var targetEcu: String = "7E0"
    @State private var startLidHex: String = "00"
    @State private var endLidHex: String = "FF"
    @State private var agreedToRisks: Bool = false
    @State private var selectedPreset: ScanPreset = .rapid
    @State private var selectedLidPreset: LidPreset = .all
    
    // Reverse Engineering state properties
    @State private var selectedTab: Int = 0 // 0: Balayage LIDs (Fuzzer), 1: Corrélation (Reverse Engineering)
    @State private var targetLidHex: String = "01"

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
                    }
                }
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Fuzzer OBD & Corrélation")
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
            if let panda = interface as? PandaDriver {
                Task {
                    try? await panda.setSafetyModel(.allOutput)
                    NSLog("[FuzzerView] Kept Panda safety model as ALLOUTPUT")
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
}
