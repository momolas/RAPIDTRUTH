import SwiftUI
import SwiftVehicleProtocols

struct MaintenanceFlashingSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var mapManager: ECUMapManager
    @Binding var isExpanded: Bool
    @Binding var selectedBackupURL: URL?

    @State private var showingFlashConfirmAlert = false

    private var isReadyToFlash: Bool {
        mapManager.checklistBatteryOk &&
        mapManager.checklistIgnitionOn &&
        mapManager.checklistGearboxNeutral &&
        mapManager.checklistSafetyConfirmed
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // Backup
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sauvegarder la Cartographie (Lecture)")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    
                    if !mapManager.isBackingUp && !mapManager.isFlashing {
                        Button("Démarrer la sauvegarde KWP2000") {
                            Task {
                                await mapManager.backupEngineMap(interface: interface)
                            }
                        }
                        .disabled(!isConnected)
                        .font(.appButton)
                        .glassActionButton()
                    }
                    
                    if mapManager.isBackingUp {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: mapManager.progress)
                                .tint(Color.appAccent)
                            
                            HStack {
                                Text(mapManager.statusMessage ?? "")
                                    .font(.captionText)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text("\(mapManager.kbPerSecond.formatted(.number.precision(.fractionLength(1)))) KB/s")
                                    .font(.monoSmall)
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                Divider().background(Color.white.opacity(0.05))

                // Flash
                VStack(alignment: .leading, spacing: 12) {
                    Text("Flasher la Cartographie (Écriture)")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    
                    if mapManager.backupFiles.isEmpty {
                        Text("Aucune sauvegarde (.bin) trouvée dans les documents. Effectuez d'abord une sauvegarde pour pouvoir flasher.")
                            .font(.captionText)
                            .foregroundStyle(.gray)
                    } else {
                        HStack {
                            Text("Fichier Source")
                                .font(.bodyText)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $selectedBackupURL) {
                                ForEach(mapManager.backupFiles, id: \.self) { fileURL in
                                    Text(fileURL.lastPathComponent)
                                        .font(.monoSmall)
                                        .tag(fileURL as URL?)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(mapManager.isFlashing || mapManager.isBackingUp)
                        }
                        
                        Text("Consignes de sécurité obligatoires :")
                            .font(.captionText)
                            .bold()
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $mapManager.checklistBatteryOk) {
                                Text("Tension batterie stable (>12.5V)")
                                    .font(.captionText)
                            }
                            .disabled(mapManager.isFlashing || mapManager.isBackingUp)
                            
                            Toggle(isOn: $mapManager.checklistIgnitionOn) {
                                Text("Contact mis (+APC actif, moteur coupé)")
                                    .font(.captionText)
                            }
                            .disabled(mapManager.isFlashing || mapManager.isBackingUp)
                            
                            Toggle(isOn: $mapManager.checklistGearboxNeutral) {
                                Text("Boîte de vitesses au point mort (N)")
                                    .font(.captionText)
                            }
                            .disabled(mapManager.isFlashing || mapManager.isBackingUp)
                            
                            Toggle(isOn: $mapManager.checklistSafetyConfirmed) {
                                Text("J'assume le risque de briquage en cas de coupure")
                                    .font(.captionText)
                            }
                            .disabled(mapManager.isFlashing || mapManager.isBackingUp)
                        }
                        
                        if !mapManager.isFlashing && !mapManager.isBackingUp {
                            Button(action: {
                                showingFlashConfirmAlert = true
                            }) {
                                Text("Démarrer le Flashage KWP2000")
                                    .font(.appButton)
                                    .frame(maxWidth: .infinity)
                            }
                            .glassActionButton(prominent: true)
                            .disabled(!isReadyToFlash || !isConnected)
                        }
                        
                        if mapManager.isFlashing {
                            VStack(alignment: .leading, spacing: 4) {
                                ProgressView(value: mapManager.progress)
                                    .tint(.red)
                                
                                HStack {
                                    Text(mapManager.statusMessage ?? "")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    Text("\(mapManager.kbPerSecond.formatted(.number.precision(.fractionLength(1)))) KB/s")
                                        .font(.monoSmall)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .alert("DANGER : CONFIRMATION DU FLASHAGE", isPresented: $showingFlashConfirmAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Flasher le calculateur", role: .destructive) {
                        if let targetFile = selectedBackupURL {
                            Task {
                                await mapManager.flashEngineMap(interface: interface, fileURL: targetFile)
                            }
                        }
                    }
                } message: {
                    Text("ATTENTION : Le flashage écrit directement dans la mémoire Flash du calculateur moteur (EDC16CP33). Une coupure d'alimentation ou de connexion Bluetooth/Wi-Fi pendant cette phase peut rendre le calculateur définitivement inutilisable (briquage). Confirmez-vous le lancement ?")
                }
                
                if let error = mapManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.captionText)
                }
                
                if let success = mapManager.successMessage {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.captionText)
                }
            }
            .padding(.vertical, 8)
        } label: {
            Text("Reprogrammation & Cartographie")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
