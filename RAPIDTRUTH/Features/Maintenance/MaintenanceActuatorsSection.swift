import SwiftUI
import SwiftVehicleProtocols

struct MaintenanceActuatorsSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool
    
    @State private var showingFullDashboard = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Commande active des actionneurs et tests de combiné (UDS Service 30 / 2F).")
                    .font(.captionText)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                Button {
                    showingFullDashboard = true
                } label: {
                    HStack {
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ouvrir le Tableau de Bord des Actionneurs")
                                .font(.bodyText).bold()
                                .foregroundStyle(.white)
                            Text("16 actionneurs : Aiguilles, Voyants, Ventilateurs, Climatisation, Klaxon...")
                                .font(.captionTiny)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.appAccent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.appAccent.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!isConnected)
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
            Text("Test des Actionneurs & Instruments")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
