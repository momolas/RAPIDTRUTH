import SwiftUI

struct FuzzerResultsSection: View {
    let fuzzer: OBDFuzzer
    
    var body: some View {
        if !fuzzer.results.isEmpty {
            Section(header: Text("Résultats (\(fuzzer.results.count))")) {
                ForEach(fuzzer.results) { result in
                    VStack(alignment: .leading) {
                        Text("DID: \(result.did)")
                            .font(.headline)
                        Text("Resp: \(result.response)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
