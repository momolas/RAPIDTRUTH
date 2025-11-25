//
//  HomeView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI

struct HomeView: View {
	@Environment(\.colorScheme) var colorScheme
	
    var viewModel: HomeViewModel
    var diagnosticsViewModel: VehicleDiagnosticsViewModel
    var garageViewModel: GarageViewModel
    var settingsViewModel: SettingsViewModel
    var carScreenViewModel: CarScreenViewModel

    @Binding var displayType: BottomSheetType

    var garageVehicles: [Vehicle] {
        viewModel.garageVehicles
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 20) {
                    SectionView(title: "Diagnostics", 
                                subtitle: "Read Vehicle Health",
                                iconName: "wrench.and.screwdriver",
                                destination: VehicleDiagnosticsView(viewModel: diagnosticsViewModel))
                    SectionView(title: "Logs",
                                subtitle: "View Logs",
                                iconName: "flowchart",
                                destination: LogsView())
                    SectionView(title: "Battery",
                                subtitle: "Monitor Battery Health",
                                iconName: "minus.plus.batteryblock",
                                destination: BatteryTestView())
                }
                .padding(.vertical, 20)

                Divider()
					.background(Color.white)
					.padding(.horizontal, 20)
                
				NavigationLink {
                    SettingsView(viewModel: settingsViewModel)
                } label: {
                    SettingsAboutSectionView(title: "Settings", iconName: "gear", iconColor: .green.opacity(0.6))
                }

                Divider()
					.background(Color.white)
					.padding(.horizontal, 20)
                
				NavigationLink {
                    GarageView(viewModel: garageViewModel)
                        .background(LinearGradient(.darkStart, .darkEnd))
                } label: {
                    SettingsAboutSectionView(title: "Garage", iconName: "car.circle", iconColor: .blue.opacity(0.6))
                }

                Divider()
					.background(Color.white)
					.padding(.horizontal, 20)
                
				NavigationLink {
                    AboutView()
                        .onAppear {
                            withAnimation {
                                self.displayType = .none
                            }
                        }
                        .onDisappear {
                            withAnimation {
                                self.displayType = .quarterScreen
                            }
                        }
                        .transition(.move(edge: .bottom))

                } label: {
                    SettingsAboutSectionView(title: "About", iconName: "info.circle", iconColor: .secondary)
                }
                
				Divider()
					.background(Color.white)
					.padding(.horizontal, 20)
                
				NavigationLink {
                    CarScreen(viewModel: carScreenViewModel)
                        .background(LinearGradient(.darkStart, .darkEnd))
                } label: {
                    SettingsAboutSectionView(title: "Message", iconName: "car.circle", iconColor: .blue.opacity(0.6))
                }

                Divider()
					.background(Color.white)
					.padding(.horizontal, 20)
            }
            .padding()
        }
    }
}

struct SettingsAboutSectionView: View {
    let title: String
    let iconName: String
    let iconColor: Color

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

        }
        .frame(maxWidth: .infinity, maxHeight: 400, alignment: .leading)
        .padding(.horizontal, 22)
    }
}

#Preview {
    ZStack {
        LinearGradient(.darkStart, .darkEnd)
            .ignoresSafeArea()
        HomeView(
            viewModel: HomeViewModel(obdService: OBDService(bleManager: BLEManager()), garage: Garage()),
            diagnosticsViewModel: VehicleDiagnosticsViewModel(obdService: OBDService(bleManager: BLEManager()), garage: Garage()),
            garageViewModel: GarageViewModel(garage: Garage()),
            settingsViewModel: SettingsViewModel(bleManager: BLEManager()), 
            carScreenViewModel: CarScreenViewModel(obdService: OBDService(bleManager: BLEManager())),
            displayType: .constant(.quarterScreen))
    }
}
