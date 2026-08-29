import SwiftUI

struct MaintenanceActuatorsSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool
    
    @State private var showingFullDashboard = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Déclenchement forcé des actionneurs (UDS Service 30)")
                    .font(.captionText)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 4)

                // Quick Full Dashboard Button
                Button {
                    showingFullDashboard = true
                } label: {
                    HStack {
                        Image(systemName: "gauge.with.needle.fill")
                            .foregroundStyle(Color.appAccent)
                        Text("Ouvrir le Tableau de Bord des Actionneurs & Instruments")
                            .font(.caption).bold()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.appAccent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)

                // GMV
                HStack {
                    Text("Moto-ventilateur (Refroidissement)")
                        .font(.bodyText)
                    Spacer()
                    Button("Petite V") {
                        Task {
                            await maintenanceManager.runActuatorTest(interface: interface, ecuHeader: "7E0", command: "300102", name: "Moto-ventilateur Petite Vitesse")
                        }
                    }
                    .font(.captionText)
                    .glassActionButton()
                    .disabled(!isConnected || maintenanceManager.isExecuting)

                    Button("Grande V") {
                        Task {
                            await maintenanceManager.runActuatorTest(interface: interface, ecuHeader: "7E0", command: "300101", name: "Moto-ventilateur Grande Vitesse")
                        }
                    }
                    .font(.captionText)
                    .glassActionButton()
                    .disabled(!isConnected || maintenanceManager.isExecuting)
                }

                Divider().background(Color.white.opacity(0.05))

                // Clim
                HStack {
                    Text("Compresseur Climatisation (AC)")
                        .font(.bodyText)
                    Spacer()
                    Button("Déclencher") {
                        Task {
                            await maintenanceManager.runActuatorTest(interface: interface, ecuHeader: "7E0", command: "300103", name: "Embrayage Compresseur Clim")
                        }
                    }
                    .font(.captionText)
                    .glassActionButton()
                    .disabled(!isConnected || maintenanceManager.isExecuting)
                }

                Divider().background(Color.white.opacity(0.05))

                // Avertisseur
                HStack {
                    Text("Avertisseur Sonore (Klaxon)")
                        .font(.bodyText)
                    Spacer()
                    Button("Déclencher") {
                        Task {
                            await maintenanceManager.runActuatorTest(interface: interface, ecuHeader: "745", command: "300104", name: "Avertisseur Sonore (Klaxon)")
                        }
                    }
                    .font(.captionText)
                    .glassActionButton()
                    .disabled(!isConnected || maintenanceManager.isExecuting)
                }

                Divider().background(Color.white.opacity(0.05))

                // Essuie-glaces
                HStack {
                    Text("Balayage Essuie-glace")
                        .font(.bodyText)
                    Spacer()
                    Button("Déclencher") {
                        Task {
                            await maintenanceManager.runActuatorTest(interface: interface, ecuHeader: "745", command: "300105", name: "Balayage Essuie-glace")
                        }
                    }
                    .font(.captionText)
                    .glassActionButton()
                    .disabled(!isConnected || maintenanceManager.isExecuting)
                }
            }
            .padding(.vertical, 8)
            .sheet(isPresented: $showingFullDashboard) {
                NavigationStack {
                    ActuatorDashboardView(interface: interface)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fermer") {
                                    showingFullDashboard = false
                                }
                            }
                        }
                }
            }
        } label: {
            Text("Test des Actionneurs")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
