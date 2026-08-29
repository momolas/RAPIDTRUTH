import SwiftUI

struct MaintenanceOilSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool
    
    @State private var showingOilAlert = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    showingOilAlert = true
                }) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.orange)
                        Text("Réinitialiser Intervalle Vidange")
                        Spacer()
                    }
                    .font(.appButton)
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
            }
            .padding(.vertical, 8)
        } label: {
            Text("Vidange & Entretien")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
