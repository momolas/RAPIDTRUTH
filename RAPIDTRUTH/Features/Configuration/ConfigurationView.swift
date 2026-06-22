import SwiftUI

struct ConfigurationView: View {
    let interface: VehicleInterface
    @State private var configManager = ConfigurationManager()
    @Environment(PandaTransport.self) private var pandaTransport

    @State private var isTdbExpanded = true
    @State private var isUchExpanded = false
    @State private var isUpcExpanded = false
    @State private var isFpaExpanded = false
    @State private var isAasExpanded = false
    @State private var isRadNavExpanded = false

    init(interface: VehicleInterface) {
        self.interface = interface
    }

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
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

                VStack(alignment: .leading, spacing: 16) {
                    // TdB Group
                    DisclosureGroup(isExpanded: $isTdbExpanded) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Langue de l'Afficheur")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.dashboardLanguage) {
                                    Text("Français").tag("FR")
                                    Text("English").tag("EN")
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Toggle(isOn: $configManager.seatbeltWarning) {
                                Text("Alerte Ceinture (Bip)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Toggle(isOn: $configManager.clockDisplay) {
                                Text("Affichage Horloge / Temp.")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Unité de Consommation")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.consumptionUnit) {
                                    Text("L/100 km").tag("L/100")
                                    Text("km/L").tag("KM/L")
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Toggle(isOn: $configManager.overspeedWarning) {
                                Text("Alarme Survitesse (120)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Motorisation / Carburant")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.fuelType) {
                                    Text("Diesel").tag("DSL")
                                    Text("Essence").tag("GSL")
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Type de Boîte")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.gearboxType) {
                                    Text("Manuelle (BVM)").tag("BVM")
                                    Text("Automatique (BVA)").tag("BVA")
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Toggle(isOn: $configManager.voiceSynthesis) {
                                Text("Synthèse Vocale d'Alerte")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Intervalle de Maintenance")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.oilServiceInterval) {
                                    Text("15 000 km / 1 an").tag("15K")
                                    Text("20 000 km / 1 an").tag("20K")
                                    Text("30 000 km / 2 ans").tag("30K")
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Tableau de Bord (TdB)")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))

                    // UCH Group
                    DisclosureGroup(isExpanded: $isUchExpanded) {
                        VStack(spacing: 12) {
                            Toggle(isOn: $configManager.autoLockDoors) {
                                Text("Condamnation Auto (CAR)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.autoRearWiper) {
                                Text("Essuie-glace Arrière Auto")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.followMeHome) {
                                Text("Éclairage d'Accompagnement")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.oneTouchTurnSignal) {
                                Text("Clignotants Impulsionnels")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.deadlocking) {
                                Text("Supercondamnation")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.tpmsEnabled) {
                                Text("Contrôle de Pression (SSPP)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.autoRainSensor) {
                                Text("Essuyage Auto (Pluie)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.keylessGo) {
                                Text("Accès & Démarrage Main-Libre")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.selectiveUnlocking) {
                                Text("Condamnation Porte Sélective")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Unité Centrale Habitacle (UCH)")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))

                    // UPC Group
                    DisclosureGroup(isExpanded: $isUpcExpanded) {
                        VStack(spacing: 12) {
                            Toggle(isOn: $configManager.xenonHeadlights) {
                                Text("Projecteurs Xénon")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.drlEnabled) {
                                Text("Feux de Jour (DRL)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Puissance Alternateur")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.alternatorClass) {
                                    Text("Standard (110A)").tag("110A")
                                    Text("Grand Froid (150A)").tag("150A")
                                }
                                .pickerStyle(.menu)
                            }
                            HStack {
                                Text("Feux de Virage (Cornering)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.corneringLightsMode) {
                                    Text("Désactivé").tag(0)
                                    Text("Cornering Actif").tag(1)
                                    Text("AFS Seuls").tag(2)
                                    Text("Cornering + AFS").tag(3)
                                }
                                .pickerStyle(.menu)
                            }
                            HStack {
                                Text("Seuil Vitesse Cornering")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.corneringSpeedThreshold) {
                                    Text("30 km/h").tag(30)
                                    Text("40 km/h").tag(40)
                                    Text("50 km/h").tag(50)
                                    Text("60 km/h").tag(60)
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Unité Commutation Moteur (UPC)")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // FPA Group
                    DisclosureGroup(isExpanded: $isFpaExpanded) {
                        VStack(spacing: 12) {
                            Toggle(isOn: $configManager.coldClimateMode) {
                                Text("Mode Pays Froids (Sans serrage auto)")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Frein de Parking Assisté (FPA)")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // AAS Group
                    DisclosureGroup(isExpanded: $isAasExpanded) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Volume du Bruiteur")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.parkAssistVolume) {
                                    Text("Silencieux").tag(0)
                                    Text("Faible").tag(2)
                                    Text("Moyen").tag(3)
                                    Text("Fort").tag(6)
                                }
                                .pickerStyle(.menu)
                            }
                            HStack {
                                Text("Fréquence du Signal")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $configManager.parkAssistTone) {
                                    Text("500 Hz").tag(0)
                                    Text("666 Hz").tag(1)
                                    Text("800 Hz").tag(2)
                                    Text("1000 Hz").tag(3)
                                }
                                .pickerStyle(.menu)
                            }
                            Toggle(isOn: $configManager.parkAssistInhibitionButton) {
                                Text("Bouton d'Inhibition Habitacle")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Aide au Stationnement (AAS)")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // RadNav Group
                    DisclosureGroup(isExpanded: $isRadNavExpanded) {
                        VStack(spacing: 12) {
                            Toggle(isOn: $configManager.androidAuto) {
                                Text("Android Auto / CarPlay")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle(isOn: $configManager.rearViewCamera) {
                                Text("Caméra de Recul")
                                    .font(.bodyText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("Radio / Multimédia (RadNav)")
                            .font(.valueLabel)
                            .foregroundStyle(.white)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    Button(action: {
                        Task {
                            if let panda = interface as? PandaDriver {
                                try? await panda.setSafetyModel(.allOutput)
                            }
                            await configManager.writeConfig(interface: interface)
                        }
                    }) {
                        HStack {
                            Spacer()
                            if configManager.isWriting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Écriture en cours...")
                            } else {
                                Text("Enregistrer dans l'ECU")
                            }
                            Spacer()
                        }
                        .font(.appButton)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(configManager.isWriting || configManager.isReading || !isConnected)
                    .glassActionButton(prominent: true)
                    .buttonBorderShape(.roundedRectangle)
                    
                    if configManager.showSuccessMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Codage réussi !")
                                .font(.statusText)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    if let error = configManager.actionError {
                        Text(error)
                            .font(.statusText)
                            .foregroundStyle(.red)
                    }
                }
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Codage & Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        if let panda = interface as? PandaDriver {
                            try? await panda.setSafetyModel(.allOutput)
                        }
                        await configManager.readConfig(interface: interface)
                    }
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
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
                NSLog("[ConfigurationView] Switched Panda safety model to ALLOUTPUT for coding")
            }
            if isConnected {
                await configManager.readConfig(interface: interface)
            }
        }
        .onDisappear {
            if let panda = interface as? PandaDriver {
                Task {
                    try? await panda.setSafetyModel(.silent)
                    NSLog("[ConfigurationView] Switched Panda safety model back to SILENT")
                }
            }
        }
    }
}
