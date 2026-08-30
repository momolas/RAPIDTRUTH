import SwiftUI
import SwiftVehicleProtocols

struct FuzzerSignalCorrelationSection: View {
    let interface: VehicleInterface
    @Bindable var fuzzer: OBDFuzzer
    @Binding var targetEcu: String
    @Binding var targetLidHex: String
    
    var onStartCorrelation: () -> Void
    var onStopCorrelation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration du LID")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("ECU Cible (Hex)")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("7E0", text: $targetEcu)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(.monoSmall)
                    .frame(width: 100)
                    .foregroundStyle(.white)
            }
            HStack {
                Text("LID Cible (Hex)")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("01", text: $targetLidHex)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(.monoSmall)
                    .frame(width: 100)
                    .foregroundStyle(.white)
            }
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Analyse de Corrélation")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            
            if fuzzer.isRunning {
                Button(action: onStopCorrelation) {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Arrêter l'Analyse")
                        Spacer()
                    }
                    .font(.appButton)
                }
                .glassActionButton(prominent: true)
                .foregroundStyle(.red)
            } else {
                Button(action: onStartCorrelation) {
                    Text("Démarrer l'Analyse")
                        .font(.appButton)
                        .frame(maxWidth: .infinity)
                }
                .glassActionButton(prominent: true)
            }
            
            if fuzzer.analyzedFrameCount > 0 {
                HStack {
                    Text("Trames analysées")
                        .font(.captionText)
                    Spacer()
                    Text("\(fuzzer.analyzedFrameCount)")
                        .font(.valueNumber)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Rapports de Pearson (Temps Réel)")
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            
            if fuzzer.correlations.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("En attente d'acquisition...")
                        .font(.statusText)
                        .foregroundStyle(.secondary)
                    Text("Accélérez ou faites varier l'état pour corréler les signaux.")
                        .font(.captionTiny)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(fuzzer.correlations) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tranche \(result.sliceName)")
                                .font(.monoSmall)
                                .bold()
                                .foregroundStyle(.white)
                            Spacer()
                            Text(result.classification)
                                .font(.captionTiny)
                                .bold()
                                .foregroundStyle(colorForClassification(result.classification))
                        }
                        
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(colorForCoefficient(result.coefficient))
                                    .frame(height: 6)
                                    .visualEffect { content, _ in
                                        content.scaleEffect(x: CGFloat(abs(result.coefficient)), y: 1.0, anchor: .leading)
                                    }
                            }
                            .frame(height: 6)
                            
                            Text(abs(result.coefficient * 100), format: .number.precision(.fractionLength(1)))
                                .font(.valueNumber)
                                .foregroundStyle(.secondary)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.02))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    }
                }
            }
        }
    }
    
    private func colorForClassification(_ classification: String) -> Color {
        if classification.contains("FORT") {
            return Color.green
        } else if classification.contains("potentiel") {
            return Color.appAccent
        }
        return Color.secondary
    }
    
    private func colorForCoefficient(_ coef: Double) -> Color {
        if coef >= 0.75 {
            return Color.green
        } else if coef <= -0.75 {
            return Color.orange
        } else if coef >= 0.50 {
            return Color.appAccent
        }
        return Color.secondary
    }
}
