import Foundation

/// OBD2Analyzer fournit des fonctions utilitaires pour décoder, annoter et traduire
/// les trames de diagnostic automobile OBD-II et UDS (ISO 14229).
/// Inspiré des capacités avancées d'analyse d'ELMterm.
final class OBD2Analyzer {

    // MARK: - Tables de Décryptage UDS

    private static let udsModeDescriptions: [UInt8: String] = [
        0x10: "Diagnostic Session Control",
        0x11: "ECU Reset",
        0x14: "Clear Diagnostic Information",
        0x19: "Read DTC Information",
        0x22: "Read Data By Identifier",
        0x23: "Read Memory By Address",
        0x27: "Security Access",
        0x28: "Communication Control",
        0x2E: "Write Data By Identifier",
        0x31: "Routine Control",
        0x34: "Request Download",
        0x35: "Request Upload",
        0x36: "Transfer Data",
        0x37: "Request Transfer Exit",
        0x3E: "Tester Present",
        0x85: "Control DTC Setting"
    ]

    private static let obd2ModeDescriptions: [UInt8: String] = [
        0x01: "Show Current Data",
        0x02: "Show Freeze Frame Data",
        0x03: "Show Stored DTCs",
        0x04: "Clear DTCs",
        0x09: "Request Vehicle Information"
    ]

    private static let udsSubFunctions: [UInt8: [UInt8: String]] = [
        0x10: [
            0x01: "Default Session",
            0x02: "Programming Session",
            0x03: "Extended Diagnostic Session"
        ],
        0x11: [
            0x01: "Hard Reset",
            0x02: "Key Off/On Reset",
            0x03: "Soft Reset"
        ],
        0x19: [
            0x01: "Report number of DTC by status mask",
            0x02: "Report DTC by status mask",
            0x03: "Report DTC snapshot identification",
            0x04: "Report DTC snapshot record by DTC number",
            0x06: "Report DTC extended data record by DTC number",
            0x0A: "Report supported DTCs"
        ],
        0x28: [
            0x00: "Enable Rx and Tx",
            0x01: "Enable Rx, disable Tx",
            0x02: "Disable Rx, enable Tx",
            0x03: "Disable Rx and Tx"
        ],
        0x31: [
            0x01: "Start Routine",
            0x02: "Stop Routine",
            0x03: "Request Routine Results"
        ],
        0x3E: [
            0x00: "Zero Sub-function"
        ],
        0x85: [
            0x01: "On",
            0x02: "Off"
        ]
    ]

    private static let didDescriptions: [UInt16: String] = [
        0xF180: "Boot Software Identification",
        0xF186: "Active Diagnostic Session",
        0xF187: "Spare Part Number",
        0xF188: "ECU Software Number",
        0xF189: "ECU Software Version Number",
        0xF18A: "System Supplier Identifier",
        0xF18B: "ECU Manufacturing Date",
        0xF18C: "ECU Serial Number",
        0xF190: "VIN",
        0xF191: "ECU Hardware Number",
        0xF192: "System Supplier ECU Hardware Number",
        0xF193: "System Supplier ECU Hardware Version",
        0xF194: "System Supplier ECU Software Number",
        0xF195: "System supplier ECU software version",
        0xF197: "System name or engine type",
        0xF199: "Programming Date",
        0xF1A0: "Diagnostic Version"
    ]

    private static let nrcDescriptions: [UInt8: String] = [
        0x10: "General reject",
        0x11: "Service not supported",
        0x12: "Sub-function not supported",
        0x13: "Incorrect message length or invalid format",
        0x14: "Response too long",
        0x21: "Busy repeat request",
        0x22: "Conditions not correct",
        0x24: "Request sequence error",
        0x25: "No response from sub-bus component",
        0x26: "Failure prevents execution of requested action",
        0x31: "Request out of range",
        0x33: "Security access denied",
        0x35: "Invalid key",
        0x36: "Exceeded number of attempts",
        0x37: "Required time delay not expired",
        0x70: "Upload/download not accepted",
        0x71: "Transfer data suspended",
        0x72: "General programming failure",
        0x73: "Wrong block sequence counter",
        0x78: "Request correctly received - response pending",
        0x7E: "Sub-function not supported in active session",
        0x7F: "Service not supported in active session"
    ]

