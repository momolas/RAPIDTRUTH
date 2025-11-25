//
//  GarageView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/2/23.
//

import SwiftUI

struct GarageView: View {
    var viewModel: GarageViewModel
    @State private var showingSheet = false

    var body: some View {
        ZStack {
            if viewModel.garage.garageVehicles.isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView("Garage Empty",
                                           systemImage: "car",
                                           description: Text("Add a vehicle to start monitoring."))
                } else {
                    Text("Garage Empty. Add a vehicle.")
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    ForEach(viewModel.garage.garageVehicles) { vehicle in
                        HStack {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(vehicle.make)
                                    .font(.system(size: 20, weight: .bold, design: .default))
                                     .foregroundStyle(.white)

                                Text(vehicle.model)
                                    .font(.system(size: 14, weight: .bold, design: .default))
                                    .foregroundStyle(.white)

                                Text(vehicle.year)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Button {
                                viewModel.deleteVehicle(vehicle)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: 125, alignment: .leading)
                        .background(viewModel.currentVehicle?.vin == vehicle.vin ? Color.blue : Color.clear)
                        .padding(.bottom, 15)
                        .onTapGesture {
                            withAnimation {
                                viewModel.garage.setCurrentVehicle(by: vehicle.vin)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: 
            Button {
                showingSheet.toggle()
            } label: {
                if #available(iOS 17.0, *) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.white)
                        .font(.system(size: 20))
                        .symbolEffect(.bounce, value: showingSheet)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.white)
                        .font(.system(size: 20))
                }
            }
            .sheet(isPresented: $showingSheet) {
                AddVehicleView(viewModel: AddVehicleViewModel(garage: viewModel.garage))
            }
        )
    }
}

#Preview {
    GarageView(viewModel: GarageViewModel(garage: Garage()))
        .background(LinearGradient(.darkStart, .darkEnd))
}
