import Foundation
import SwiftVehicleProtocols

/// Convertit un `Profile` hérité de RAPIDTRUTH vers un `UnifiedECUProfile` déclaratif
enum UnifiedProfileConverter {

    /// Convertit un `Profile` classique en `UnifiedECUProfile` standardisé
    static func convert(legacyProfile: Profile) -> UnifiedECUProfile {
        var connections: [UnifiedConnection] = []

        // 1. Convertir les calculateurs en connexions réseau
        for (ecuKey, ecuDef) in legacyProfile.ecus {
            let tx = ecuDef.requestHeader.hasPrefix("0x") ? ecuDef.requestHeader : "0x\(ecuDef.requestHeader)"
            let rx = ecuDef.responseHeader.hasPrefix("0x") ? ecuDef.responseHeader : "0x\(ecuDef.responseHeader)"
            connections.append(
                UnifiedConnection(
                    busType: "CAN",
                    baudrate: 500000,
                    txId: tx,
                    rxId: rx,
                    protocolName: "ISO15765-2"
                )
            )
        }

        if connections.isEmpty {
            connections.append(
                UnifiedConnection(
                    busType: "CAN",
                    baudrate: 500000,
                    txId: "0x7E0",
                    rxId: "0x7E8",
                    protocolName: "ISO15765-2"
                )
            )
        }

        // 2. Regrouper les PIDs par ECU et par commande (Mode + PID)
        var servicesByPayload: [String: [PidDef]] = [:]
        for pid in legacyProfile.pids {
            let payload = "\(pid.mode)\(pid.pid)".uppercased()
            servicesByPayload[payload, default: []].append(pid)
        }

        var downloadServices: [UnifiedService] = []
        var actuationServices: [UnifiedService] = []
        var functionServices: [UnifiedService] = []

        for (payload, pids) in servicesByPayload.sorted(by: { $0.key < $1.key }) {
            var outputParams: [UnifiedParameter] = []

            for pid in pids {
                let (startBit, lengthBits, format) = parseFormula(pid.formula)

                let param = UnifiedParameter(
                    name: pid.displayName.isEmpty ? pid.id : pid.displayName,
                    unit: pid.unit,
                    startBit: startBit,
                    lengthBits: lengthBits,
                    byteOrder: .bigEndian,
                    dataFormat: format,
                    validBounds: (pid.min != nil && pid.max != nil) ? UnifiedLimit(lower: pid.min ?? 0, upper: pid.max ?? 0) : nil
                )
                outputParams.append(param)
            }

            let service = UnifiedService(
                name: pids.first?.displayName ?? "Service_\(payload)",
                description: "Service pour \(payload) (\(pids.count) signaux)",
                payloadHex: payload,
                inputParams: [],
                outputParams: outputParams
            )

            if payload.hasPrefix("30") || payload.hasPrefix("2F") {
                actuationServices.append(service)
            } else if payload.hasPrefix("11") || payload.hasPrefix("31") {
                functionServices.append(service)
            } else {
                downloadServices.append(service)
            }
        }

        let variant = UnifiedVariant(
            name: "\(legacyProfile.profileId)_Variant1",
            description: legacyProfile.description ?? "Variante par défaut",
            patterns: [
                UnifiedPattern(
                    vendor: legacyProfile.vehicleMatch?.make ?? "Generic",
                    vendorId: legacyProfile.profileVersion
                )
            ],
            errors: [],
            downloads: downloadServices,
            actuations: actuationServices,
            adjustments: [],
            functions: functionServices
        )

        return UnifiedECUProfile(
            name: legacyProfile.displayName,
            description: legacyProfile.description ?? "",
            connections: connections,
            variants: [variant]
        )
    }

    /// Analyse heuristique d'une formule textuelle classique pour extraire startBit, lengthBits et DataFormat
    private static func parseFormula(_ formula: String) -> (startBit: Int, lengthBits: Int, format: UnifiedDataFormat) {
        let cleaned = formula.replacingOccurrences(of: " ", with: "")

        // Extraction des lettres majuscules présentes dans la formule
        let letters = cleaned.filter { $0 >= "A" && $0 <= "Z" }
        guard let firstLetter = letters.first else {
            return (0, 8, .identical)
        }

        let firstIndex = Int(firstLetter.asciiValue! - Character("A").asciiValue!)
        let isTwoBytes = letters.count >= 2 && letters.contains(Character(UnicodeScalar(firstLetter.asciiValue! + 1)))

        let startBit = firstIndex * 8
        let lengthBits = isTwoBytes ? 16 : 8

        // Formules courantes
        // 1. A - 40
        if cleaned == "A-40" || cleaned == "(A-40)" {
            return (startBit, lengthBits, .linear(multiplier: 1.0, offset: -40.0))
        }

        // 2. (A*256+B)/4 -> multiplier = 0.25
        if cleaned.contains("256") && cleaned.contains("/4") {
            return (startBit, lengthBits, .linear(multiplier: 0.25, offset: 0.0))
        }

        // 3. Multiplicateur et offset explicites (ex: "((P*0.375)-23.625)")
        if let multMatch = extractMultiplierAndOffset(from: cleaned) {
            return (startBit, lengthBits, .linear(multiplier: multMatch.mult, offset: multMatch.offset))
        }

        return (startBit, lengthBits, .identical)
    }

