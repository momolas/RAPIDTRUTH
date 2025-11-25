//
//  VehicleDiagnosticsView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Observation

@Observable
class VehicleDiagnosticsViewModel {
    var garage: Garage

    var currentVehicle: Vehicle? {
        if let vin = garage.currentVehicleVin {
             return garage.garageVehicles.first(where: { $0.vin == vin })
        }
        return nil
    }

    var garageVehicles: [Vehicle] {
        garage.garageVehicles
    }

    var troubleCodes: [TroubleCode] = []

    let obdService: OBDService

    init(obdService: OBDService, garage: Garage) {
        self.obdService = obdService
        self.garage = garage
    }

    func scanForTroubleCodes() {
        Task {
            do {
                guard let troubleCodes = try await obdService.scanForTroubleCodes() else {
                    return
                }
                DispatchQueue.main.async {
                    self.troubleCodes = troubleCodes
                }
                print("Trouble Codes: \(troubleCodes)")
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

struct VehicleDiagnosticsView: View {
    var viewModel: VehicleDiagnosticsViewModel

    var body: some View {
        ZStack {
            LinearGradient(.darkStart, .darkEnd)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        print("Button tapped")
                    } label: {
                        Text("Clear Trouble Codes")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(15)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    Button {
                        viewModel.scanForTroubleCodes()
                    } label: {
                        Text("Scan for Trouble Codes")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(15)
                            .background(Color.pinknew)
                            .cornerRadius(10)
                    }
                }

                Divider()
					.background(Color.white)
					.padding(10)

                ForEach(viewModel.troubleCodes, id: \.self) { troubleCode in
                    VStack {
                        HStack {
                            Text(troubleCode.rawValue)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(troubleCode.description)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        
						Divider()
							.background(Color.white)
							.padding(10)
                    }
                }
            
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var navTitle: String {
           if let currentVehicle = viewModel.currentVehicle {
               return "\(currentVehicle.year) \(currentVehicle.make) \(currentVehicle.model)"
           } else {
               return "Garage Empty"
           }
       }
}

#Preview {
    ZStack {
        VehicleDiagnosticsView(viewModel: VehicleDiagnosticsViewModel(obdService: OBDService(bleManager: BLEManager()),
                                                        garage: Garage()))
    }
}
