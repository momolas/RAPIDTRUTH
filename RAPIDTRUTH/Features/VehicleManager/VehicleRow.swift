import SwiftUI

struct VehicleRow: View {
    let vehicle: Vehicle
    @Environment(SettingsStore.self) private var settings
    
    let onReprobe: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.displayName)
                        .font(.valueLabel)
                    Text(vehicle.slug + " · " + vehicle.profileId)
                        .font(.monoSmall)
                        .foregroundStyle(.tertiary)
                    Text("\(vehicle.supportedStandardPIDs.count) std · \(vehicle.supportedProfilePIDs.count) profile PIDs cached")
                        .font(.monoSmall)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if settings.activeVehicleSlug == vehicle.slug {
                    Text("ACTIVE")
                        .font(.monoSmall)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(.rect(cornerRadius: 4))
                } else {
                    Button("Activate") {
                        settings.activeVehicleSlug = vehicle.slug
                    }
                    .glassActionButton(prominent: false)
                    .controlSize(.small)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Button("Re-probe PIDs", action: onReprobe)
                    .glassActionButton(prominent: false)
                    .controlSize(.small)
                Text("Clears the cached supported-PID list. Next session re-runs the discovery + probe from scratch.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .top, spacing: 8) {
                Button(role: .destructive, action: onRemove) {
                    Text("Remove")
                }
                .glassActionButton(prominent: false)
                .controlSize(.small)
                Text("Deletes this vehicle from the app. Recorded sessions on disk are kept.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.appCardBackground)
        .clipShape(.rect(cornerRadius: 8))
    }
}
