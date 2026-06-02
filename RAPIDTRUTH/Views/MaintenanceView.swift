import SwiftUI

struct MaintenanceView: View {
    let interface: VehicleInterface
    @State private var maintenanceManager = MaintenanceManager()
    @State private var mapManager = ECUMapManager()
    @Environment(PandaTransport.self) private var pandaTransport
    
    @State private var showingDPFAlert = false
    @State private var showingEPBAlert = false
    @State private var showingOilAlert = false
    @State private var showingABSAlert = false
    
    @State private var selectedBackupURL: URL? = nil
    @State private var showingFlashConfirmAlert = false
    
    @State private var selectedKMIndex = 0
    let kmOptions = [10000, 15000, 20000, 30000]
    @State private var selectedMonthIndex = 0
    let monthOptions = [12, 24]
    
    @State private var showingSSPPAlert = false
    @State private var ssppTargetState = false
    
    @State private var showingAirbagAlert = false
    @State private var airbagTargetState = false

    @State private var isOilExpanded = true
    @State private var isBrakesExpanded = false
    @State private var isExhaustExpanded = false
    @State private var isCodingExpanded = false
    @State private var isFlashingExpanded = false

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }
    
    private var isReadyToFlash: Bool {
        mapManager.checklistBatteryOk &&
        mapManager.checklistIgnitionOn &&
        mapManager.checklistGearboxNeutral &&
        mapManager.checklistSafetyConfirmed
    }

    init(interface: VehicleInterface) {
        self.interface = interface
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !isConnected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Outil non connecté. Connectez un adaptateur OBD.")
                            .font(.captionText)
                            .foregroundStyle(.gray)
                    }
                    .appCard()
                }

                if let error = maintenanceManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.statusText)
                        .padding(.horizontal, 16)
                }

                if let success = maintenanceManager.successMessage {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.statusText)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // 1. Vidange
                    DisclosureGroup(isExpanded: $isOilExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                showingOilAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "drop.fill")
                                        .foregroundStyle(.orange)
                                    Text("Réinitialiser Intervalle Vidange")
                                    Spacer()
                                }
                                .font(.appButton)
                            }
                            .disabled(!isConnected || maintenanceManager.isExecuting)
                            .glassActionButton()
                            .alert("Remise à zéro Vidange", isPresented: $showingOilAlert) {
                                Button("Annuler", role: .cancel) { }
                                Button("Confirmer", role: .destructive) {
                                    Task { await maintenanceManager.resetOilService(interface: interface) }
                                }
                            } message: {
                                Text("Êtes-vous sûr de vouloir réinitialiser l'indicateur de maintenance ? L'opération est irréversible.")
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Vidange & Entretien")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // 2. Freinage
                    DisclosureGroup(isExpanded: $isBrakesExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                showingEPBAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "parkingsign.circle.fill")
                                        .foregroundStyle(.red)
                                    Text("Mode Atelier Frein Parking (FPA)")
                                    Spacer()
                                }
                                .font(.appButton)
                            }
                            .disabled(!isConnected || maintenanceManager.isExecuting)
                            .glassActionButton()
                            .alert("Mode Atelier Frein de Parking", isPresented: $showingEPBAlert) {
                                Button("Annuler", role: .cancel) { }
                                Button("Activer", role: .destructive) {
                                    Task { await maintenanceManager.enterEPBMaintenanceMode(interface: interface) }
                                }
                            } message: {
                                Text("Attention : Cette action relâche les mâchoires du frein de stationnement pour permettre le remplacement des plaquettes. Assurez-vous que le véhicule est sur une surface plane et calé.")
                            }

                            Button(action: {
                                showingABSAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "fluid.brakesignal")
                                        .foregroundStyle(.red)
                                    Text("Purge Bloc ABS")
                                    Spacer()
                                }
                                .font(.appButton)
                            }
                            .disabled(!isConnected || maintenanceManager.isExecuting)
                            .glassActionButton()
                            .alert("Purge du groupe hydraulique ABS", isPresented: $showingABSAlert) {
                                Button("Annuler", role: .cancel) { }
                                Button("Démarrer la Purge", role: .destructive) {
                                    Task { await maintenanceManager.purgeABSGroup(interface: interface) }
                                }
                            } message: {
                                Text("Attention : Cette action va activer les solénoïdes et la pompe du bloc hydraulique ABS pour chasser les bulles d'air. Assurez-vous que les vis de purge sont prêtes et ouvertes, et que le réservoir de liquide de frein est plein.")
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Freinage")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // 3. Échappement
                    DisclosureGroup(isExpanded: $isExhaustExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                showingDPFAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "smoke.fill")
                                        .foregroundStyle(.gray)
                                    Text("Régénération Forcée FAP")
                                    Spacer()
                                }
                                .font(.appButton)
                            }
                            .disabled(!isConnected || maintenanceManager.isExecuting)
                            .glassActionButton()
                            .alert("Régénération FAP DANGER", isPresented: $showingDPFAlert) {
                                Button("Annuler", role: .cancel) { }
                                Button("Lancer Régénération", role: .destructive) {
                                    Task { await maintenanceManager.forceDPFRegeneration(interface: interface) }
                                }
                            } message: {
                                Text("AVERTISSEMENT : La régénération statique fera monter le régime moteur et la température d'échappement très haut (>600°C). Effectuez cette opération en extérieur, sur une surface ininflammable, capot ouvert, avec un réservoir au moins au quart plein. Ne quittez pas le véhicule pendant l'opération.")
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Échappement")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // 4. Télécodage
                    DisclosureGroup(isExpanded: $isCodingExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            // SSPP
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Configuration SSPP (Valves)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Activer") {
                                        ssppTargetState = true
                                        showingSSPPAlert = true
                                    }
                                    .font(.captionText)
                                    .glassActionButton()
                                    .foregroundStyle(.green)
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                    
                                    Button("Désactiver") {
                                        ssppTargetState = false
                                        showingSSPPAlert = true
                                    }
                                    .font(.captionText)
                                    .glassActionButton()
                                    .foregroundStyle(.red)
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                }
                            }
                            .alert("Modification Configuration SSPP", isPresented: $showingSSPPAlert) {
                                Button("Annuler", role: .cancel) { }
                                Button("Confirmer", role: .destructive) {
                                    Task { await maintenanceManager.setSSPPEnabled(interface: interface, enabled: ssppTargetState) }
                                }
                            } message: {
                                Text(ssppTargetState ? "Confirmez-vous l'activation du système de surveillance de pression de pneus ?" : "Confirmez-vous la désactivation ? Tous les voyants de pneu manquant et alertes de crevaison s'éteindront définitivement.")
                            }

                            Divider().background(Color.white.opacity(0.05))

                            // Ralenti
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Régulation du Ralenti dCi")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                  HStack {
                                    Button("+50 tr/min") {
                                        Task { await maintenanceManager.adjustIdleSpeed(interface: interface, increase: true) }
                                    }
                                    .font(.captionText)
                                    .glassActionButton()
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                    
                                    Button("-50 tr/min") {
                                        Task { await maintenanceManager.adjustIdleSpeed(interface: interface, increase: false) }
                                    }
                                    .font(.captionText)
                                    .glassActionButton()
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                }
                            }

                            Divider().background(Color.white.opacity(0.05))

                            // Vidange Perso
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Périodicité Vidange Personnalisée")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Picker("Distance", selection: $selectedKMIndex) {
                                        ForEach(0..<kmOptions.count, id: \.self) { index in
                                            Text("\(kmOptions[index]) km").tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .disabled(maintenanceManager.isExecuting)
                                    
                                    Picker("Durée", selection: $selectedMonthIndex) {
                                        ForEach(0..<monthOptions.count, id: \.self) { index in
                                            Text("\(monthOptions[index]) mois").tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .disabled(maintenanceManager.isExecuting)
                                    
                                    Spacer()
                                    
                                    Button("Écrire") {
                                        let targetKM = kmOptions[selectedKMIndex]
                                        let targetMonths = monthOptions[selectedMonthIndex]
                                        Task {
                                            await maintenanceManager.setOilServicePeriodicity(interface: interface, intervalKM: targetKM, intervalMonths: targetMonths)
                                        }
                                    }
                                    .font(.captionText)
                                    .glassActionButton(prominent: true)
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                }
                            }

                            Divider().background(Color.white.opacity(0.05))

                            // Airbag
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Verrouillage de l'Airbag (Mode Atelier)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Sécuriser (Verrouiller)") {
                                        airbagTargetState = true
                                        showingAirbagAlert = true
                                    }
                                    .font(.captionText)
                                    .glassActionButton()
                                    .foregroundStyle(.red)
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                    
                                    Button("Réactiver (Déverrouiller)") {
                                        airbagTargetState = false
                                        showingAirbagAlert = true
                                    }
                                    .font(.captionText)
                                    .glassActionButton()
                                    .foregroundStyle(.green)
                                    .disabled(!isConnected || maintenanceManager.isExecuting)
                                }
                            }
                            .alert("Modification État Airbag", isPresented: $showingAirbagAlert) {
                                Button("Annuler", role: .cancel) { }
                                Button("Confirmer", role: .destructive) {
                                    Task { await maintenanceManager.setAirbagLocked(interface: interface, locked: airbagTargetState) }
                                }
                            } message: {
                                Text(airbagTargetState ? "Voulez-vous verrouiller le calculateur ? Toutes les lignes de tir seront désactivées pour les travaux physiques d'atelier." : "Voulez-vous déverrouiller le calculateur ? Le système d'airbags sera réactivé et prêt à protéger en route.")
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Télécodage & Personnalisation")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // 5. Reprog / Carto
                    DisclosureGroup(isExpanded: $isFlashingExpanded) {
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
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Fonctions de Service")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            mapManager.refreshBackupList()
            selectedBackupURL = mapManager.backupFiles.first
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
                NSLog("[MaintenanceView] Switched Panda safety model to ALLOUTPUT for service operations")
            }
        }
        .onDisappear {
            if let panda = interface as? PandaDriver {
                Task {
                    try? await panda.setSafetyModel(.allOutput)
                    NSLog("[MaintenanceView] Kept Panda safety model as ALLOUTPUT")
                }
            }
        }
    }
}
