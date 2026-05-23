import SwiftUI

struct FuzzerConfigSection: View {
    @Binding var selectedDidPreset: DidPreset
    @Binding var targetEcu: String
    @Binding var startDidHex: String
    @Binding var endDidHex: String
    
    var body: some View {
        Section(header: Text("Configuration du Fuzzer")) {
            Picker("Gamme de DIDs", selection: $selectedDidPreset) {
                ForEach(DidPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            
            TextField("ECU Cible (ex: 7E0)", text: $targetEcu)
            TextField("DID Début (Hex)", text: $startDidHex)
            TextField("DID Fin (Hex)", text: $endDidHex)
        }
    }
}
