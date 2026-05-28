import SwiftUI

struct ConfigurationView: View {
    let interface: VehicleInterface
    @Environment(\.dismiss) var dismiss
    @State private var configManager = ConfigurationManager()
    @Environment(PandaTransport.self) private var pandaTransport

    init(interface: VehicleInterface) {
        self.interface = interface
    }

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tableau de Bord (TdB)")) {
                    Picker("Langue de l'Afficheur", selection: $configManager.dashboardLanguage) {
                        Text("Français").tag("FR")
                        Text("English").tag("EN")
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Alerte Ceinture (Bip)", isOn: $configManager.seatbeltWarning)
                        .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Affichage Horloge / Temp.", isOn: $configManager.clockDisplay)
                        .listRowBackground(Color.appCardBackground)
                        
                    Picker("Unité de Consommation", selection: $configManager.consumptionUnit) {
                        Text("L/100 km").tag("L/100")
                        Text("km/L").tag("KM/L")
                    }
                    .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Alarme Survitesse (120)", isOn: $configManager.overspeedWarning)
                        .listRowBackground(Color.appCardBackground)
                    
                    Picker("Motorisation / Carburant", selection: $configManager.fuelType) {
                        Text("Diesel").tag("DSL")
                        Text("Essence").tag("GSL")
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Picker("Type de Boîte", selection: $configManager.gearboxType) {
                        Text("Manuelle (BVM)").tag("BVM")
                        Text("Automatique (BVA)").tag("BVA")
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Synthèse Vocale d'Alerte", isOn: $configManager.voiceSynthesis)
                        .listRowBackground(Color.appCardBackground)
                    
                    Picker("Intervalle de Maintenance (OCS)", selection: $configManager.oilServiceInterval) {
                        Text("15 000 km / 1 an").tag("15K")
                        Text("20 000 km / 1 an").tag("20K")
                        Text("30 000 km / 2 ans").tag("30K")
                    }
                    .listRowBackground(Color.appCardBackground)
                }
                
                Section(header: Text("Unité Centrale Habitacle (UCH)")) {
                    Toggle("Condamnation Auto (CAR)", isOn: $configManager.autoLockDoors)
                        .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Essuie-glace Arrière Auto", isOn: $configManager.autoRearWiper)
                        .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Éclairage d'Accompagnement", isOn: $configManager.followMeHome)
                        .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Clignotants Impulsionnels", isOn: $configManager.oneTouchTurnSignal)
                        .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Supercondamnation", isOn: $configManager.deadlocking)
                        .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Contrôle de Pression Pneus (SSPP)", isOn: $configManager.tpmsEnabled)
                        .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Essuyage Auto (Capteur Pluie)", isOn: $configManager.autoRainSensor)
                        .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Accès & Démarrage Main-Libre", isOn: $configManager.keylessGo)
                        .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Condamnation Porte Sélective", isOn: $configManager.selectiveUnlocking)
                        .listRowBackground(Color.appCardBackground)
                }
                
                Section(header: Text("Unité de Commutation (Moteur / UPC)")) {
                    Toggle("Projecteurs Xénon", isOn: $configManager.xenonHeadlights)
                        .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Feux de Jour (DRL)", isOn: $configManager.drlEnabled)
                        .listRowBackground(Color.appCardBackground)
                    
                    Picker("Puissance Alternateur", selection: $configManager.alternatorClass) {
                        Text("Classe Standard (110A)").tag("110A")
                        Text("Classe Grand Froid (150A)").tag("150A")
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Picker("Feux de Virage (Cornering)", selection: $configManager.corneringLightsMode) {
                        Text("Désactivé").tag(0)
                        Text("Cornering Actif (Antibrouillard)").tag(1)
                        Text("Phares Adaptatifs (AFS) Seuls").tag(2)
                        Text("Cornering + AFS Actifs").tag(3)
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Picker("Seuil Vitesse Cornering", selection: $configManager.corneringSpeedThreshold) {
                        Text("30 km/h").tag(30)
                        Text("40 km/h").tag(40)
                        Text("50 km/h").tag(50)
                        Text("60 km/h").tag(60)
                    }
                    .listRowBackground(Color.appCardBackground)
                }
                
                Section(header: Text("Frein de Parking Assisté (FPA)")) {
                    Toggle("Mode Pays Froids (Sans serrage auto)", isOn: $configManager.coldClimateMode)
                        .listRowBackground(Color.appCardBackground)
                }
                
                Section(header: Text("Aide au Stationnement (AAS)")) {
                    Picker("Volume du Bruiteur", selection: $configManager.parkAssistVolume) {
                        Text("Désactivé (Silencieux)").tag(0)
                        Text("Faible").tag(2)
                        Text("Moyen").tag(3)
                        Text("Moyen Fort").tag(4)
                        Text("Assez Fort").tag(5)
                        Text("Fort").tag(6)
                        Text("Très Fort").tag(7)
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Picker("Fréquence du Signal Sonore", selection: $configManager.parkAssistTone) {
                        Text("500 Hz").tag(0)
                        Text("666 Hz").tag(1)
                        Text("800 Hz").tag(2)
                        Text("1000 Hz").tag(3)
                        Text("2000 Hz").tag(4)
                    }
                    .listRowBackground(Color.appCardBackground)
                    
                    Toggle("Bouton d'Inhibition Habitacle", isOn: $configManager.parkAssistInhibitionButton)
                        .listRowBackground(Color.appCardBackground)
                }
                
                Section(header: Text("Radio / Multimédia (RadNav)")) {
                    Toggle("Android Auto / CarPlay", isOn: $configManager.androidAuto)
                        .listRowBackground(Color.appCardBackground)
                        
                    Toggle("Caméra de Recul", isOn: $configManager.rearViewCamera)
                        .listRowBackground(Color.appCardBackground)
                }
                
                Section {
                    Button(action: {
                        Task { await configManager.writeConfig(interface: interface) }
                    }, label: {
                        HStack {
                            Spacer()
                            if configManager.isWriting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Écriture en cours...")
                            } else {
                                Text("Enregistrer dans l'ECU")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    })
                    .disabled(configManager.isWriting || configManager.isReading || !isConnected)
                    .listRowBackground(Color.blue)
                    .foregroundStyle(.white)
                    .buttonBorderShape(.roundedRectangle(radius: 5))
                }
                
                if configManager.showSuccessMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Codage réussi !")
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                if let error = configManager.actionError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Codage & Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await configManager.readConfig(interface: interface) }
                    }) {
                        if configManager.isReading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(configManager.isReading || configManager.isWriting || !isConnected)
                }
            }
            .task {
                if isConnected {
                    await configManager.readConfig(interface: interface)
                }
            }
            .onAppear {
                if let panda = interface as? PandaDriver {
                    Task {
                        try? await panda.setSafetyModel(.allOutput)
                        NSLog("[ConfigurationView] Switched Panda safety model to ALLOUTPUT for coding")
                    }
                }
            }
            .onDisappear {
                if let panda = interface as? PandaDriver {
                    Task {
                        try? await panda.setSafetyModel(.elm327)
                        NSLog("[ConfigurationView] Restored Panda safety model to ELM327")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
        }
    }
}
