import SwiftUI

struct MaintenanceOilSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool
    
    @State private var showingOilAlert = false
    @State private var showingBatterySheet = false
    @State private var showingThrottleAlert = false
    @State private var showingAdaptationsAlert = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Remise à zéro Vidange
                Button(action: {
                    showingOilAlert = true
                }) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Réinitialiser Intervalle Vidange")
                                .font(.bodyText)
                            Text("Remet le compteur de révision à zéro sur le combiné")
                                .font(.captionTiny)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
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

                // 2. Enregistrement Nouvelle Batterie (BMS)
                Button(action: {
                    showingBatterySheet = true
                }) {
                    HStack {
                        Image(systemName: "battery.100.bolt")
                            .foregroundStyle(Color.appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enregistrement Nouvelle Batterie (BMS)")
                                .font(.bodyText)
                            Text("Déclaration type (AGM/EFB) et capacité (Ah) au calculateur")
                                .font(.captionTiny)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!isConnected || maintenanceManager.isExecuting)
                .glassActionButton()

                // 3. Réapprentissage Boîtier Papillon
                Button(action: {
                    showingThrottleAlert = true
                }) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alignement & Réapprentissage Boîtier Papillon")
                                .font(.bodyText)
                            Text("Calibre les butées électroniques min/max du papillon motorisé")
                                .font(.captionTiny)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .disabled(!isConnected || maintenanceManager.isExecuting)
                .glassActionButton()
                .alert("Réapprentissage Papillon", isPresented: $showingThrottleAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Lancer l'alignement") {
                        Task { await maintenanceManager.adaptThrottleBody(interface: interface) }
                    }
                } message: {
                    Text("Moteur coupé, contact mis. Le papillon va exécuter un cycle complet de calibration.")
                }

                // 4. Réinitialisation Autoadaptatifs Moteur
                Button(action: {
                    showingAdaptationsAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Réinitialiser les Autoadaptatifs Moteur")
                                .font(.bodyText)
                            Text("Efface les dérives d'injection et réinitialise les trims carburant")
                                .font(.captionTiny)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .disabled(!isConnected || maintenanceManager.isExecuting)
                .glassActionButton()
                .alert("Réinitialiser les Autoadaptatifs", isPresented: $showingAdaptationsAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Confirmer", role: .destructive) {
                        Task { await maintenanceManager.resetECUAdaptations(interface: interface) }
                    }
                } message: {
                    Text("À effectuer après remplacement de capteurs (débitmètre, sonde lambda, injecteurs).")
                }
            }
            .padding(.vertical, 8)
            .sheet(isPresented: $showingBatterySheet) {
                BatteryRegistrationSheet(
                    interface: interface,
                    isConnected: isConnected,
                    maintenanceManager: maintenanceManager
                )
            }
        } label: {
            Text("Entretien, Batterie & Moteur")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
