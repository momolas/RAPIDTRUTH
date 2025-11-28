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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Dashboard")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(Color.textPrimary)
                        Text("Connected Vehicle Status")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    // Connection Status Indicator (Mockup)
                    Circle()
                        .fill(viewModel.isConnected ? Color.statusSuccess : Color.statusError)
                        .frame(width: 12, height: 12)
                        .shadow(color: (viewModel.isConnected ? Color.statusSuccess : Color.statusError).opacity(0.5), radius: 5)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Quick Actions Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

                    HomeCard(title: "Diagnostics", icon: "wrench.and.screwdriver.fill", color: .accentPrimary) {
                        VehicleDiagnosticsView(viewModel: diagnosticsViewModel)
                    }

                    HomeCard(title: "Live Data", icon: "gauge", color: .accentSecondary) {
                         // Navigation is handled via TabView, but we can deep link or show a summary here if needed.
                         // For now, let's link to Logs as a placeholder or maybe specific dashboard widgets
                         LogsView()
                    }

                    HomeCard(title: "Battery", icon: "battery.100.bolt", color: .statusWarning) {
                        BatteryTestView()
                    }

                    HomeCard(title: "Car Screen", icon: "car.side.fill", color: .purple) {
                        CarScreen(viewModel: carScreenViewModel)
                    }
                }
                .padding(.horizontal)
                
                // Secondary Actions (List Style)
                VStack(spacing: 16) {
                    NavigationLink {
                        SettingsView(viewModel: settingsViewModel)
                    } label: {
                        ListRowCard(title: "Settings", icon: "gearshape.fill", color: .gray)
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        ListRowCard(title: "About", icon: "info.circle.fill", color: .gray)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .background(LinearGradient.mainBackground.ignoresSafeArea())
    }
}

// MARK: - Components

struct HomeCard<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .glassCardStyle()
        }
    }
}

struct ListRowCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .padding(8)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            Text(title)
                .font(.body)
                .bold()
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSecondary)
        }
        .padding()
        .glassCardStyle()
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(obdService: OBDService(bleManager: BLEManager()), garage: Garage()),
        diagnosticsViewModel: VehicleDiagnosticsViewModel(obdService: OBDService(bleManager: BLEManager()), garage: Garage()),
        garageViewModel: GarageViewModel(garage: Garage()),
        settingsViewModel: SettingsViewModel(bleManager: BLEManager()),
        carScreenViewModel: CarScreenViewModel(obdService: OBDService(bleManager: BLEManager())),
        displayType: .constant(.quarterScreen)
    )
}
