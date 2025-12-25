//
//  AddPIDView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/10/23.
//

import SwiftUI
import Observation

@Observable
class AddPIDViewModel {
    let garage: Garage

    var currentVehicle: Vehicle? {
        if let vin = garage.currentVehicleVin {
            return garage.garageVehicles.first(where: { $0.vin == vin })
        }
        return nil
    }

    init(garage: Garage) {
        self.garage = garage
    }
}

struct AddPIDView: View {
    var viewModel: LiveDataViewModel
    var body: some View {
        if let car = viewModel.currentVehicle {
            VStack(alignment: .leading) {
                Text("Supported sensors for \(car.year) \(car.make) \(car.model)")
                Divider().background(Color.white)

                ScrollView(.vertical) {
                    if let supportedPIDs = car.obdinfo?.supportedPIDs {
                        ForEach(supportedPIDs, id: \.self) { pid in
                            Button {
                                viewModel.addPIDToRequest(pid)
                            } label: {
                                HStack {
                                    Text(pid.properties.description)
                                        .font(.caption)
                                        .padding()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.endColor())
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(viewModel.data.keys.contains(pid) ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }

    }
}

#Preview {
    AddPIDView(viewModel: LiveDataViewModel(obdService: OBDService(bleManager: BLEManager()),
                                            garage: Garage()))
}
