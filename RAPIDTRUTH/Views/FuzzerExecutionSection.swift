import SwiftUI

struct FuzzerExecutionSection: View {
    let fuzzer: OBDFuzzer
    let onStartFuzzing: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if fuzzer.isRunning {
                Button(action: { fuzzer.cancel() }) {
                    Text(fuzzer.currentScanTarget.contains("Scan") ? "Arrêter le Scan" : "Arrêter le Fuzzing")
                        .font(.appButton)
                        .frame(maxWidth: .infinity)
                }
                .glassActionButton(prominent: true)
                .foregroundStyle(.red)
                
                ProgressView(value: fuzzer.currentProgress)
                    .padding(.vertical, 8)
                
            } else {
                Button(action: onStartFuzzing) {
                    Text("Démarrer le Fuzzing")
                        .font(.appButton)
                        .frame(maxWidth: .infinity)
                }
                .glassActionButton(prominent: true)
                .foregroundStyle(.orange)
            }
            
            if let error = fuzzer.actionError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 8)
    }
}
