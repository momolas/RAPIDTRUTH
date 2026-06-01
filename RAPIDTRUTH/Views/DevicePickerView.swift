import SwiftUI

/// Sheet that lets the user pick a discovered BLE device. Lives only while
/// scanning; auto-stops scan on dismiss.
struct DevicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let dongleType: DongleType
    @Environment(BLEManager.self) private var ble
    @Environment(PandaTransport.self) private var panda
    
    var onPickBLE: ((BLEManager.DiscoveredDevice) -> Void)? = nil
    var onPickWiFi: ((String) -> Void)? = nil

    var body: some View {
        NavigationStack {
            Group {
                if dongleType == .panda {
                    WiFiScannerView(onPickWiFi: onPickWiFi, dismiss: { dismiss() })
                } else {
                    BLEScannerView(onPickBLE: onPickBLE, dismiss: { dismiss() })
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
        .task {
            if dongleType == .panda {
                panda.scanForPandas()
            } else {
                _ = await ble.awaitPowerStateSettled()
                ble.startScan()
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
}
