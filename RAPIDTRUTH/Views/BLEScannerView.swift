import SwiftUI

struct BLEScannerView: View {
    @Environment(BLEManager.self) private var ble
    let onPickBLE: ((BLEManager.DiscoveredDevice) -> Void)?
    let dismiss: () -> Void
    
    var body: some View {
        if ble.discovered.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning for ELM327 adapters…")
                    .font(.bodyText)
                    .foregroundStyle(.secondary)
                Text("Hold your phone close to the adapter and key the car to ON.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(ble.discovered) { device in
                Button {
                    onPickBLE?(device)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .foregroundStyle(.primary)
                            Text(device.id.uuidString.prefix(13) + "…")
                                .font(.monoSmall)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text("\(device.rssi) dB")
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }
}
