import SwiftUI

struct ConfigurationView: View {
    let elm: ELM327
    @Environment(\.dismiss) var dismiss
    @State private var configManager = ConfigurationManager()
    private var ble = BLEManager.shared

    init(elm: ELM327) {
        self.elm = elm
    }

    private var isConnected: Bool {
        if case .connected = ble.connectionState { return true }
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
                    
                    Toggle("Alerte Ceinture (Bip)", isOn: $configManager.seatbeltWarning)
                }
                
                Section(header: Text("Unité Centrale Habitacle (UCH)")) {
                    Toggle("Condamnation Auto (CAR)", isOn: $configManager.autoLockDoors)
                }
                
                Section {
                    Button(action: {
                        Task { await configManager.writeConfig(elm: elm) }
                    }) {
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
                    }
                    .disabled(configManager.isWriting || configManager.isReading || !isConnected)
                    .listRowBackground(Color.blue)
                    .foregroundStyle(.white)
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
                        Task { await configManager.readConfig(elm: elm) }
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
                    await configManager.readConfig(elm: elm)
                }
            }
        }
    }
}
