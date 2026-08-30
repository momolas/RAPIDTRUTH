import SwiftUI
import SwiftVehicleProtocols
import SwiftData

struct DiagnosticsView: View {
    let interface: VehicleInterface
    let profile: Profile
    @State private var dtcLoader = DTCLoader()
    @Environment(PandaTransport.self) private var pandaTransport
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(SettingsStore.self) private var settings
    
    @State private var scanHistory: [DTCScanRecord] = []
    @State private var selectedFreezeFrameDTC: DTC? = nil
    
    init(interface: VehicleInterface, profile: Profile) {
        self.interface = interface
        self.profile = profile
    }

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }
    
    private var activeVehicleSlug: String {
        settings.activeVehicleSlug ?? "unknown"
    }
    
    private func reloadHistory() {
        scanHistory = vehicleStore.fetchDTCScans(for: activeVehicleSlug)
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

                    // NRC Reject Banner if any
                    if let nrc = dtcLoader.lastNRCError {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundStyle(.orange)
                                Text("Refus Calculateur : \(nrc.title) (0x\(nrc.rawHexCode))")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            Text(nrc.explanation)
                                .font(.captionText)
                                .foregroundStyle(.secondary)
                            Text("💡 Conseil : \(nrc.actionAdvice)")
                                .font(.captionText)
                                .bold()
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 8))
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
                            ForEach(Array(dtcLoader.dtcs.enumerated()), id: \.element.id) { index, dtc in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(alignment: .center, spacing: 6) {
                                                if let df = dtc.dfCode {
                                                    Text(df)
                                                        .font(.caption).bold()
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.appAccent.opacity(0.2))
                                                        .foregroundStyle(Color.appAccent)
                                                        .clipShape(.rect(cornerRadius: 4))
                                                }
                                                
                                                Text(dtc.code)
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                
                                                Text("(\(dtc.ecu.uppercased()))")
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
                                        
                                        VStack(alignment: .trailing, spacing: 6) {
                                            if let mask = dtc.statusMask {
                                                HStack(spacing: 4) {
                                                    if mask.contains(.warningIndicatorRequested) {
                                                        Image(systemName: "engine.combustion.fill")
                                                            .font(.caption2)
                                                            .foregroundStyle(.yellow)
                                                    }
                                                    if mask.contains(.testFailed) {
                                                        Text("ACTIF")
                                                            .font(.caption).bold()
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.red.opacity(0.2))
                                                            .foregroundStyle(.red)
                                                            .clipShape(.rect(cornerRadius: 4))
                                                    } else if mask.contains(.pendingDTC) {
                                                        Text("EN ATTENTE")
                                                            .font(.caption).bold()
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.orange.opacity(0.2))
                                                            .foregroundStyle(.orange)
                                                            .clipShape(.rect(cornerRadius: 4))
                                                    } else if mask.contains(.confirmedDTC) {
                                                        Text("CONFIRMÉ")
                                                            .font(.caption).bold()
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.blue.opacity(0.2))
                                                            .foregroundStyle(.blue)
                                                            .clipShape(.rect(cornerRadius: 4))
                                                    } else {
                                                        Text("MÉMORISÉ")
                                                            .font(.caption).bold()
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.secondary.opacity(0.2))
                                                            .foregroundStyle(.secondary)
                                                            .clipShape(.rect(cornerRadius: 4))
                                                    }
                                                }
                                            } else {
                                                Text(dtc.state == .active ? "ACTIF" : "MÉMORISÉ")
                                                    .font(.caption).bold()
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(dtc.state == .active ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                                                    .foregroundStyle(dtc.state == .active ? .red : .orange)
                                                    .clipShape(.rect(cornerRadius: 5))
                                            }
                                            
                                            Button {
                                                Task {
                                                    await dtcLoader.fetchFreezeFrame(interface: interface, profile: profile, dtcIndex: index)
                                                    if dtcLoader.dtcs.indices.contains(index) {
                                                        selectedFreezeFrameDTC = dtcLoader.dtcs[index]
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "snowflake")
                                                    Text("Freeze Frame")
                                                }
                                                .font(.captionTiny)
                                                .foregroundStyle(Color.appAccent)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    
                                    // Quick summary of Freeze Frame if loaded
                                    if let freezeFrame = dtc.freezeFrame {
                                        HStack(spacing: 12) {
                                            if let rpm = freezeFrame.rpm {
                                                Text("\(rpm) tr/min")
                                                    .font(.monoTiny)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let speed = freezeFrame.vehicleSpeed {
                                                Text("\(speed) km/h")
                                                    .font(.monoTiny)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let temp = freezeFrame.coolantTemp {
                                                Text("\(temp) °C")
                                                    .font(.monoTiny)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button("Voir détails") {
                                                selectedFreezeFrameDTC = dtc
                                            }
                                            .font(.captionTiny)
                                            .foregroundStyle(Color.appAccent)
                                        }
                                        .padding(8)
                                        .background(Color.black.opacity(0.25))
                                        .clipShape(.rect(cornerRadius: 6))
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .clipShape(.rect(cornerRadius: 6))
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        Button("Scanner les Défauts", action: scanFaults)
                            .font(.appButton)
                            .frame(maxWidth: .infinity)
                            .glassActionButton(prominent: true)
                            .buttonBorderShape(.roundedRectangle)
                            .disabled(dtcLoader.isScanning || dtcLoader.isClearing || !isConnected)

                        if !dtcLoader.dtcs.isEmpty {
                            Button(dtcLoader.isClearing ? "Effacement..." : "Tout Effacer", role: .destructive, action: clearFaults)
                                .font(.appButton)
                                .frame(maxWidth: .infinity)
                                .glassActionButton(prominent: false)
                                .buttonBorderShape(.roundedRectangle)
                                .disabled(dtcLoader.isClearing || !isConnected)
                        }
                    }
                }
                .appCard()
                
                // Scan History Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Historique des Scans")
                        .font(.cardTitle)
                        .foregroundStyle(.secondary)
                    
                    if scanHistory.isEmpty {
                        Text("Aucun scan enregistré pour ce véhicule.")
                            .font(.captionText)
                            .foregroundStyle(.gray)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(scanHistory) { record in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.captionText).bold()
                                            .foregroundStyle(.white)
                                        
                                        let count = record.codes.count
                                        Text(count == 0 ? "Aucun défaut" : "\(count) défaut\(count > 1 ? "s" : "") détecté\(count > 1 ? "s" : "")")
                                            .font(.captionTiny)
                                            .foregroundStyle(count == 0 ? .green : .red)
                                        
                                        if !record.codes.isEmpty {
                                            Text(record.codes.joined(separator: ", "))
                                                .font(.monoTiny)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.03))
                                .clipShape(.rect(cornerRadius: 6))
                            }
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
        .sheet(item: $selectedFreezeFrameDTC) { dtc in
            if let frame = dtc.freezeFrame {
                DTCFreezeFrameSheet(dtc: dtc, frame: frame)
            }
        }
        .task {
            reloadHistory()
        }
    }
    
    private func scanFaults() {
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            await dtcLoader.scan(interface: interface, profile: profile)
            
            let codes = dtcLoader.dtcs.map { $0.code }
            let ecus = Array(Set(dtcLoader.dtcs.map { $0.ecu }))
            try? vehicleStore.saveDTCScan(vehicleSlug: activeVehicleSlug, codes: codes, ecus: ecus)
            reloadHistory()
        }
    }
    
    private func clearFaults() {
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            await dtcLoader.clear(interface: interface, profile: profile)
            
            try? vehicleStore.saveDTCScan(vehicleSlug: activeVehicleSlug, codes: [], ecus: [])
            reloadHistory()
        }
    }
}
