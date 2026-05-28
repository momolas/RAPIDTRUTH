import SwiftUI

struct FuzzerResultsSection: View {
    let fuzzer: OBDFuzzer
    
    var body: some View {
        if !fuzzer.results.isEmpty {
            Section(header: Text("RÉSOLUTIONS DE DIDS (\(fuzzer.results.count))").font(.cardTitle)) {
                ForEach(fuzzer.results) { result in
                    HStack(spacing: 12) {
                        // Icône contextuelle selon le DID
                        Image(systemName: iconForDid(result.did))
                            .font(.title3)
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 32, height: 32)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                            
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("DID \(result.did)")
                                    .font(.monoSmall)
                                    .bold()
                                    .foregroundStyle(.white)
                                
                                Text("•")
                                    .font(.captionText)
                                    .foregroundStyle(.tertiary)
                                
                                Text(OBD2Analyzer.describeDID(result.did) ?? "Paramètre Spécifique")
                                    .font(.captionText)
                                    .bold()
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Si décodable (ex: VIN, numéro série, ou valeurs physiques)
                            if let decoded = OBD2Analyzer.decodeResponse(request: "22" + result.did, response: result.response) {
                                Text(decoded)
                                    .font(.valueNumber)
                                    .foregroundStyle(Color.appAccent)
                                    .padding(.top, 2)
                                
                                Text("Brut: \(result.response)")
                                    .font(.monoTiny)
                                    .foregroundStyle(.tertiary)
                            } else {
                                // Afficher simplement l'hexdump si non décodable en texte
                                Text(spacedHex(result.response))
                                    .font(.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.02))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func iconForDid(_ did: String) -> String {
        switch did.uppercased() {
        case "F190": return "barcode.viewfinder"
        case "F18C": return "number.circle.fill"
        case "F187", "F191": return "shippingbox.fill"
        case "F188", "F189": return "cpu"
        case "F186": return "key.fill"
        default: return "doc.text.magnifyingglass"
        }
    }
    
    private func spacedHex(_ hex: String) -> String {
        var spaced = ""
        var i = 0
        for char in hex {
            spaced.append(char)
            i += 1
            if i % 2 == 0 {
                spaced.append(" ")
            }
        }
        return spaced.trimmingCharacters(in: .whitespaces)
    }
}
