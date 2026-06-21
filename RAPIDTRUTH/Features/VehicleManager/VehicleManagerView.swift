import SwiftUI
import UniformTypeIdentifiers

/// Sheet body for the vehicle-management flow. Presented from
/// `VehicleCardView` when the user taps the active-vehicle card on the
/// main shell. Houses the three actions that used to clutter the main
/// shell — Add, Import profile, Re-probe — in one place.
struct VehicleManagerSheet: View {
    let driver: VehicleInterface
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(ProfileRegistry.self) private var profileRegistry

    @State private var showAdd = false
    @State private var showImporter = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VehicleManagerActionRow(showAdd: $showAdd, showImporter: $showImporter)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 6))
                    }

                    if vehicleStore.vehicles.isEmpty {
                        ContentUnavailableView(
                            "Aucun véhicule",
                            systemImage: "car.fill",
                            description: Text("Touchez **Ajouter un véhicule** pour en configurer un — la lecture automatique du VIN et le décodage par l'API prérempliront l'année, la marque et le modèle.")
                        )
                        .padding(.vertical, 16)
                    } else {
                        ForEach(vehicleStore.vehicles) { vehicle in
                            VehicleRow(
                                vehicle: vehicle,
                                onReprobe: { reprobePIDs(for: vehicle) },
                                onRemove: { removeVehicle(vehicle) }
                            )
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAdd) {
            AddVehicleView(driver: driver)
                .onDisappear {
                    vehicleStore.reload(owner: settings.owner)
                }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let profile = try ProfileImporter.importProfile(from: url)
                    profileRegistry.reload()
                    statusMessage = "Profil importé avec succès : \(profile.displayName)"
                } catch {
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
        .task {
            vehicleStore.reload(owner: settings.owner)
        }
    }

    private func removeVehicle(_ vehicle: Vehicle) {
        do {
            try vehicleStore.delete(slug: vehicle.slug, owner: vehicle.owner)
            if settings.activeVehicleSlug == vehicle.slug {
                settings.activeVehicleSlug = vehicleStore.vehicles.first?.slug
            }
            statusMessage = "Véhicule « \(vehicle.displayName) » supprimé de l'application."
        } catch {
            statusMessage = "Échec de la suppression : \(error.localizedDescription)"
        }
    }

    private func reprobePIDs(for vehicle: Vehicle) {
        // Clear the cached supported lists so the next session re-runs
        // the (now ATSH-aware) standard discovery + profile probe from
        // scratch. Useful when an early session populated the cache via
        // the old broadcast-addressed probe and produced false positives.
        do {
            try vehicleStore.clearPIDCaches(slug: vehicle.slug, owner: vehicle.owner)
            statusMessage = "Cache des PIDs vidé pour \(vehicle.displayName). La prochaine session relancera la détection automatique."
        } catch {
            statusMessage = "Échec du vidage de cache : \(error.localizedDescription)"
        }
    }
}
