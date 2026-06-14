import Foundation

/// Le résultat du traitement d'une trame ISO-TP par le réassembleur.
enum ISOTPResult: Equatable {
    /// Le message est incomplet, en attente de trames consécutives (CF).
    case pending
    /// Le message est entièrement réassemblé avec succès.
    case completed(Data)
    /// Une trame de début de message multiple (First Frame) a été reçue ;
    /// l'émetteur a besoin d'une trame de contrôle de flux (Flow Control).
    case needsFlowControl
    /// Une anomalie de séquence ou de format a été rencontrée.
    case error(String)
}

/// Gère le réassemblage asynchrone des messages multiples ISO 15765-2 (ISO-TP)
/// sur le bus CAN. Supporte l'isolation `@MainActor` et permet de suivre
/// de multiples flux concurrents indexés par l'identifiant CAN.
@MainActor
final class ISOTPReassembler {

    private struct ReassemblyState {
        var totalLength: Int
        var buffer: Data
        var nextSequence: UInt8
    }

    private var states: [UInt32: ReassemblyState] = [:]

    /// Réinitialise l'état d'un flux CAN spécifique ou de l'ensemble du réassembleur.
    func reset(address: UInt32? = nil) {
        if let address {
            states.removeValue(forKey: address)
        } else {
            states.removeAll()
        }
    }

    /// Analyse une trame CAN entrante et met à jour la machine d'état ISO-TP.
    ///
    /// - Parameters:
    ///   - address: L'identifiant CAN de l'émetteur de la trame (ex: rxID comme `7E8`)
    ///   - data: Le bloc de données brutes CAN (généralement 8 octets)
    /// - Returns: Un état `ISOTPResult` décrivant l'action requise ou le résultat final.
    func processFrame(address: UInt32, data: Data) -> ISOTPResult {
        guard !data.isEmpty else {
            return .error("Trame vide")
        }

        let pci = data[0] >> 4

        switch pci {
        case 0: // Single Frame (SF)
            let length = Int(data[0] & 0x0F)
            guard length > 0 else {
                return .error("Longueur Single Frame invalide (0)")
            }
            guard data.count >= length + 1 else {
                return .error("Trame Single Frame trop courte pour la longueur déclarée (\(length))")
            }
            // Réinitialiser tout état en cours pour cette adresse
            states.removeValue(forKey: address)
            let payload = data[1...length]
            return .completed(Data(payload))

        case 1: // First Frame (FF)
            guard data.count >= 2 else {
                return .error("Trame First Frame incomplète (moins de 2 octets)")
            }
            let length = Int((UInt16(data[0] & 0x0F) << 8) | UInt16(data[1]))
            guard length > 7 else {
                return .error("Longueur First Frame invalide (\(length) octets ; devrait être > 7)")
            }

            let payload = data[2...]
            states[address] = ReassemblyState(
                totalLength: length,
                buffer: Data(payload),
                nextSequence: 1
            )
            return .needsFlowControl

        case 2: // Consecutive Frame (CF)
            guard var state = states[address] else {
                // Trame consécutive orpheline, peut se produire si le fuzzer interroge rapidement
                return .error("Trame Consecutive Frame reçue sans First Frame préalable sur l'adresse \(String(format: "0x%X", address))")
            }

            let sequence = data[0] & 0x0F
            guard sequence == state.nextSequence else {
                states.removeValue(forKey: address)
                return .error("Erreur de séquence ISO-TP : trame \(sequence) attendue \(state.nextSequence) sur l'adresse \(String(format: "0x%X", address))")
            }

            let payload = data[1...]
            state.buffer.append(payload)
            state.nextSequence = (state.nextSequence + 1) & 0x0F

            if state.buffer.count >= state.totalLength {
                states.removeValue(forKey: address)
                let completedData = state.buffer.prefix(state.totalLength)
                return .completed(Data(completedData))
            } else {
                states[address] = state
                return .pending
            }

        case 3: // Flow Control (FC)
            // On signale la réception mais pas de réassemblage de données requis en retour
            return .pending

        default:
            return .error("Type de protocole PCI ISO-TP inconnu (\(pci))")
        }
    }
}
