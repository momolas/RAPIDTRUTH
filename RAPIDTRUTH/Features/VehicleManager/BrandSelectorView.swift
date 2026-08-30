import SwiftUI
import SwiftVehicleProtocols

public struct BrandItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let systemImage: String
    public let color: Color
    public let defaultProfileId: String
    public let description: String

    public static let allBrands: [BrandItem] = [
        BrandItem(
            id: "renault",
            name: "Renault / Dacia",
            systemImage: "car.fill",
            color: .yellow,
            defaultProfileId: "scenic2_obd2",
            description: "DDT2000 Complet · 30+ calculateurs"
        ),
        BrandItem(
            id: "bmw",
            name: "BMW / Mini",
            systemImage: "bolt.car.fill",
            color: .blue,
            defaultProfileId: "bmw_3series_obd2",
            description: "UDS DIDs · Turbo, Rail, Huile ZF8"
        ),
        BrandItem(
            id: "tesla",
            name: "Tesla",
            systemImage: "bolt.fill",
            color: .red,
            defaultProfileId: "tesla_model3y_ev",
            description: "EV DIDs · SoH, Tension Pack, Courant"
        ),
        BrandItem(
            id: "toyota",
            name: "Toyota / Lexus",
            systemImage: "leaf.arrow.triangle.circlepath",
            color: .green,
            defaultProfileId: "toyota_hybrid_obd2",
            description: "Hybride · SOC Batterie HV, MG1/MG2"
        ),
        BrandItem(
            id: "vag",
            name: "VAG (VW / Audi)",
            systemImage: "gauge.with.dots.needle.bottom.50percent",
            color: .cyan,
            defaultProfileId: "vag_golf_obd2",
            description: "UDS · Pression Turbo, Suie FAP"
        ),
        BrandItem(
            id: "generic",
            name: "OBD2 Universel",
            systemImage: "wrench.and.screwdriver.fill",
            color: .gray,
            defaultProfileId: "generic_obd2",
            description: "Standard SAE J1979 · Toutes marques"
        )
    ]
}

struct BrandSelectorView: View {
    var driver: VehicleInterface? = nil
    
    @Environment(SettingsStore.self) private var settings
    @Environment(ProfileRegistry.self) private var profileRegistry
    @Environment(PandaTransport.self) private var pandaTransport
    
    @State private var autoManager = AutoProfileManager.shared
    @State private var showAllProfilesSheet = false

    private var activeProfile: Profile {
        if let manualId = settings.selectedProfileId,
           let prof = profileRegistry.profile(id: manualId) {
            return prof
        }
        return profileRegistry.profile(id: "scenic2_obd2")
            ?? profileRegistry.profile(id: "renault_scenic2_multi_ecu")
            ?? profileRegistry.profiles.first
            ?? Profile.fallback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sélecteur de Marque & Profil")
                    .font(.cardTitle)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showAllProfilesSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Tous (\(profileRegistry.profiles.count))")
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.captionText)
                    .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }

            // Bouton d'auto-détection intelligente et téléchargement OBDb
            Button {
                triggerAutoDetection()
            } label: {
                HStack(spacing: 10) {
                    if isDetecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.headline)
                            .foregroundStyle(Color.appAccent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Détection Automatique & Profil OBDb")
                                .font(.caption).bold()
                                .foregroundStyle(.white)
                            if autoManager.state != .idle {
                                Text("ACTIF")
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.appAccent.opacity(0.2))
                                    .foregroundStyle(Color.appAccent)
                                    .clipShape(.rect(cornerRadius: 3))
                            }
                        }
                        Text(autoDetectionStatusText)
                            .font(.caption2)
                            .foregroundStyle(isDetecting ? Color.appAccent : .secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.appCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isDetecting ? Color.appAccent : Color.white.opacity(0.1), lineWidth: isDetecting ? 1.5 : 0.5)
                )
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isDetecting)

            // Grille de sélection manuelle rapide par constructeur
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BrandItem.allBrands) { brand in
                        let isSelected = activeProfile.profileId.contains(brand.id) || (settings.selectedProfileId == brand.defaultProfileId)
                        
                        Button {
                            selectBrand(brand)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: brand.systemImage)
                                    .font(.subheadline)
                                    .foregroundStyle(brand.color)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(brand.name)
                                        .font(.caption).bold()
                                        .foregroundStyle(.white)
                                    Text(brand.description.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? brand.color.opacity(0.2) : Color.appCardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? brand.color : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Bandeau résumant les capteurs actifs
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profil actif : \(activeProfile.displayName)")
                        .font(.caption).bold()
                        .foregroundStyle(.white)
                    Text("\(activeProfile.pids.count) capteurs et PIDs prêts pour le diagnostic")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(.rect(cornerRadius: 8))
        }
        .sheet(isPresented: $showAllProfilesSheet) {
            AllProfilesPickerSheet()
        }
    }

    private var isDetecting: Bool {
        switch autoManager.state {
        case .readingVIN, .decodingVehicle, .downloadingOBDb:
            return true
        default:
            return false
        }
    }

    private var autoDetectionStatusText: String {
        switch autoManager.state {
        case .idle:
            return "Lit le VIN, identifie la marque et télécharge le profil OBDb adapté"
        case .readingVIN:
            return "Lecture du VIN sur le réseau du véhicule..."
        case .decodingVehicle(let vin):
            return "Décodage du véhicule pour VIN \(vin.prefix(8))..."
        case .downloadingOBDb(let make, let model):
            return "Téléchargement du profil \(make) \(model) depuis OBDb..."
        case .activated(let name, let isBuiltin, let count):
            return "\(isBuiltin ? "Profil Usine" : "Profil OBDb") activé : \(name) (\(count) capteurs)"
        case .failed(let msg):
            return msg
        }
    }

    private func triggerAutoDetection() {
        guard let driver else {
            return
        }
        Task {
            await autoManager.autoDetectAndConfigure(interface: driver)
        }
    }

    private func selectBrand(_ brand: BrandItem) {
        if let match = profileRegistry.profiles.first(where: { $0.profileId == brand.defaultProfileId }) {
            settings.selectedProfileId = match.profileId
        } else if let fuzzy = profileRegistry.profiles.first(where: { $0.profileId.contains(brand.id) }) {
            settings.selectedProfileId = fuzzy.profileId
        } else {
            settings.selectedProfileId = brand.defaultProfileId
        }
    }
}

/// Feuille modale listant l'ensemble exhaustif des profils chargés (OVD, OBDb, DDT2000)
struct AllProfilesPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(ProfileRegistry.self) private var profileRegistry
    
    @State private var searchText = ""

    private var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return profileRegistry.profiles
        }
        return profileRegistry.profiles.filter {
            $0.displayName.localizedStandardContains(searchText) ||
            $0.profileId.localizedStandardContains(searchText) ||
            ($0.description?.localizedStandardContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredProfiles) { prof in
                Button {
                    settings.selectedProfileId = prof.profileId
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prof.displayName)
                                .font(.headline)
                                .foregroundStyle(.white)
                            if let desc = prof.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Text("\(prof.pids.count) capteurs · \(prof.ecus.count) calculateur(s)")
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                        }
                        
                        Spacer()
                        
                        if settings.selectedProfileId == prof.profileId {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une marque ou un profil")
            .navigationTitle("Catalogue de Profils")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
