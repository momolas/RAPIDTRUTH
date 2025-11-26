//
//  SettingsView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/13/23.
//

import SwiftUI
import CoreBluetooth
import Observation

@Observable
class SettingsViewModel {
	var peripherals: [Peripheral] {
        bleManager.foundPeripherals
    }
	
	let bleManager: BLEManager
	
	init(bleManager: BLEManager) {
		self.bleManager = bleManager
	}
}

struct SettingsView: View {
	var viewModel: SettingsViewModel
	
	var body: some View {
        List {
            Section(header: Text("Bluetooth Devices")) {
                if viewModel.peripherals.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView("No Devices Found",
                                               systemImage: "wifi.slash",
                                               description: Text("Ensure Bluetooth is on and devices are in range."))
                    } else {
                        Text("No Devices Found")
                    }
                } else {
                    ForEach(viewModel.peripherals) { peripheral in
                        PeripheralRow(peripheral: peripheral)
                    }
                }
            }

            Section(header: Text("Supported Adapters")) {
                ForEach(OBDDevices.allCases, id: \.self) { OBDDevice in
                    Text(OBDDevice.properties.DeviceName)
                }
            }
        }
        .navigationTitle("Settings")
	}
}

struct PeripheralRow: View {
	let peripheral: Peripheral
	
	var body: some View {
		HStack {
			Text(peripheral.name)
			Spacer()
			Text("\(peripheral.rssi)")
		}
	}
}

struct ProtocolPicker: View {
	@Binding var selectedProtocol: OBDProtocol
	
	var body: some View {
		HStack {
			Text("OBD Protocol: ")
				.padding()
				.frame(maxWidth: .infinity, alignment: .leading)
			
			Picker("Select Protocol", selection: $selectedProtocol) {
				ForEach(OBDProtocol.asArray, id: \.self) { protocolItem in
					Text(protocolItem.description).tag(protocolItem)
				}
			}
		}
	}
}

struct RoundedRectangleStyle: ViewModifier {
	@Environment(\.colorScheme) var colorScheme
	
	func body(content: Content) -> some View {
		content
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 10)
					.fill(Color.endColor())
			)
	}
}

#Preview {
	SettingsView(viewModel: SettingsViewModel(bleManager: BLEManager()))
}
