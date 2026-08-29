import SwiftUI

enum CustomizationCategory: String, CaseIterable, Identifiable {
    case lighting = "Éclairage & Visibilité"
    case doors = "Portes, Vitres & Sécurité"
    case cluster = "Combiné & Habitacle"
    case driverAssistance = "Aides & Multimédia"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .lighting: return "headlight.high.beam.fill"
        case .doors: return "lock.fill"
        case .cluster: return "gauge.with.needle.fill"
        case .driverAssistance: return "car.rear.and.tire.marks"
        }
    }
}

struct ConfigurationView: View {
    let interface: VehicleInterface
    @State private var configManager = ConfigurationManager()
    @Environment(PandaTransport.self) private var pandaTransport

    @State private var selectedTheme: CustomizationCategory = .lighting

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
                // Connection Banner if not connected
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

                // Category Switcher Pills
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(CustomizationCategory.allCases) { category in
                            Button {
                                selectedTheme = category
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.iconName)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.caption).bold()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTheme == category ? Color.appAccent : Color.white.opacity(0.06))
                                .foregroundStyle(selectedTheme == category ? .white : .secondary)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)

                // Themed Content Card
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTheme {
                    case .lighting:
                        LightingConfigSection(configManager: configManager)
                    case .doors:
                        DoorsSecurityConfigSection(configManager: configManager)
                    case .cluster:
                        ClusterConfigSection(configManager: configManager)
                    case .driverAssistance:
                        DriverAssistanceConfigSection(configManager: configManager)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // Write / Save Button
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
                                Text("Écriture dans les calculateurs...")
                                    .bold()
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Enregistrer les Personnalisations")
                                    .bold()
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
                            Text("Télécodage validé par les calculateurs !")
                                .font(.statusText)
                                .foregroundStyle(.green)
                        }
                    }

                    if let error = configManager.actionError {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.statusText)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Télécodage & Options")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        if let panda = interface as? PandaDriver {
                            try? await panda.setSafetyModel(.allOutput)
                        }
                        await configManager.readConfig(interface: interface)
                    }
                } label: {
                    Label {
                        Text(configManager.isReading ? "Lecture..." : "Lire les calculateurs")
                    } icon: {
                        if configManager.isReading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .disabled(configManager.isReading || configManager.isWriting || !isConnected)
            }
        }
        .task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            if isConnected {
                await configManager.readConfig(interface: interface)
            }
        }
    }
}

// MARK: - 1. Éclairage & Visibilité
private struct LightingConfigSection: View {
    @Bindable var configManager: ConfigurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Éclairage & Visibilité")
                .font(.headline)
                .foregroundStyle(.white)

            Toggle(isOn: $configManager.drlEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feux de Jour (DRL)")
                        .font(.bodyText)
                    Text("Allumage automatique des feux diurnes dès le contact")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.xenonHeadlights) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projecteurs Xénon / LED")
                        .font(.bodyText)
                    Text("Gestion de l'allumage haute tension et assiette")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Divider().background(Color.white.opacity(0.05))

