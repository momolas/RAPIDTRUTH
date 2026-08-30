import SwiftUI
import SwiftVehicleProtocols

struct FuzzerLINSection: View {
    let interface: VehicleInterface
    @Bindable var linFuzzer: LINFuzzer
    @Binding var linUartPort: UInt16
    @Binding var linBaudRate: UInt32
    @Binding var useEnhancedChecksum: Bool
    @Binding var linSubTab: Int
    @Binding var injectRawIdHex: String
    @Binding var injectDataHex: String
    
    var onStartSniffing: () -> Void
    var onStopSniffing: () -> Void
    var onStartScan: () -> Void
    var onStopScan: () -> Void
    var onInjectFrame: () -> Void

    var body: some View {
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
            snifferView
        } else if linSubTab == 1 {
            scanView
        } else {
            injectorView
        }
    }
    
    @ViewBuilder
    private var snifferView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Écoute passive du Bus")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            
            if linFuzzer.isRunning {
                Button(action: onStopSniffing) {
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
                Button(action: onStartSniffing) {
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
    }
    
    @ViewBuilder
    private var scanView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balayage d'Identifiants LIN")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            
            Text("Envoie séquentiellement des en-têtes LIN Master (PIDs 0x00-0x3F) pour provoquer et écouter les réponses des esclaves connectés.")
                .font(.captionText)
                .foregroundStyle(.secondary)
            
            if linFuzzer.isRunning {
                VStack(spacing: 8) {
                    Button(action: onStopScan) {
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
                Button(action: onStartScan) {
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
    }
    
    @ViewBuilder
    private var injectorView: some View {
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
            
            Button(action: onInjectFrame) {
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
}
