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
                ContentUnavailableView(AppStrings.Garage.emptyTitle,
                                       systemImage: "car",
                                       description: Text(AppStrings.Garage.emptyDescription))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(garage.garageVehicles) { vehicle in
                            VehicleRow(vehicle: vehicle,
                                       isActive: garage.currentVehicleVin == vehicle.vin,
                                       onSelect: {
                                           withAnimation {
                                               garage.setCurrentVehicle(by: vehicle.vin)
                                           }
                                       },
                                       onDelete: {
                                           garage.deleteVehicle(vehicle)
                                       })
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient.mainBackground.ignoresSafeArea())
        .navigationTitle(AppStrings.Garage.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSheet.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentPrimary)
                        .font(.system(size: 24))
                        .symbolEffect(.bounce, value: showingSheet)
                }
            }
        }
        .sheet(isPresented: $showingSheet) {
            AddVehicleView(viewModel: AddVehicleViewModel(garage: garage))
        }
    }
}

struct VehicleRow: View {
    let vehicle: Vehicle
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon / Avatar
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accentPrimary : Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)

                    Image(systemName: "car.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.make)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)

                    Text("\(vehicle.model) • \(vehicle.year)")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                // Active Status or Select
                if isActive {
                    Text(AppStrings.Garage.active)
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary.opacity(0.2))
                        .foregroundStyle(Color.accentPrimary)
                        .clipShape(Capsule())
                }

                // Delete Button (Menu or direct)
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.textSecondary)
                        .padding(10)
                        .contentShape(Rectangle())
                }
            }
            .padding()
            .glassCardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.accentPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GarageView(garage: Garage())
        .background(LinearGradient.mainBackground)
}
