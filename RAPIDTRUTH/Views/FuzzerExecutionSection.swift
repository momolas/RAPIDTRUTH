import SwiftUI

struct FuzzerExecutionSection: View {
    let fuzzer: OBDFuzzer
    let onStartFuzzing: () -> Void
    
    var body: some View {
        Section {
            if fuzzer.isRunning {
                Button(fuzzer.currentScanTarget.contains("Scan") ? "Arrêter le Scan" : "Arrêter le Fuzzing", action: { fuzzer.cancel() })
                    .glassActionButton(prominent: true)
                    .buttonBorderShape(.roundedRectangle)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                
                ProgressView(value: fuzzer.currentProgress)
                    .padding(.vertical, 8)
                
            } else {
                Button("Démarrer le Fuzzing", action: onStartFuzzing)
                    .glassActionButton(prominent: true)
                    .buttonBorderShape(.roundedRectangle)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
            }
            
            if let error = fuzzer.actionError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }
}
