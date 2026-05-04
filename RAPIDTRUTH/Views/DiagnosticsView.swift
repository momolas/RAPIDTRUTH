import SwiftUI

struct DiagnosticsView: View {
    let interface: VehicleInterface
    let profile: Profile
    @State private var dtcLoader = DTCLoader()
    private var ble = BLEManager.shared

    init(interface: VehicleInterface, profile: Profile) {
        self.interface = interface
        self.profile = profile
    }

    private var isConnected: Bool {
        if case .connected = ble.connectionState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Diagnostic Trouble Codes (DTC)")
                    .font(.cardTitle)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if dtcLoader.isScanning {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    if let ecu = dtcLoader.currentEcuScanning {
                        Text("Scanning \(ecu)...")
                            .font(.statusText)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Scanning ECUs...")
                            .font(.statusText)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            } else if let error = dtcLoader.scanError {
                Text(error)
                    .font(.statusText)
                    .foregroundStyle(.red)
                    .padding()
            } else if dtcLoader.dtcs.isEmpty {
                Text("No faults detected. System OK.")
                    .font(.statusText)
                    .foregroundStyle(.green)
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
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            }

            HStack(spacing: 16) {
                Button(action: {
                    Task { await dtcLoader.scan(interface: interface, profile: profile) }
                }) {
                    Text("Scan Faults")
                        .font(.appButton)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(dtcLoader.isScanning || dtcLoader.isClearing || !isConnected)

                if !dtcLoader.dtcs.isEmpty {
                    Button(action: {
                        Task { await dtcLoader.clear(interface: interface, profile: profile) }
                    }) {
                        Text(dtcLoader.isClearing ? "Clearing..." : "Clear All")
                            .font(.appButton)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(dtcLoader.isClearing || !isConnected)
                }
            }
        }
        .appCard()
    }
}
