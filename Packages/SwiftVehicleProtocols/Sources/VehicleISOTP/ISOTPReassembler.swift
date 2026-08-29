import Foundation
import VehicleCore

public enum ISOTPResult: Equatable, Sendable {
    case pending
    case completed(Data)
    case needsFlowControl
    case error(String)
}

public actor ISOTPReassembler {
    private struct ReassemblyState: Sendable {
        var totalLength: Int
        var buffer: Data
        var nextSequence: UInt8
        var createdAt: ContinuousClock.Instant = .now
    }

    private var states: [UInt32: ReassemblyState] = [:]

    public init() {}

    public func reset(address: UInt32? = nil) {
        if let address {
            states.removeValue(forKey: address)
        } else {
            states.removeAll()
        }
    }

    private func purgeStaleStates() {
        let now = ContinuousClock.Instant.now
        states = states.filter { _, state in
            now.duration(to: state.createdAt) > .seconds(-1.5)
        }
    }

    public func processFrame(address: UInt32, data: Data) -> ISOTPResult {
        purgeStaleStates()
        
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
            states.removeValue(forKey: address)
            let payload = data[1...length]
            return .completed(Data(payload))

        case 1: // First Frame (FF)
            guard data.count >= 2 else {
                return .error("Trame First Frame incomplète")
            }
            let length = Int((UInt16(data[0] & 0x0F) << 8) | UInt16(data[1]))
            guard length > 7 else {
                return .error("Longueur First Frame invalide (\(length))")
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
                return .error("Trame Consecutive Frame orpheline sur 0x\(String(format: "%X", address))")
            }

            let sequence = data[0] & 0x0F
            guard sequence == state.nextSequence else {
                states.removeValue(forKey: address)
                return .error("Erreur séquence ISO-TP : reçu \(sequence), attendu \(state.nextSequence)")
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
            return .pending

        default:
            return .error("Type de trame ISO-TP non supporté: \(pci)")
        }
    }
}
