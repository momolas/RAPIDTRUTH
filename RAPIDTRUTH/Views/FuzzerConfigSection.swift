import SwiftUI

struct FuzzerConfigSection: View {
    @Binding var selectedLidPreset: LidPreset
    @Binding var targetEcu: String
    @Binding var startLidHex: String
    @Binding var endLidHex: String
    
    var body: some View {
        Section(header: Text("Configuration du Fuzzer (KWP2000)")) {
            Picker("Plage d'identifiants (LIDs)", selection: $selectedLidPreset) {
                ForEach(LidPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            
            TextField("ECU Cible (ex: 7E0)", text: $targetEcu)
            TextField("LID Début (Hex)", text: $startLidHex)
            TextField("LID Fin (Hex)", text: $endLidHex)
        }
    }
}
