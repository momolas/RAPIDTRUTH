import SwiftUI
import SwiftVehicleProtocols

struct FuzzerPersistenceSection: View {
    let vehicle: Vehicle?
    let profile: Profile?
    let hasCANResults: Bool
    let hasLINResults: Bool
    let isLINMode: Bool
    
    let saveSuccessMessage: String?
    let saveErrorMessage: String?
    
    var onEnrichProfile: () -> Void
    var onExportCAN: () -> Void
    var onExportLIN: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAUVEGARDE & PERSISTANCE")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                
            if let vehicle {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Véhicule actif : \(vehicle.displayName)")
                        .font(.bodyText)
                        .bold()
                    
                    if !isLINMode, let profile {
                        Text("Profil : \(profile.displayName) (v\(profile.profileVersion))")
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Button("Enrichir le profil", systemImage: "plus.square.dashed", action: onEnrichProfile)
                                .glassActionButton(prominent: true)
                            
                            Button("Exporter JSON", systemImage: "doc.badge.plus", action: onExportCAN)
                                .glassActionButton(prominent: false)
                        }
                        .padding(.top, 4)
                    } else if isLINMode {
                        Button("Exporter les trames LIN (JSON)", systemImage: "doc.badge.plus", action: onExportLIN)
                            .glassActionButton(prominent: true)
                            .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.02))
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aucun véhicule sélectionné comme actif")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    Text("Veuillez sélectionner un véhicule dans le garage de l'application pour activer l'enrichissement de profil et l'export.")
                        .font(.captionTiny)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color.white.opacity(0.02))
                .clipShape(.rect(cornerRadius: 8))
            }
            
            if let msg = saveSuccessMessage {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.captionText)
                        .foregroundStyle(.green)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
                .padding(.top, 8)
            }
            
            if let err = saveErrorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.captionText)
                        .foregroundStyle(.red)
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }
}
