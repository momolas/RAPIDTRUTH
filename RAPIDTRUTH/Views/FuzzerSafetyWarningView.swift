import SwiftUI

struct FuzzerSafetyWarningView: View {
    @Binding var agreedToRisks: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title)
                Text("Avertissement de Sécurité")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            Text("Le fuzzing OBD peut entraîner des comportements inattendus du véhicule, y compris des plantages d'ECU. Ce fuzzer est strictement limité à la LECTURE (Service 22).")
                .font(.subheadline)
            
            Toggle(isOn: $agreedToRisks) {
                Text("J'accepte les risques")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
            }
            .tint(.red)
            .padding(.top, 5)
        }
        .padding(.vertical, 8)
    }
}
