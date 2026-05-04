import Foundation
import Observation

enum AdapterType: String, CaseIterable, Identifiable {
    case elm327 = "ELM327 (AT Commands)"
    case panda = "Panda (Native CAN UDP)"
    var id: String { rawValue }
}

@MainActor
@Observable
final class AdapterManager {
    static let shared = AdapterManager()
    
    var adapterType: AdapterType {
        get {
            let saved = UserDefaults.standard.string(forKey: "adapter_type") ?? AdapterType.elm327.rawValue
            return AdapterType(rawValue: saved) ?? .elm327
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "adapter_type")
            updateActiveInterface()
        }
    }
    
    // We keep instances alive so they can maintain their connection states if needed
    let elm327 = ELM327()
    let pandaDriver = PandaDriver()
    
    var activeInterface: VehicleInterface {
        switch adapterType {
        case .elm327: return elm327
        case .panda: return pandaDriver
        }
    }
    
    init() {
        // Initial setup
    }
    
    private func updateActiveInterface() {
        // If we switch adapters, we might want to attach/detach them
        if adapterType == .elm327 {
            pandaDriver.detach()
            elm327.attach()
        } else {
            elm327.detach()
            pandaDriver.attach()
        }
    }
}