    // MARK: - Analyseurs et Formateurs Statiques

    /// Décrit une requête de diagnostic à partir de son format hexadécimal (ex: "22F190" -> "Read Data By Identifier · VIN (F190)")
    static func describeRequest(_ hex: String) -> String {
        guard let bytes = HexParsing.bytes(hex), let mode = bytes.first else {
            return "Commande brute: \(hex)"
        }

        let isOBD2 = mode <= 0x0F
        let modeName = isOBD2 ? obd2ModeDescriptions[mode] : udsModeDescriptions[mode]
        let fallback = isOBD2 ? "OBD-II Mode \(String(format: "%02X", mode))" : "UDS Service \(String(format: "%02X", mode))"
        let displayMode = modeName ?? fallback

        var details: [String] = [displayMode]

        if isOBD2 {
            if bytes.count > 1 {
                let pid = bytes[1]
                let pidHex = String(format: "%02X", pid)
                if let standardPid = StandardPids.get(pidHex) {
                    details.append("\(standardPid.displayName) (PID \(pidHex))")
                } else {
                    details.append("PID \(pidHex)")
                }
            }
        } else {
            // UDS Sub-parameters / DIDs
            switch mode {
            case 0x22, 0x2E: // Read / Write by Identifier
                if bytes.count >= 3 {
                    let did = UInt16(bytes[1]) << 8 | UInt16(bytes[2])
                    let didHex = String(format: "%04X", did)
                    if let name = didDescriptions[did] {
                        details.append("\(name) (DID \(didHex))")
                    } else {
                        details.append("DID \(didHex)")
                    }
                }
            case 0x27: // Security Access
                if bytes.count >= 2 {
                    let subFn = bytes[1] & 0x7F
                    let step = subFn.isMultiple(of: 2) ? "Send Key" : "Request Seed"
                    let level = (subFn + 1) / 2
                    details.append("\(step) (Niveau \(level))")
                }
            default:
                if bytes.count >= 2, let subs = udsSubFunctions[mode], let subName = subs[bytes[1]] {
                    details.append(subName)
                }
            }
        }

        return details.joined(separator: " · ")
    }

    /// Tente de décoder et formater intelligemment le résultat de diagnostic
    static func decodeResponse(request: String, response: String) -> String? {
        guard let reqBytes = HexParsing.bytes(request), let reqMode = reqBytes.first else {
            return nil
        }
        guard let respBytes = HexParsing.bytes(response) else {
            return nil
        }

        // 1. Détection des trames NRC (Negative Response) : Format "7F [Service] [Code NRC]"
        if respBytes.first == 0x7F {
            guard respBytes.count >= 3 else {
                return "❌ Erreur de réponse négative incomplète"
            }
            let service = respBytes[1]
            let nrc = respBytes[2]
            let serviceName = udsModeDescriptions[service] ?? String(format: "%02X", service)
            let nrcName = nrcDescriptions[nrc] ?? "Code NRC \(String(format: "%02X", nrc))"
            return "❌ Erreur sur Service \(serviceName) : \(nrcName)"
        }

        // 2. Décryptage selon le mode d'envoi
        let isOBD2 = reqMode <= 0x0F

        if isOBD2 {
            // OBD-II Response positive : reqMode + 0x40
            let expectedPositive = reqMode + 0x40
            guard respBytes.first == expectedPositive else { return nil }

            if reqBytes.count > 1, respBytes.count > 2 {
                let pidHex = String(format: "%02X", reqBytes[1])
                // Si la trame est du texte (ex: Mode 09 PID 02 -> VIN)
                if reqMode == 0x09 && reqBytes[1] == 0x02 {
                    let payload = Array(respBytes.dropFirst(2))
                    if let text = asciiDecode(HexParsing.hex(payload)) {
                        return "VIN: \(text)"
                    }
                }
                
                // Formater selon la base de PIDs
                if let standard = StandardPids.get(pidHex), standard.formula != "0" {
                    // Tenter un calcul à la volée pour l'affichage de base
                    let payload = Array(respBytes.dropFirst(2))
                    if let value = applyFormula(standard.formula, bytes: payload) {
                        return "\(value) \(standard.unit)"
                    }
                }
            }
        } else {
            // UDS Response positive : reqMode + 0x40
            let expectedPositive = reqMode + 0x40
            guard respBytes.first == expectedPositive else { return nil }

            switch reqMode {
            case 0x22: // Read Data By Identifier
                if reqBytes.count >= 3, respBytes.count > 3 {
                    let did = UInt16(reqBytes[1]) << 8 | UInt16(reqBytes[2])
                    let payload = Array(respBytes.dropFirst(3))
                    let payloadHex = HexParsing.hex(payload)
                    
                    // Si c'est le VIN ou des références textuelles connues
                    if did == 0xF190 || did == 0xF187 || did == 0xF18C || did == 0xF188 || did == 0xF197 {
                        if let text = asciiDecode(payloadHex) {
                            return text
                        }
                    }
                    
                    // Renvoyer l'hexdump si c'est binaire
                    return "Hex: " + payload.map { String(format: "%02X", $0) }.joined(separator: " ")
                }
            case 0x27: // Security Access
                if reqBytes.count >= 2, respBytes.count >= 2 {
                    let subFn = respBytes[1]
                    if !subFn.isMultiple(of: 2) {
                        // Seed reçue
                        let seed = Array(respBytes.dropFirst(2))
                        return "Seed reçue: " + seed.map { String(format: "%02X", $0) }.joined(separator: " ")
                    } else {
                        return "🔓 Clé validée, ECU déverrouillé"
                    }
                }
            default:
                break
            }
        }

        return nil
    }

