import SwiftUI

/// Sheet that lets the user pick a discovered BLE device. Lives only while
/// scanning; auto-stops scan on dismiss.
struct DevicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let dongleType: DongleType
    let ble = BLEManager.shared
    let panda = PandaTransport.shared
    
    var onPickBLE: ((BLEManager.DiscoveredDevice) -> Void)? = nil
    var onPickWiFi: ((String) -> Void)? = nil

    var body: some View {
        NavigationStack {
            Group {
                if dongleType == .panda {
                    wifiScannerView
                } else {
                    bleScannerView
                }
            }
            .navigationTitle("Choose adapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if dongleType == .panda {
                            panda.stopScan()
                        } else {
                            ble.stopScan()
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if dongleType == .panda {
                panda.scanForPandas()
            } else {
                Task { _ = await ble.awaitPowerStateSettled(); ble.startScan() }
            }
        }
        .onDisappear {
            if dongleType == .panda {
                panda.stopScan()
            } else {
                ble.stopScan()
            }
        }
    }
    
    // MARK: - BLE View
    @ViewBuilder
    private var bleScannerView: some View {
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
    
    // MARK: - Wi-Fi View
    @ViewBuilder
    private var wifiScannerView: some View {
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
