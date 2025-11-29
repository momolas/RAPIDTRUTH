//
//  GarageView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/2/23.
//

import SwiftUI

struct GarageView: View {
    @Bindable var garage: Garage
    @State private var showingSheet = false

    var body: some View {
        ZStack {
            if garage.garageVehicles.isEmpty {
                ContentUnavailableView("Garage Empty",
                                       systemImage: "car",
                                       description: Text("Add a vehicle to start monitoring."))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    ForEach(garage.garageVehicles) { vehicle in
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
                                garage.deleteVehicle(vehicle)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: 125, alignment: .leading)
                        .background(garage.currentVehicleVin == vehicle.vin ? Color.blue : Color.clear)
                        .padding(.bottom, 15)
                        .onTapGesture {
                            withAnimation {
                                garage.setCurrentVehicle(by: vehicle.vin)
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
                Image(systemName: "plus.circle")
                    .foregroundStyle(.white)
                    .font(.system(size: 20))
                    .symbolEffect(.bounce, value: showingSheet)
            }
            .sheet(isPresented: $showingSheet) {
                AddVehicleView(viewModel: AddVehicleViewModel(garage: garage))
            }
        )
    }
}

#Preview {
    GarageView(garage: Garage())
        .background(LinearGradient(.darkStart, .darkEnd))
}
