import SwiftUI

struct DiagnosticsView: View {
    let interface: VehicleInterface
    let profile: Profile
    @State private var dtcLoader = DTCLoader()
    @Environment(PandaTransport.self) private var pandaTransport
    
    init(interface: VehicleInterface, profile: Profile) {
        self.interface = interface
        self.profile = profile
    }

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Diagnostic Trouble Codes (DTC)")
                            .font(.cardTitle)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    if dtcLoader.isScanning {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.appAccent)
                                .symbolEffect(.rotate, options: .repeating)
                            if let ecu = dtcLoader.currentEcuScanning {
                                Text("Scan en cours : \(ecu)...")
                                    .font(.statusText)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Scan des calculateurs...")
                                    .font(.statusText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    } else if let error = dtcLoader.scanError {
                        Text(error)
                            .font(.statusText)
                            .foregroundStyle(.red)
                            .padding()
                    } else if dtcLoader.dtcs.isEmpty {
                        ContentUnavailableView {
                            Label("Aucun défaut détecté", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                        } description: {
                            Text("Le système de diagnostic réseau est sain.")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(dtcLoader.dtcs) { dtc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .bottom) {
                                            Text(dtc.code)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(dtc.ecu.uppercased())
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        if let desc = dtc.description {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(dtc.state.rawValue.uppercased())
                                        .font(.caption).bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(dtc.state == .active ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                                        .foregroundStyle(dtc.state == .active ? .red : .orange)
                                        .clipShape(.rect(cornerRadius: 5))
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .clipShape(.rect(cornerRadius: 5))
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        Button("Scan Faults", action: scanFaults)
                            .font(.appButton)
                            .frame(maxWidth: .infinity)
                            .glassActionButton(prominent: true)
                            .buttonBorderShape(.roundedRectangle)
                            .disabled(dtcLoader.isScanning || dtcLoader.isClearing || !isConnected)

                        if !dtcLoader.dtcs.isEmpty {
                            Button(dtcLoader.isClearing ? "Clearing..." : "Clear All", role: .destructive, action: clearFaults)
                                .font(.appButton)
                                .frame(maxWidth: .infinity)
                                .glassActionButton(prominent: false)
                                .buttonBorderShape(.roundedRectangle)
                                .disabled(dtcLoader.isClearing || !isConnected)
                        }
                    }
                }
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Diagnostic Réseau (DTC)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func scanFaults() {
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            await dtcLoader.scan(interface: interface, profile: profile)
        }
    }
    
    private func clearFaults() {
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            await dtcLoader.clear(interface: interface, profile: profile)
        }
    }
}
