import SwiftUI
import SwiftVehicleProtocols

struct MaintenanceExhaustSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool
    
    @State private var showingDPFAlert = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    showingDPFAlert = true
                }) {
                    HStack {
                        Image(systemName: "smoke.fill")
                            .foregroundStyle(.gray)
                        Text("Régénération Forcée FAP")
                        Spacer()
                    }
                    .font(.appButton)
                }
                .disabled(!isConnected || maintenanceManager.isExecuting)
                .glassActionButton()
                .alert("Régénération FAP DANGER", isPresented: $showingDPFAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Lancer Régénération", role: .destructive) {
                        Task { await maintenanceManager.forceDPFRegeneration(interface: interface) }
                    }
                } message: {
                    Text("AVERTISSEMENT : La régénération statique fera monter le régime moteur et la température d'échappement très haut (>600°C). Effectuez cette opération en extérieur, sur une surface ininflammable, capot ouvert, avec un réservoir au moins au quart plein. Ne quittez pas le véhicule pendant l'opération.")
                }
            }
            .padding(.vertical, 8)
        } label: {
            Text("Échappement")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
