import SwiftUI
import SwiftVehicleProtocols

struct MaintenanceBrakesSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool
    @Binding var showingEPBWizard: Bool
    @Binding var showingABSWizard: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    showingEPBWizard = true
                }) {
                    HStack {
                        Image(systemName: "parkingsign.circle.fill")
                            .foregroundStyle(.red)
                        Text("Assistant Remplacement Plaquettes (EPB/FPA)")
                        Spacer()
                    }
                    .font(.appButton)
                }
                .disabled(!isConnected || maintenanceManager.isExecuting)
                .glassActionButton()

                Button(action: {
                    showingABSWizard = true
                }) {
                    HStack {
                        Image(systemName: "fluid.brakesignal")
                            .foregroundStyle(.red)
                        Text("Assistant Purge Bloc ABS")
                        Spacer()
                    }
                    .font(.appButton)
                }
                .disabled(!isConnected || maintenanceManager.isExecuting)
                .glassActionButton()
            }
            .padding(.vertical, 8)
        } label: {
            Text("Freinage")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
