import Foundation
import Observation
import SwiftVehicleProtocols

public enum AutoDetectionState: Sendable, Equatable {
    case idle
    case readingVIN
    case decodingVehicle(vin: String)
    case downloadingOBDb(make: String, model: String)
    case activated(profileName: String, isLocalBuiltin: Bool, pidsCount: Int)
    case failed(String)
}

/// Service intelligent de détection automatique de véhicule et téléchargement de profils OBDb
@MainActor
@Observable
final class AutoProfileManager {
    static let shared = AutoProfileManager()

    var state: AutoDetectionState = .idle
    var lastDetectedVIN: String?
    var lastDetectedMake: String?
    var lastDetectedModel: String?
    var lastDetectedYear: Int?

    private init() {}

    /// Exécute la détection complète : Lecture VIN -> Décodage Véhicule -> Choix Profil Local vs Téléchargement OBDb
    func autoDetectAndConfigure(interface: VehicleInterface) async {
        state = .readingVIN
        
        do {
            // 1. Lecture du VIN sur le bus CAN / KWP2000
            let vin = try await VINReader.read(interface: interface) ?? (PandaTransport.shared.isSimulationMode ? "VF1JM0G0D12345678" : nil)
            
            guard let vin, !vin.isEmpty else {
                state = .failed("Impossible de lire le numéro VIN du véhicule connecté.")
                return
            }
            
            lastDetectedVIN = vin
            state = .decodingVehicle(vin: vin)

            // 2. Décodage du VIN (Marque, Modèle, Année)
            let decoder = getActiveDecoderService(settings: SettingsStore.shared)
            let result = try await decoder.decode(vin: vin)
            
            let make = result.make.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = result.model.trimmingCharacters(in: .whitespacesAndNewlines)
            let year = result.year
            
            lastDetectedMake = make
            lastDetectedModel = model
            lastDetectedYear = year

            let cleanMake = make.lowercased()
            let cleanModel = model.lowercased()

            // 3. Règle constructeur : Conserver les profils haute précision DDT2000 pour Scenic et Modus
            if cleanMake.contains("renault") || cleanMake.contains("dacia") {
                if cleanModel.contains("scenic") || cleanModel.contains("scénic") {
                    activateLocalProfile(id: "scenic2_obd2", fallbackId: "renault_scenic2_multi_ecu", displayName: "Renault Scénic (DDT2000 Usine)")
                    return
                } else if cleanModel.contains("modus") {
                    activateLocalProfile(id: "modus_obd2", fallbackId: "renault_modus_multi_ecu", displayName: "Renault Modus (DDT2000 Usine)")
                    return
                }
            }

            // 4. Téléchargement ou activation du profil OBDb multi-marques
            state = .downloadingOBDb(make: make, model: model)
            await fetchAndApplyOBDbProfile(make: make, model: model, year: year)

        } catch {
            state = .failed("Erreur de détection : \(error.localizedDescription)")
        }
    }

    // MARK: - Gestion des profils locaux & OBDb

    private func activateLocalProfile(id: String, fallbackId: String, displayName: String) {
        let registry = ProfileRegistry.shared
        let targetId = registry.profile(id: id) != nil ? id : (registry.profile(id: fallbackId) != nil ? fallbackId : id)
        
        SettingsStore.shared.selectedProfileId = targetId
        let count = registry.profile(id: targetId)?.pids.count ?? 0
        state = .activated(profileName: displayName, isLocalBuiltin: true, pidsCount: count)
    }

    private func fetchAndApplyOBDbProfile(make: String, model: String, year: Int?) async {
        let registry = ProfileRegistry.shared
        let candidateRepoName = obdbRepoName(make: make, model: model)
        let profileSlug = candidateRepoName.lowercased().replacingOccurrences(of: "-", with: "_")

        // Si le profil est déjà présent localement dans ProfileRegistry
        if let existing = registry.profile(id: profileSlug) {
            SettingsStore.shared.selectedProfileId = existing.profileId
            state = .activated(profileName: existing.displayName, isLocalBuiltin: false, pidsCount: existing.pids.count)
            return
        }

        // Téléchargement depuis GitHub OBDb
        let urlsToTry = [
            "https://raw.githubusercontent.com/OBDb/\(candidateRepoName)/main/signalsets/v3/default.json",
            "https://raw.githubusercontent.com/OBDb/\(candidateRepoName)/master/signalsets/v3/default.json",
            "https://raw.githubusercontent.com/OBDb/\(make)-\(model)/main/signalsets/v3/default.json"
        ]

        var downloadedData: Data? = nil

        for urlString in urlsToTry {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, data.count > 50 {
                    downloadedData = data
                    break
                }
            } catch {
                continue
            }
        }

        if let data = downloadedData {
            do {
                let vehicleTitle = "\(make) \(model)" + (year.map { " (\($0))" } ?? "")
                let unifiedProfile = try OBDbImporter.convert(
                    jsonData: data,
                    vehicleName: vehicleTitle,
                    profileId: profileSlug
                )

                // Enregistrement dans Documents/profiles/
                try AppStorage.shared.ensureDir("profiles")
                let targetURL = AppStorage.shared.url(for: "profiles/\(profileSlug).json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let encodedData = try encoder.encode(unifiedProfile)
                try encodedData.write(to: targetURL)

                // Rechargement du registre
                registry.reload()
                SettingsStore.shared.selectedProfileId = profileSlug

                let pidsCount = registry.profile(id: profileSlug)?.pids.count ?? unifiedProfile.variants.first?.downloads.reduce(0, { $0 + $1.outputParams.count }) ?? 0
                state = .activated(profileName: vehicleTitle, isLocalBuiltin: false, pidsCount: pidsCount)
                return
            } catch {
                NSLog("[AutoProfileManager] Échec de conversion OBDb: \(error)")
            }
        }

        // Si non trouvé sur OBDb, repli sur le profil générique OBD2
        SettingsStore.shared.selectedProfileId = "generic_obd2"
        let count = registry.profile(id: "generic_obd2")?.pids.count ?? 30
        state = .activated(profileName: "\(make) \(model) (Générique OBD2)", isLocalBuiltin: true, pidsCount: count)
    }

    /// Génère le nom de dépôt standard selon la nomenclature OBDb (ex: "BMW-3-Series", "Tesla-Model-3")
    private func obdbRepoName(make: String, model: String) -> String {
        let cleanMake = make.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .capitalized
        
        // Mappings spécifiques connus dans OBDb
        let key = "\(cleanMake.lowercased())_\(cleanModel.lowercased())"
        switch key {
        case "bmw_3", "bmw_serie 3", "bmw_series 3", "bmw_3-series":
            return "BMW-3-Series"
        case "tesla_model 3", "tesla_model-3":
            return "Tesla-Model-3"
        case "tesla_model y", "tesla_model-y":
            return "Tesla-Model-Y"
        case "toyota_yaris":
            return "Toyota-Yaris"
        case "toyota_corolla":
            return "Toyota-Corolla"
        case "volkswagen_golf", "vw_golf":
            return "Volkswagen-Golf"
        case "audi_a3":
            return "Audi-A3"
        case "renault_clio":
            return "Renault-Clio"
        case "renault_zoe":
            return "Renault-ZOE"
        case "renault_megane", "renault_mégane":
            return "Renault-Megane"
        default:
            return "\(cleanMake)-\(cleanModel)"
        }
    }
}