            Toggle(isOn: $configManager.followMeHome) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Éclairage d'Accompagnement (Follow-me-home)")
                        .font(.bodyText)
                    Text("Maintien des phares allumés après verrouillage")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            if configManager.followMeHome {
                HStack {
                    Text("Durée d'allumage")
                        .font(.bodyText).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $configManager.comingHomeDuration) {
                        Text("30 secondes").tag(30)
                        Text("60 secondes").tag(60)
                        Text("120 secondes").tag(120)
                    }
                    .pickerStyle(.menu)
                }
            }

            Divider().background(Color.white.opacity(0.05))

            Toggle(isOn: $configManager.oneTouchTurnSignal) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clignotants Impulsionnels")
                        .font(.bodyText)
                    Text("Clignotement automatique sur simple impulsion du commodo")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            if configManager.oneTouchTurnSignal {
                HStack {
                    Text("Nombre de clignotements")
                        .font(.bodyText).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $configManager.laneChangeFlashes) {
                        Text("3 coups").tag(3)
                        Text("5 coups").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }

            Divider().background(Color.white.opacity(0.05))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feux de Virage (Cornering AFS)")
                        .font(.bodyText)
                    Text("Allumage des antibrouillards selon le braquage")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $configManager.corneringLightsMode) {
                    Text("Désactivé").tag(0)
                    Text("Virage Seul").tag(1)
                    Text("AFS Seul").tag(2)
                    Text("Virage + AFS").tag(3)
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - 2. Portes, Vitres & Sécurité
private struct DoorsSecurityConfigSection: View {
    @Bindable var configManager: ConfigurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Portes, Vitres & Sécurité")
                .font(.headline)
                .foregroundStyle(.white)

            Toggle(isOn: $configManager.autoLockDoors) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Condamnation Automatique en Roulant (Auto-Lock)")
                        .font(.bodyText)
                    Text("Verrouillage de tous les ouvrants dès 10 km/h")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.selectiveUnlocking) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Déverrouillage Sélectif")
                        .font(.bodyText)
                    Text("1ère impulsion clé : porte conducteur. 2ème impulsion : tout le véhicule")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.acousticLockConfirmation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bip Sonore de Confirmation au Verrouillage")
                        .font(.bodyText)
                    Text("Court coup d'avertisseur sonore ou sirène à la fermeture")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Divider().background(Color.white.opacity(0.05))

            Toggle(isOn: $configManager.rainClosing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fermeture Automatique des Vitres en cas de Pluie")
                        .font(.bodyText)
                    Text("Remonte les vitres si le capteur détecte de la pluie à l'arrêt")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.autoRearWiper) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Essuie-Glace Arrière en Marche Arrière")
                        .font(.bodyText)
                    Text("Coup de balai automatique si les essuie-glaces AV sont actifs")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.tpmsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Surveillance Pression des Pneus (SSPP / TPMS)")
                        .font(.bodyText)
                    Text("Alerte de sous-gonflage sur le tableau de bord")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 3. Combiné d'Instruments & Habitacle
private struct ClusterConfigSection: View {
    @Bindable var configManager: ConfigurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Combiné d'Instruments & Habitacle")
                .font(.headline)
                .foregroundStyle(.white)

            Toggle(isOn: $configManager.needleSweep) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balayage des Aiguilles (Gauge Staging)")
                        .font(.bodyText)
                    Text("Les aiguilles de vitesse et RPM vont au max au contact")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.seatbeltWarning) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avertisseur Sonore Ceinture (Bip)")
                        .font(.bodyText)
                    Text("Signal sonore continu si la ceinture conducteur n'est pas bouclée")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.startStopMemory) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mémoire du Système Start & Stop")
                        .font(.bodyText)
                    Text("Conserve le dernier état (activé/désactivé) au redémarrage")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Divider().background(Color.white.opacity(0.05))

            HStack {
                Text("Langue de l'Afficheur")
                    .font(.bodyText).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $configManager.dashboardLanguage) {
                    Text("Français").tag("FR")
                    Text("English").tag("EN")
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Unité de Consommation")
                    .font(.bodyText).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $configManager.consumptionUnit) {
                    Text("L/100 km").tag("L/100")
                    Text("km/L").tag("KM/L")
                }
                .pickerStyle(.menu)
            }

            Toggle(isOn: $configManager.overspeedWarning) {
                Text("Alarme de Survitesse")
                    .font(.bodyText)
            }

            if configManager.overspeedWarning {
                HStack {
                    Text("Seuil de déclenchement")
                        .font(.bodyText).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $configManager.overspeedThreshold) {
                        Text("90 km/h").tag(90)
                        Text("110 km/h").tag(110)
                        Text("120 km/h").tag(120)
                        Text("130 km/h").tag(130)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

// MARK: - 4. Aides à la Conduite & Infodivertissement
private struct DriverAssistanceConfigSection: View {
    @Bindable var configManager: ConfigurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Aides & Multimédia")
                .font(.headline)
                .foregroundStyle(.white)

            Toggle(isOn: $configManager.androidAuto) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Android Auto / Apple CarPlay")
                        .font(.bodyText)
                    Text("Activation de la réplication smartphone sur l'écran tactile")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $configManager.rearViewCamera) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Caméra de Recul")
                        .font(.bodyText)
                    Text("Affichage automatique du flux vidéo au passage de la marche arrière")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }

            Divider().background(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 6) {
                Text("Radar de Recul (AAS) - Volume")
                    .font(.bodyText)
                Picker("", selection: $configManager.parkAssistVolume) {
                    Text("Désactivé (0)").tag(0)
                    Text("Faible (2)").tag(2)
                    Text("Moyen (3)").tag(3)
                    Text("Fort (5)").tag(5)
                    Text("Maximum (7)").tag(7)
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $configManager.coldClimateMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mode Climat Froid (Frein de Parking)")
                        .font(.bodyText)
                    Text("Évite le serrage automatique par gel intense pour ne pas coller les plaquettes")
                        .font(.captionTiny).foregroundStyle(.secondary)
                }
            }
        }
    }
}
