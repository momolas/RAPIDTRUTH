import SwiftUI

enum ScanPreset: String, CaseIterable, Identifiable {
    case rapid = "Rapide (Standard + Renault)"
    case standard11bit = "Exhaustif 11-bit (700-7EF)"
    case standard29bit = "Exhaustif 29-bit (18DAxxF1)"
    
    var id: String { self.rawValue }
}

enum DidPreset: String, CaseIterable, Identifiable {
    case LowerRange = "Registre Bas (0000-00FF)"
    case dynamicRange = "Registre Dynamique (D000-D0FF)"
    case udsIdent = "Identification UDS (F180-F1AF)"
    case custom = "Personnalisé"
    
    var id: String { self.rawValue }
    
    var startHex: String {
        switch self {
        case .udsIdent: return "F180"
        case .LowerRange: return "0000"
        case .dynamicRange: return "D000"
        case .custom: return ""
        }
    }
    
    var endHex: String {
        switch self {
        case .udsIdent: return "F1AF"
        case .LowerRange: return "00FF"
        case .dynamicRange: return "D0FF"
        case .custom: return ""
        }
    }
}

struct FuzzerView: View {
    let interface: VehicleInterface
    @Environment(\.dismiss) var dismiss
    @State private var fuzzer = OBDFuzzer()
    
    @State private var targetEcu: String = "7E0"
    @State private var startDidHex: String = "0000"
    @State private var endDidHex: String = "00FF"
    @State private var agreedToRisks: Bool = false
    @State private var selectedPreset: ScanPreset = .rapid
    @State private var selectedDidPreset: DidPreset = .LowerRange
    
    // Reverse Engineering state properties
    @State private var selectedTab: Int = 0 // 0: Balayage DIDs (Fuzzer), 1: Corrélation (Reverse Engineering)
    @State private var targetDidHex: String = "2101"
    
    var body: some View {
        NavigationStack {
            Form {
                if !agreedToRisks {
                    FuzzerSafetyWarningView(agreedToRisks: $agreedToRisks)
                } else {
                    Picker("Mode Fuzzer", selection: $selectedTab) {
                        Text("Balayage DIDs").tag(0)
                        Text("Corrélation TR (Reverse)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    
                    if selectedTab == 0 {
                        FuzzerNetworkDiscoverySection(
                            interface: interface,
                            fuzzer: fuzzer,
                            selectedPreset: $selectedPreset,
                            targetEcu: $targetEcu
                        )
                        FuzzerConfigSection(
                            selectedDidPreset: $selectedDidPreset,
                            targetEcu: $targetEcu,
                            startDidHex: $startDidHex,
                            endDidHex: $endDidHex
                        )
                        FuzzerExecutionSection(
                            fuzzer: fuzzer,
                            onStartFuzzing: startFuzzing
                        )
                        FuzzerResultsSection(fuzzer: fuzzer)
                    } else {
                        // Section d'analyse de signaux en temps réel
                        Section(header: Text("Configuration du DID").font(.cardTitle)) {
                            HStack {
                                Text("ECU Cible (Hex)")
                                Spacer()
                                TextField("7E0", text: $targetEcu)
                                    .multilineTextAlignment(.trailing)
                                    .font(.monoSmall)
                                    .frame(width: 80)
                            }
                            HStack {
                                Text("DID Cible (Hex)")
                                Spacer()
                                TextField("2101", text: $targetDidHex)
                                    .multilineTextAlignment(.trailing)
                                    .font(.monoSmall)
                                    .frame(width: 80)
                            }
                        }
                        
                        Section(header: Text("Analyse de Corrélation").font(.cardTitle)) {
                            if fuzzer.isRunning {
                                Button(role: .destructive, action: stopCorrelation) {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding(.trailing, 8)
                                        Text("Arrêter l'Analyse")
                                            .font(.appButton)
                                        Spacer()
                                    }
                                }
                                .glassActionButton(prominent: true)
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
                        
                        Section(header: Text("Rapports de Pearson (Temps Réel)").font(.cardTitle)) {
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
            .navigationTitle("Fuzzer OBD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: selectedDidPreset) { oldValue, newValue in
                if newValue != .custom {
                    startDidHex = newValue.startHex
                    endDidHex = newValue.endHex
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
                        try? await panda.setSafetyModel(.elm327)
                        NSLog("[FuzzerView] Restored Panda safety model to ELM327")
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startFuzzing() {
        guard let start = Int(startDidHex, radix: 16),
              let end = Int(endDidHex, radix: 16),
              start <= end else {
            fuzzer.actionError = "Valeurs hexadécimales invalides."
            return
        }
        
        Task {
            await fuzzer.fuzzService22(interface: interface, ecu: targetEcu, startDid: start, endDid: end)
        }
    }
    
    private func startCorrelation() {
        guard targetDidHex.count == 4, Int(targetDidHex, radix: 16) != nil else {
            fuzzer.actionError = "Le DID cible doit être de 4 caractères hexadécimaux."
            return
        }
        Task {
            await fuzzer.analyzeDIDCorrelation(interface: interface, ecu: targetEcu, didHex: targetDidHex)
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
