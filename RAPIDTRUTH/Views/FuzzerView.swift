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
    
    var body: some View {
        NavigationStack {
            Form {
                if !agreedToRisks {
                    safetyWarningView
                } else {
                    networkDiscoverySection
                    fuzzerConfigSection
                    fuzzerExecutionSection
                    resultsSection
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
    
    // MARK: - Extracted Subviews
    
    @ViewBuilder
    private var safetyWarningView: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.title)
                    Text("Avertissement de Sécurité")
                        .font(.headline)
                        .foregroundStyle(.red)
                }
                Text("Le fuzzing OBD peut entraîner des comportements inattendus du véhicule, y compris des plantages d'ECU. Ce fuzzer est strictement limité à la LECTURE (Service 22).")
                    .font(.subheadline)
                
                Toggle("J'accepte les risques", isOn: $agreedToRisks)
                    .tint(.red)
                    .padding(.top, 5)
            }
        }
    }
    
    @ViewBuilder
    private var networkDiscoverySection: some View {
        Section(header: Text("Découverte Réseau")) {
            Picker("Type de Scan", selection: $selectedPreset) {
                ForEach(ScanPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            
            if !fuzzer.discoveredECUs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calculateurs trouvés (tapez pour cibler) :")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(fuzzer.discoveredECUs, id: \.self) { ecu in
                                Button(action: {
                                    targetEcu = ecu
                                }) {
                                    Text(ecu)
                                        .font(.monoSmall)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(targetEcu == ecu ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2))
                                        .clipShape(.rect(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Button(action: {
                Task {
                    let range: [String]
                    switch selectedPreset {
                    case .rapid:
                        range = ["7E0", "7E1", "7E2", "7E3", "7E4", "7E5", "7E6", "7E7", "740", "741", "742", "743", "744", "745", "756", "7A0", "7A2"]
                    case .standard11bit:
                        range = (0x700...0x7EF).map { String(format: "%03X", $0) }
                    case .standard29bit:
                        range = (0x00...0xFF).map { String(format: "18DA%02XF1", $0) }
                    }
                    await fuzzer.scanNetwork(interface: interface, range: range)
                }
            }, label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Scanner le Réseau CAN")
                }
                .frame(maxWidth: .infinity)
            })
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .disabled(fuzzer.isRunning)
        }
    }
    
    @ViewBuilder
    private var fuzzerConfigSection: some View {
        Section(header: Text("Configuration du Fuzzer")) {
            Picker("Gamme de DIDs", selection: $selectedDidPreset) {
                ForEach(DidPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            
            TextField("ECU Cible (ex: 7E0)", text: $targetEcu)
            TextField("DID Début (Hex)", text: $startDidHex)
            TextField("DID Fin (Hex)", text: $endDidHex)
        }
    }
    
    @ViewBuilder
    private var fuzzerExecutionSection: some View {
        Section {
            if fuzzer.isRunning {
                Button(action: {
                    fuzzer.cancel()
                }, label: {
                    Text(fuzzer.currentScanTarget.contains("Scan") ? "Arrêter le Scan" : "Arrêter le Fuzzing")
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .tint(.red)
                
                ProgressView(value: fuzzer.currentProgress)
                    .padding(.vertical, 8)
                
            } else {
                Button(action: {
                    startFuzzing()
                }, label: {
                    Text("Démarrer le Fuzzing")
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .tint(.orange)
            }
            
            if let error = fuzzer.actionError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        if !fuzzer.results.isEmpty {
            Section(header: Text("Résultats (\(fuzzer.results.count))")) {
                ForEach(fuzzer.results) { result in
                    VStack(alignment: .leading) {
                        Text("DID: \(result.did)")
                            .font(.headline)
                        Text("Resp: \(result.response)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
}
