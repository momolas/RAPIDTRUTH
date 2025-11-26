//
//  VehicleDiagnosticsView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Observation

@MainActor
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
    var errorMessage: String?
    var showAlert = false

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
                self.troubleCodes = troubleCodes
            } catch {
                self.errorMessage = error.localizedDescription
                self.showAlert = true
            }
        }
    }

    func clearTroubleCodes() {
        Task {
            do {
                try await obdService.clearTroubleCodes()
                // Clear local list after successful command
                self.troubleCodes.removeAll()
            } catch {
                self.errorMessage = error.localizedDescription
                self.showAlert = true
            }
        }
    }

    func clearTroubleCodes() {
        Task {
            do {
                try await obdService.clearTroubleCodes()
                // Clear local list after successful command
                self.troubleCodes.removeAll()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

struct VehicleDiagnosticsView: View {
    @Bindable var viewModel: VehicleDiagnosticsViewModel

    var body: some View {
        ZStack {
            LinearGradient(.darkStart, .darkEnd)
                .ignoresSafeArea()

            VStack {
                if viewModel.troubleCodes.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView("No Trouble Codes",
                                               systemImage: "checkmark.circle",
                                               description: Text("No codes found or scan not started."))
                        .foregroundStyle(.white)
                    } else {
                        Text("No Trouble Codes")
                            .foregroundStyle(.white)
                    }
                }

                HStack {
                    Button {
                        viewModel.clearTroubleCodes()
                    } label: {
                        Text("Clear Trouble Codes")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(15)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    Button {
                        viewModel.scanForTroubleCodes()
                    } label: {
                        HStack {
                            if #available(iOS 17.0, *) {
                                Image(systemName: "magnifyingglass")
                                    .symbolEffect(.pulse.byLayer)
                            }
                            Text("Scan for Trouble Codes")
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(troubleCode.description)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
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
        .errorAlert()
    }

    var navTitle: String {
           if let currentVehicle = viewModel.currentVehicle {
               return "\(currentVehicle.year) \(currentVehicle.make) \(currentVehicle.model)"
           } else {
               return "Garage Empty"
           }
       }
}

extension VehicleDiagnosticsView {
    // Helper to attach alert
    func errorAlert() -> some View {
        self.alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

#Preview {
    ZStack {
        VehicleDiagnosticsView(viewModel: VehicleDiagnosticsViewModel(obdService: OBDService(bleManager: BLEManager()),
                                                        garage: Garage()))
    }
}