    private static func extractMultiplierAndOffset(from formula: String) -> (mult: Double, offset: Double)? {
        // Recherche de patterns type (X*mult) ou ((X*mult)+offset) ou ((X*mult)-offset)
        let multPattern = #"\*([0-9.]+)"#
        var mult: Double = 1.0
        var offset: Double = 0.0

        if let multRange = formula.range(of: multPattern, options: .regularExpression) {
            let multStr = String(formula[multRange]).replacingOccurrences(of: "*", with: "")
            if let parsedMult = Double(multStr) {
                mult = parsedMult
            }
        }

        if let plusRange = formula.range(of: #"\+([0-9.]+)"#, options: .regularExpression) {
            let offsetStr = String(formula[plusRange]).replacingOccurrences(of: "+", with: "")
            if let parsedOffset = Double(offsetStr) {
                offset = parsedOffset
            }
        } else if let minusRange = formula.range(of: #"-([0-9.]+)"#, options: .regularExpression) {
            let offsetStr = String(formula[minusRange]).replacingOccurrences(of: "-", with: "")
            if let parsedOffset = Double(offsetStr) {
                offset = -parsedOffset
            }
        }

        return (mult, offset)
    }

    // MARK: - Conversion Inverse (UnifiedECUProfile -> Legacy Profile)

    /// Convertit un `UnifiedECUProfile` vers le format `Profile` hérité pour rétrocompatibilité UI
    static func toLegacyProfile(unified: UnifiedECUProfile, id: String? = nil) -> Profile {
        let profileId = id ?? unified.name.lowercased().replacingOccurrences(of: " ", with: "_")
        var ecus: [String: EcuDef] = [:]

        for (index, conn) in unified.connections.enumerated() {
            let ecuKey = index == 0 ? "main" : "ecu_\(index)"
            let tx = conn.txId.replacingOccurrences(of: "0x", with: "").replacingOccurrences(of: "0X", with: "")
            let rx = conn.rxId.replacingOccurrences(of: "0x", with: "").replacingOccurrences(of: "0X", with: "")
            ecus[ecuKey] = EcuDef(requestHeader: tx, responseHeader: rx)
        }

        if ecus.isEmpty {
            ecus["main"] = EcuDef(requestHeader: "7E0", responseHeader: "7E8")
        }

        var pids: [PidDef] = []
        let primaryEcuKey = ecus.keys.first ?? "main"

        if let variant = unified.variants.first {
            for service in variant.downloads {
                let payload = service.payloadHex.replacingOccurrences(of: " ", with: "").uppercased()
                let mode: String
                let pid: String

                if payload.count >= 4 {
                    mode = String(payload.prefix(2))
                    pid = String(payload.suffix(payload.count - 2))
                } else if payload.count == 2 {
                    mode = payload
                    pid = ""
                } else {
                    mode = "21"
                    pid = payload
                }

                for param in service.outputParams {
                    let formula = buildFormulaFromParam(param)
                    let cat: PidCategory = pid.hasPrefix("0C") || param.name.localizedCaseInsensitiveContains("rpm") ? .rpm :
                                           (param.name.localizedCaseInsensitiveContains("vitesse") || param.name.localizedCaseInsensitiveContains("speed") ? .speed :
                                           (param.name.localizedCaseInsensitiveContains("temp") ? .temperature : .engine))

                    let pidDef = PidDef(
                        id: "\(profileId)_\(param.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                        displayName: param.name,
                        ecu: primaryEcuKey,
                        mode: mode,
                        pid: pid,
                        unit: param.unit,
                        formula: formula,
                        category: cat,
                        min: param.validBounds?.lower,
                        max: param.validBounds?.upper
                    )
                    pids.append(pidDef)
                }
            }
        }

        let make = unified.variants.first?.patterns.first?.vendor ?? "Renault"
        let vehicleMatch = VehicleMatch(
            make: make,
            models: [unified.name],
            yearMin: 2000,
            yearMax: 2026
        )

        return Profile(
            profileId: profileId,
            profileVersion: "2.0.0",
            displayName: unified.name,
            description: unified.description,
            vehicleMatch: vehicleMatch,
            ecus: ecus,
            pids: pids,
            sources: ["Unified OVD Specification"],
            validatedAgainst: nil
        )
    }

    private static func buildFormulaFromParam(_ param: UnifiedParameter) -> String {
        let byteIndex = param.startBit / 8
        let letterA = Character("A").asciiValue!
        let letter = String(UnicodeScalar(letterA + UInt8(min(byteIndex, 25))))

        switch param.dataFormat {
        case .linear(let multiplier, let offset):
            if param.lengthBits == 16 {
                let nextLetter = String(UnicodeScalar(letterA + UInt8(min(byteIndex + 1, 25))))
                if offset != 0.0 {
                    return "((\(letter)*256+\(nextLetter))*\(multiplier)+\(offset))"
                } else {
                    return "((\(letter)*256+\(nextLetter))*\(multiplier))"
                }
            } else {
                if offset != 0.0 {
                    return "((\(letter)*\(multiplier))+\(offset))"
                } else {
                    return "(\(letter)*\(multiplier))"
                }
            }
        case .identical:
            if param.lengthBits == 16 {
                let nextLetter = String(UnicodeScalar(letterA + UInt8(min(byteIndex + 1, 25))))
                return "(\(letter)*256+\(nextLetter))"
            }
            return letter
        default:
            return letter
        }
    }
}
