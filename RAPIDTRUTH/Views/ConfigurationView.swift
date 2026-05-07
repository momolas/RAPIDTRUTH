import SwiftUI

struct ConfigurationView: View {
    let interface: VehicleInterface
    @Environment(\.dismiss) var dismiss
    @State private var configManager = ConfigurationManager()
    private var pandaTransport = PandaTransport.shared


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
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
        }
    }
}
