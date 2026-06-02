import SwiftUI

struct FuzzerConfigSection: View {
    @Binding var selectedLidPreset: LidPreset
    @Binding var targetEcu: String
    @Binding var startLidHex: String
    @Binding var endLidHex: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration du Fuzzer (KWP2000)")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("Plage d'identifiants (LIDs)")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $selectedLidPreset) {
                    ForEach(LidPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                Text("ECU Cible")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("7E0", text: $targetEcu)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("LID Début (Hex)")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("00", text: $startLidHex)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("LID Fin (Hex)")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("FF", text: $endLidHex)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 8)
    }
}
