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
                    Text("\(vehicle.supportedStandardPIDs.count) std · \(vehicle.supportedProfilePIDs.count) pids profil en cache")
                        .font(.monoSmall)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if settings.activeVehicleSlug == vehicle.slug {
                    Text("ACTIF")
                        .font(.monoSmall)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(.rect(cornerRadius: 4))
                } else {
                    Button("Activer") {
                        settings.activeVehicleSlug = vehicle.slug
                    }
                    .glassActionButton(prominent: false)
                    .controlSize(.small)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Button("Réanalyser PIDs", action: onReprobe)
                    .glassActionButton(prominent: false)
                    .controlSize(.small)
                Text("Vide la liste des PIDs supportés en cache. La prochaine session relancera la détection à zéro.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .top, spacing: 8) {
                Button(role: .destructive, action: onRemove) {
                    Text("Supprimer")
                }
                .glassActionButton(prominent: false)
                .controlSize(.small)
                Text("Supprime ce véhicule de l'application. Les sessions enregistrées sur disque sont conservées.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.appCardBackground)
        .clipShape(.rect(cornerRadius: 8))
    }
}
