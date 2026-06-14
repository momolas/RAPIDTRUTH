import SwiftUI

struct WiFiScannerView: View {
    @Environment(PandaTransport.self) private var panda
    let onPickWiFi: ((String) -> Void)?
    let dismiss: () -> Void
    
    var body: some View {
        if panda.discoveredPandas.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning for Panda Wi-Fi…")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Text("Connect your iPhone to the Panda's Wi-Fi network in Settings.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(panda.discoveredPandas, id: \.self) { ip in
                Button {
                    onPickWiFi?(ip)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Panda Wi-Fi")
                                .foregroundStyle(.primary)
                            Text(ip)
                                .font(.monoSmall)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "wifi")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }
}
