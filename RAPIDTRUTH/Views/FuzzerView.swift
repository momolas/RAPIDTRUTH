import SwiftUI

struct FuzzerView: View {
    let interface: VehicleInterface
    @Environment(\.dismiss) var dismiss
    @State private var fuzzer = OBDFuzzer()
    
    @State private var targetEcu: String = "7E0"
    @State private var startDidHex: String = "0000"
    @State private var endDidHex: String = "00FF"
    @State private var agreedToRisks: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                if !agreedToRisks {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title)
                                Text("Avertissement de Sécurité")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            Text("Le fuzzing OBD peut entraîner des comportements inattendus du véhicule, y compris des plantages d'ECU. Ce fuzzer est strictement limité à la LECTURE (Service 22).")
                                .font(.subheadline)
                            
                            Toggle("J'accepte les risques", isOn: $agreedToRisks)
                                .tint(.red)
                                .padding(.top, 5)
                        }
                    }
                } else {
                    Section(header: Text("Configuration du Fuzzer")) {
                        TextField("ECU Cible (ex: 7E0)", text: $targetEcu)
                        TextField("DID Début (Hex)", text: $startDidHex)
                        TextField("DID Fin (Hex)", text: $endDidHex)
                    }
                    
                    Section {
                        if fuzzer.isRunning {
                            Button(action: {
                                fuzzer.cancel()
                            }) {
                                Text("Arrêter le Fuzzing")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
							.buttonBorderShape(.roundedRectangle)
                            .tint(.red)
                            
                            ProgressView(value: fuzzer.currentProgress)
                                .padding(.vertical, 8)
                            
                        } else {
                            Button(action: {
                                startFuzzing()
                            }) {
                                Text("Démarrer le Fuzzing")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
							.buttonBorderShape(.roundedRectangle)
                            .tint(.orange)
                        }
                    }
                    
                    if let error = fuzzer.actionError {
                        Section {
                            Text(error).foregroundColor(.red)
                        }
                    }
                    
                    if !fuzzer.results.isEmpty {
                        Section(header: Text("Résultats (\(fuzzer.results.count))")) {
                            List(fuzzer.results) { result in
                                VStack(alignment: .leading) {
                                    Text("DID: \(result.did)")
                                        .font(.headline)
                                    Text("Resp: \(result.response)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fuzzer OBD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
    
    private func startFuzzing() {
        guard let start = Int(startDidHex, radix: 16),
              let end = Int(endDidHex, radix: 16),
              start <= end else {
            fuzzer.actionError = "Valeurs hexadécimales invalides."
            return
        }
        
        Task {
            await fuzzer.fuzzService22(interface: interface, ecu: targetEcu, startDid: start, endDid: end)
        }
    }
}
