import SwiftUI

struct FuzzerResultsSection: View {
    let fuzzer: OBDFuzzer
    
    var body: some View {
        if !fuzzer.results.isEmpty {
            Section(header: Text("RÉSOLUTIONS DE LIDS (\(fuzzer.results.count))").font(.cardTitle)) {
                ForEach(fuzzer.results) { result in
                    HStack(spacing: 12) {
                        // Icône contextuelle selon le LID
                        Image(systemName: iconForLid(result.did))
                             .font(.title3)
                             .foregroundStyle(Color.appAccent)
                             .frame(width: 32, height: 32)
                             .background(Color.appAccent.opacity(0.1))
                             .clipShape(.rect(cornerRadius: 8))
                            
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(result.did)
                                    .font(.monoSmall)
                                    .bold()
                                    .foregroundStyle(.white)
                                
                                Text("•")
                                    .font(.captionText)
                                    .foregroundStyle(.tertiary)
                                
                                let cleanLidHex = result.did.replacing("LID ", with: "")
                                Text(OBD2Analyzer.describeLID(cleanLidHex) ?? "Paramètre Spécifique")
                                    .font(.captionText)
                                    .bold()
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Si décodable (ex: VIN, numéro série, ou valeurs physiques)
                            let cleanLidHex = result.did.replacing("LID ", with: "")
                            if let decoded = OBD2Analyzer.decodeResponse(request: "21" + cleanLidHex, response: result.response) {
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
    
    private func iconForLid(_ lid: String) -> String {
        let cleanLid = lid.replacing("LID ", with: "").uppercased()
        switch cleanLid {
        case "90": return "barcode.viewfinder"
        case "8C": return "number.circle.fill"
        case "87", "84": return "shippingbox.fill"
        case "88", "89", "01": return "cpu"
        case "04": return "speedometer"
        case "A1", "A3": return "thermometer.medium"
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
