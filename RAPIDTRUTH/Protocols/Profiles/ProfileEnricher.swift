import Foundation

struct ProfileEnricher {
    
    /// Estime l'identifiant de réponse CAN correspondant à l'identifiant de requête.
    /// Pour les identifiants OBD standard (0x7E0 - 0x7E7), la réponse est +8 (0x7E8 - 0x7EF).
    /// Pour les autres identifiants (ex: Renault 740, 745), la réponse est +0x20 (760, 765).
    static func estimateResponseHeader(requestHeader: String) -> String {
        let clean = requestHeader.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let val = Int(clean, radix: 16) else { return requestHeader }
        if val >= 0x7E0 && val <= 0x7E7 {
            return String(format: "%03X", val + 8)
        } else {
            return String(format: "%03X", val + 0x20)
        }
    }
    
    /// Recherche ou génère un nom de clé d'ECU standard pour une adresse de requête donnée.
    static func ecuKeyName(for requestHeader: String) -> String {
        let clean = requestHeader.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch clean {
        case "7E0": return "injection"
        case "740": return "abs"
        case "743": return "tdb"
        case "745": return "uch"
        case "744": return "clim"
        case "742": return "dae"
        case "751": return "upc"
        case "74A": return "airbag"
        case "74D": return "fpa"
        default: return "ecu_\(clean.lowercased())"
        }
    }
    
    /// Enrichit un profil existant avec les calculateurs et les LIDs découverts.
    static func enrich(
        profile: Profile,
        discoveredECUs: [String],
        supportedLIDs: [String: [String]]
    ) -> Profile {
        var updatedEcus = profile.ecus
        
        // 1. Ajouter les nouveaux calculateurs découverts lors du scan réseau
        for ecu in discoveredECUs {
            let key = ecuKeyName(for: ecu)
            if updatedEcus[key] == nil {
                let resp = estimateResponseHeader(requestHeader: ecu)
                updatedEcus[key] = EcuDef(requestHeader: ecu, responseHeader: resp)
            }
        }
        
        // S'assurer également que tous les calculateurs présents dans les résultats de LIDs sont définis dans ecus
        for (ecuAddr, _) in supportedLIDs {
            let key = ecuKeyName(for: ecuAddr)
            if updatedEcus[key] == nil {
                let resp = estimateResponseHeader(requestHeader: ecuAddr)
                updatedEcus[key] = EcuDef(requestHeader: ecuAddr, responseHeader: resp)
            }
        }
        
        // 2. Préparer la liste des PIDs mise à jour
        var updatedPids = profile.pids
        
        // Construire un ensemble pour vérifier rapidement les doublons existants
        // Clé de doublon : "\(ecu_key)_\(mode)_\(pid)"
        var existingKeys = Set<String>()
        for pidDef in updatedPids {
            let uniqueKey = "\(pidDef.ecu)_\(pidDef.mode)_\(pidDef.pid.uppercased())"
            existingKeys.insert(uniqueKey)
        }
        
        // 3. Ajouter les LIDs découverts par le fuzzer KWP2000
        for (ecuAddr, lids) in supportedLIDs {
            let ecuKey = ecuKeyName(for: ecuAddr)
            
            for lid in lids {
                let lidHex = lid.uppercased()
                let uniqueKey = "\(ecuKey)_21_\(lidHex)"
                
                // Ajouter seulement si ce PID (ECU/Mode/PID) n'est pas déjà référencé
                if !existingKeys.contains(uniqueKey) {
                    let displayName = OBD2Analyzer.describeLID(lidHex) ?? "LID \(lidHex) (Fuzz)"
                    let pidId = "\(ecuKey)_fuzzed_lid_\(lidHex.lowercased())"
                    
                    let newPid = PidDef(
                        id: pidId,
                        displayName: displayName,
                        ecu: ecuKey,
                        mode: "21",
                        pid: lidHex,
                        unit: "",
                        formula: "hex", // La formule "hex" permet d'afficher la réponse brute sous forme d'octets hexadécimaux
                        category: .diagnostics,
                        min: nil,
                        max: nil
                    )
                    updatedPids.append(newPid)
                    existingKeys.insert(uniqueKey)
                }
            }
        }
        
        // Calculer la nouvelle version du profil
        let currentVersion = profile.profileVersion
        var newVersion = currentVersion
        if let doubleVer = Double(currentVersion) {
            newVersion = String(format: "%.2f", doubleVer + 0.01)
        } else {
            newVersion = currentVersion + "+fuzzed"
        }
        
        return Profile(
            profileId: profile.profileId,
            profileVersion: newVersion,
            displayName: profile.displayName,
            description: profile.description,
            vehicleMatch: profile.vehicleMatch,
            ecus: updatedEcus,
            pids: updatedPids,
            sources: profile.sources,
            validatedAgainst: profile.validatedAgainst
        )
    }
}
