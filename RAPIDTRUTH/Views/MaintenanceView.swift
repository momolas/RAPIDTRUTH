import SwiftUI

struct MaintenanceView: View {
    let interface: VehicleInterface
    @Environment(\.dismiss) var dismiss
    @State private var maintenanceManager = MaintenanceManager()
    @State private var mapManager = ECUMapManager()
    @Environment(PandaTransport.self) private var pandaTransport
    
    @State private var showingDPFAlert = false
    @State private var showingEPBAlert = false
    @State private var showingOilAlert = false
    @State private var showingABSAlert = false
    
    @State private var selectedBackupURL: URL? = nil
    @State private var showingFlashConfirmAlert = false
    
    // New state properties for telecoding pickers and actions
    @State private var selectedKMIndex = 0
    let kmOptions = [10000, 15000, 20000, 30000]
    @State private var selectedMonthIndex = 0
    let monthOptions = [12, 24]
    
    @State private var showingSSPPAlert = false
    @State private var ssppTargetState = false
    
    @State private var showingAirbagAlert = false
    @State private var airbagTargetState = false

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
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section {
                        if !isConnected {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Outil non connecté. Connectez un adaptateur OBD pour utiliser les fonctions de service.")
                                    .font(.captionText)
                                    .foregroundStyle(.gray)
                            }
                            .listRowBackground(Color.appCardBackground)
                        }

