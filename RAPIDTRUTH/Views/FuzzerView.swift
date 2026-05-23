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
                    FuzzerSafetyWarningView(agreedToRisks: $agreedToRisks)
                } else {
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
}
