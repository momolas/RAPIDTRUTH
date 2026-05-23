import SwiftUI

struct FuzzerNetworkDiscoverySection: View {
    let interface: VehicleInterface
    let fuzzer: OBDFuzzer
    @Binding var selectedPreset: ScanPreset
    @Binding var targetEcu: String
    
    var body: some View {
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
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(fuzzer.discoveredECUs, id: \.self) { ecu in
                                Button(action: {
                                    targetEcu = ecu
                                }) {
                                    Text(ecu)
                                        .font(.monoSmall)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(targetEcu == ecu ? Color.orange.opacity(0.3) : Color.white.opacity(0.1))
                                        .clipShape(.rect(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            
            Button {
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
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Scanner le Réseau CAN")
                }
                .frame(maxWidth: .infinity)
            }
            .glassActionButton(prominent: false)
            .buttonBorderShape(.roundedRectangle)
            .disabled(fuzzer.isRunning)
        }
    }
}