                        if let error = maintenanceManager.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.captionText)
                                .listRowBackground(Color.red.opacity(0.1))
                        }

                        if let success = maintenanceManager.successMessage {
                            Text(success)
                                .foregroundStyle(.green)
                                .font(.captionText)
                                .listRowBackground(Color.green.opacity(0.1))
                        }
                    }

                    Section(header: Text("Vidange & Entretien").foregroundStyle(.gray)) {
                        Button(action: {
                            showingOilAlert = true
                        }, label: {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 30)
                                Text("Remise à zéro Intervalle Vidange")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.captionText)
                            }
                        })
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        .listRowBackground(Color.appCardBackground)
                        .alert("Remise à zéro Vidange", isPresented: $showingOilAlert) {
                            Button("Annuler", role: .cancel) { }
                            Button("Confirmer", role: .destructive) {
                                Task { await maintenanceManager.resetOilService(interface: interface) }
                            }
                        } message: {
                            Text("Êtes-vous sûr de vouloir réinitialiser l'indicateur de maintenance ? L'opération est irréversible.")
                        }
                    }

                    Section(header: Text("Freinage").foregroundStyle(.gray)) {
                        Button(action: {
                            showingEPBAlert = true
                        }, label: {
                            HStack {
                                Image(systemName: "parkingsign.circle.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 30)
                                Text("Mode Atelier Frein de Parking (FPA)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.captionText)
                            }
                        })
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        .listRowBackground(Color.appCardBackground)
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
                        }, label: {
                            HStack {
                                Image(systemName: "fluid.brakesignal")
                                    .foregroundStyle(.red)
                                    .frame(width: 30)
                                Text("Purge du groupe hydraulique ABS")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.captionText)
                            }
                        })
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        .listRowBackground(Color.appCardBackground)
                        .alert("Purge du groupe hydraulique ABS", isPresented: $showingABSAlert) {
                            Button("Annuler", role: .cancel) { }
                            Button("Démarrer la Purge", role: .destructive) {
                                Task { await maintenanceManager.purgeABSGroup(interface: interface) }
                            }
                        } message: {
                            Text("Attention : Cette action va activer les solénoïdes et la pompe du bloc hydraulique ABS pour chasser les bulles d'air. Assurez-vous que les vis de purge sont prêtes et ouvertes au moment demandé, et que le réservoir de liquide de frein est plein.")
                        }
                    }

                    Section(header: Text("Échappement").foregroundStyle(.gray)) {
                        Button(action: {
                            showingDPFAlert = true
                        }, label: {
                            HStack {
                                Image(systemName: "smoke.fill")
                                    .foregroundStyle(.gray)
                                    .frame(width: 30)
                                Text("Régénération Forcée FAP")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.captionText)
                            }
                        })
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        .listRowBackground(Color.appCardBackground)
                        .alert("Régénération FAP DANGER", isPresented: $showingDPFAlert) {
                            Button("Annuler", role: .cancel) { }
                            Button("Lancer Régénération", role: .destructive) {
                                Task { await maintenanceManager.forceDPFRegeneration(interface: interface) }
                            }
                        } message: {
                            Text("AVERTISSEMENT : La régénération statique fera monter le régime moteur et la température d'échappement très haut (>600°C). Effectuez cette opération en extérieur, sur une surface ininflammable, capot ouvert, avec un réservoir au moins au quart plein. Ne quittez pas le véhicule pendant l'opération.")
                        }
                    }

                    Section(header: Text("Télécodage & Personnalisation").foregroundStyle(.gray)) {
                        // 1. SSPP UCH
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "gauge.sensor.radial.dimension.fill")
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Configuration SSPP (Valves)")
                                        .foregroundStyle(.primary)
                                    Text("Activer ou désactiver les alertes de pression dans l'UCH.")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                }
                            }
                            
                            HStack {
                                Button("Activer le SSPP") {
                                    ssppTargetState = true
                                    showingSSPPAlert = true
                                }
                                .font(.captionText)
                                .buttonStyle(.bordered)
                                .foregroundStyle(.green)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                                
                                Button("Désactiver le SSPP (Recommandé si HS)") {
                                    ssppTargetState = false
                                    showingSSPPAlert = true
                                }
                                .font(.captionText)
                                .buttonStyle(.bordered)
                                .foregroundStyle(.red)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCardBackground)
                        .alert("Modification Configuration SSPP", isPresented: $showingSSPPAlert) {
                            Button("Annuler", role: .cancel) { }
                            Button("Confirmer", role: .destructive) {
                                Task { await maintenanceManager.setSSPPEnabled(interface: interface, enabled: ssppTargetState) }
                            }
                        } message: {
                            Text(ssppTargetState ? "Confirmez-vous l'activation du système de surveillance de pression de pneus ?" : "Confirmez-vous la désactivation ? Tous les voyants de pneu manquant et alertes de crevaison s'éteindront définitivement.")
                        }
                        
                        // 2. Idle Regulation
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "gauge.with.needle.fill")
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Régulation du Ralenti dCi")
                                        .foregroundStyle(.primary)
                                    Text("Ajuster le régime moteur d'arrêt pour masquer les vibrations.")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                }
                            }
                            
                            HStack {
                                Button("Augmenter le ralenti (+50 tr/min)") {
                                    Task { await maintenanceManager.adjustIdleSpeed(interface: interface, increase: true) }
                                }
                                .font(.captionText)
                                .buttonStyle(.bordered)
                                .foregroundStyle(Color.appAccent)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                                
                                Button("Diminuer le ralenti (-50 tr/min)") {
                                    Task { await maintenanceManager.adjustIdleSpeed(interface: interface, increase: false) }
                                }
                                .font(.captionText)
                                .buttonStyle(.bordered)
                                .foregroundStyle(.gray)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCardBackground)
                        
                        // 3. Custom Oil Interval
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Périodicité Vidange Personnalisée")
                                        .foregroundStyle(.primary)
                                    Text("Programmer des rappels d'entretien raccourcis (recommandé).")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                }
                            }
                            
                            HStack {
                                Picker("Distance (KM)", selection: $selectedKMIndex) {
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
                                
                                Button("Écrire TDB") {
                                    let targetKM = kmOptions[selectedKMIndex]
                                    let targetMonths = monthOptions[selectedMonthIndex]
                                    Task {
                                        await maintenanceManager.setOilServicePeriodicity(interface: interface, intervalKM: targetKM, intervalMonths: targetMonths)
                                    }
                                }
                                .font(.captionText)
                                .buttonStyle(.borderedProminent)
                                .tint(Color.appAccent)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCardBackground)
                        
                        // 4. Airbag Locking
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Verrouillage de l'Airbag (Mode Atelier)")
                                        .foregroundStyle(.primary)
                                    Text("Désactiver pyrotechnie avant d'intervenir sur les sièges/volant.")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                }
                            }
                            
                            HStack {
                                Button("Verrouiller (Sécuriser)") {
                                    airbagTargetState = true
                                    showingAirbagAlert = true
                                }
                                .font(.captionText)
                                .buttonStyle(.bordered)
                                .foregroundStyle(.red)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                                
                                Button("Déverrouiller (Prêt)") {
                                    airbagTargetState = false
                                    showingAirbagAlert = true
                                }
                                .font(.captionText)
                                .buttonStyle(.bordered)
                                .foregroundStyle(.green)
                                .disabled(!isConnected || maintenanceManager.isExecuting)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCardBackground)
                        .alert("Modification État Airbag", isPresented: $showingAirbagAlert) {
                            Button("Annuler", role: .cancel) { }
                            Button("Confirmer", role: .destructive) {
                                Task { await maintenanceManager.setAirbagLocked(interface: interface, locked: airbagTargetState) }
                            }
                        } message: {
                            Text(airbagTargetState ? "Voulez-vous verrouiller le calculateur ? Toutes les lignes de tir seront désactivées pour les travaux physiques d'atelier." : "Voulez-vous déverrouiller le calculateur ? Le système d'airbags sera réactivé et prêt à protéger en route.")
                        }
                    }

                    Section(header: Text("Reprogrammation & Cartographie Moteur").foregroundStyle(.gray)) {
                        // 1. BACKUP (READ) SECTION
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 30)
                                Text("Sauvegarder la Cartographie (Lecture)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if mapManager.isBackingUp {
                                    ProgressView()
                                }
                            }
                            
                            if !mapManager.isBackingUp && !mapManager.isFlashing {
                                Button("Démarrer la sauvegarde UDS") {
                                    Task {
                                        await mapManager.backupEngineMap(interface: interface)
                                    }
                                }
                                .disabled(!isConnected)
                                .font(.appButton)
                                .buttonStyle(.bordered)
                                .foregroundStyle(isConnected ? Color.appAccent : .gray)
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
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCardBackground)
                        
                        // 2. FLASHING (WRITE) SECTION
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 30)
                                Text("Flasher la Cartographie (Écriture)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if mapManager.isFlashing {
                                    ProgressView()
                                }
                            }
                            
                            if mapManager.backupFiles.isEmpty {
                                Text("Aucune sauvegarde (.bin) trouvée dans les documents. Effectuez d'abord une sauvegarde pour pouvoir flasher.")
                                    .font(.captionText)
                                    .foregroundStyle(.gray)
                            } else {
                                Picker("Fichier Source", selection: $selectedBackupURL) {
                                    ForEach(mapManager.backupFiles, id: \.self) { fileURL in
                                        Text(fileURL.lastPathComponent)
                                            .font(.monoSmall)
                                            .tag(fileURL as URL?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(mapManager.isFlashing || mapManager.isBackingUp)
                                
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
                                        Text("Démarrer le Flashage UDS")
                                            .font(.appButton)
                                            .frame(maxWidth: .infinity)
                                            .padding(10)
                                            .background(isReadyToFlash ? Color.red : Color.gray.opacity(0.3))
                                            .foregroundStyle(.white)
                                            .clipShape(.rect(cornerRadius: 8))
                                    }
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
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCardBackground)
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
                        
                        // Status Messages within section
                        if let error = mapManager.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.captionText)
                                .listRowBackground(Color.red.opacity(0.1))
                        }
                        
                        if let success = mapManager.successMessage {
                            Text(success)
                                .foregroundStyle(.green)
                                .font(.captionText)
                                .listRowBackground(Color.green.opacity(0.1))
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                if maintenanceManager.isExecuting {
                    Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Exécution en cours...")
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(Color(white: 0.2))
                    .clipShape(.rect(cornerRadius: 5))
                }
            }
            .navigationTitle("Fonctions de Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
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
                        try? await panda.setSafetyModel(.elm327)
                        NSLog("[MaintenanceView] Restored Panda safety model to ELM327")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