    /// Décrit le nom en clair d'un DID UDS
    static func describeDID(_ didHex: String) -> String? {
        guard let bytes = HexParsing.bytes(didHex), bytes.count == 2 else { return nil }
        let did = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        return didDescriptions[did]
    }

    /// Décode une trame hexadécimale brute en chaîne ASCII imprimable, en filtrant les caractères non imprimables
    static func asciiDecode(_ hex: String) -> String? {
        guard let bytes = HexParsing.bytes(hex) else { return nil }
        var chars: [Character] = []
        for b in bytes {
            // Filtrer les caractères ASCII imprimables standard (32 à 126)
            if b >= 32 && b <= 126 {
                chars.append(Character(UnicodeScalar(b)))
            } else if b == 0 || b == 0xFF {
                // Ignorer les zéros de remplissage ou les FF
                continue
            } else {
                // Remplacer les autres caractères par un point pour la lisibilité
                chars.append(".")
            }
        }
        let cleaned = String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Formules Mathématiques Internes

    private static func applyFormula(_ formula: String, bytes: [UInt8]) -> String? {
        guard !bytes.isEmpty else { return nil }
        let a = Double(bytes[0])
        let b = bytes.count > 1 ? Double(bytes[1]) : 0.0
        let c = bytes.count > 2 ? Double(bytes[2]) : 0.0
        let d = bytes.count > 3 ? Double(bytes[3]) : 0.0

        // Parse simpliste de formules standardisées
        if formula == "A-40" {
            return String(format: "%.0f", a - 40.0)
        } else if formula == "(A*256+B)/4" || formula == "(A*256+B)*100/255" || formula == "(A*256+B)/100" || formula == "(A*256+B)/10-40" {
            // Formules doubles
            let comb = a * 256.0 + b
            if formula == "(A*256+B)/4" {
                return String(format: "%.0f", comb / 4.0)
            } else if formula == "(A*256+B)*100/255" {
                return String(format: "%.1f", comb * 100.0 / 255.0)
            } else if formula == "(A*256+B)/100" {
                return String(format: "%.2f", comb / 100.0)
            } else if formula == "(A*256+B)/10-40" {
                return String(format: "%.1f", comb / 10.0 - 40.0)
            }
        } else if formula == "A*100/255" {
            return String(format: "%.1f", a * 100.0 / 255.0)
        } else if formula == "A" {
            return String(format: "%.0f", a)
        } else if formula == "A*256+B" {
            return String(format: "%.0f", a * 256.0 + b)
        } else if formula == "(A*16777216+B*65536+C*256+D)/10" {
            let odometer = (a * 16777216.0 + b * 65536.0 + c * 256.0 + d) / 10.0
            return String(format: "%.1f", odometer)
        }

        return nil
    }
}
