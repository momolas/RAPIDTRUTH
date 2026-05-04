import SwiftUI

struct MaintenanceView: View {
    let interface: VehicleInterface
    @Environment(\.dismiss) var dismiss
    @State private var maintenanceManager = MaintenanceManager()
    private var pandaTransport = PandaTransport.shared
    @State private var showingDPFAlert = false
    @State private var showingEPBAlert = false
    @State private var showingOilAlert = false

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
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
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .listRowBackground(Color.appCardBackground)
                        }

                        if let error = maintenanceManager.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .listRowBackground(Color.red.opacity(0.1))
                        }

                        if let success = maintenanceManager.successMessage {
                            Text(success)
                                .foregroundStyle(.green)
                                .font(.caption)
                                .listRowBackground(Color.green.opacity(0.1))
                        }
                    }

                    Section(header: Text("Vidange & Entretien").foregroundStyle(.gray)) {
                        Button(action: {
                            showingOilAlert = true
                        }) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 30)
                                Text("Remise à zéro Intervalle Vidange")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                            }
                        }
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
                        }) {
                            HStack {
                                Image(systemName: "parkingsign.circle.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 30)
                                Text("Mode Atelier Frein de Parking (FPA)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                            }
                        }
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
                    }

                    Section(header: Text("Échappement").foregroundStyle(.gray)) {
                        Button(action: {
                            showingDPFAlert = true
                        }) {
                            HStack {
                                Image(systemName: "smoke.fill")
                                    .foregroundStyle(.gray)
                                    .frame(width: 30)
                                Text("Régénération Forcée FAP")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                            }
                        }
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
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Fonctions de Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
