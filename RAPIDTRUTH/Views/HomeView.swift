//
//  HomeView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme

    @Bindable var viewModel: HomeViewModel
    var diagnosticsViewModel: VehicleDiagnosticsViewModel
    var garage: Garage
    var obdService: OBDService

    @Binding var displayType: BottomSheetType

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(AppStrings.Home.dashboard)
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(Color.textPrimary)
                        Text(viewModel.isConnected ? "\(AppStrings.Home.connectedTo) \(viewModel.currentVehicle?.make ?? AppStrings.Home.vehicle)" : AppStrings.Home.notConnected)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    // Connection Status Indicator
                    Circle()
                        .fill(viewModel.isConnected ? Color.statusSuccess : Color.statusError)
                        .frame(width: 12, height: 12)
                        .shadow(color: (viewModel.isConnected ? Color.statusSuccess : Color.statusError).opacity(0.5), radius: 5)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Quick Actions Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

                    // Diagnostics Card
                    HomeCard(title: AppStrings.Home.diagnostics, icon: "wrench.and.screwdriver.fill", color: .accentPrimary, value: viewModel.dashboardDTCCount > 0 ? "\(viewModel.dashboardDTCCount) \(AppStrings.Home.faults)" : AppStrings.Home.systemOK) {
                        VehicleDiagnosticsView(viewModel: diagnosticsViewModel)
                    }

                    // Battery Card
                    HomeCard(title: AppStrings.Home.battery, icon: "battery.100.bolt", color: .statusWarning, value: viewModel.dashboardBatteryVoltage) {
                        BatteryTestView()
                    }

                    HomeCard(title: AppStrings.Home.liveData, icon: "gauge", color: .accentSecondary, value: AppStrings.Home.view) {
                         // Navigation is handled via TabView, but we can deep link or show a summary here if needed.
                         LogsView()
                    }

                    HomeCard(title: AppStrings.Home.carScreen, icon: "car.side.fill", color: .purple, value: AppStrings.Home.open) {
                        CarScreen(obdService: obdService)
                    }

                    HomeCard(title: AppStrings.Coding.title, icon: "terminal.fill", color: .indigo, value: AppStrings.Home.open) {
                        CodingView(obdService: obdService)
                    }
                }
                .padding(.horizontal)
                
                // Secondary Actions (List Style)
                VStack(spacing: 16) {
                    NavigationLink {
                        SettingsView(bleManager: obdService.bleManager)
                    } label: {
                        ListRowCard(title: AppStrings.Home.settings, icon: "gearshape.fill", color: .gray)
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        ListRowCard(title: AppStrings.Home.about, icon: "info.circle.fill", color: .gray)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .background(LinearGradient.mainBackground.ignoresSafeArea())
        .onAppear {
            if viewModel.isConnected {
                Task {
                    await viewModel.refreshDashboardData()
                }
            }
        }
        // Also refresh when connection state changes to true
        .onChange(of: viewModel.isConnected) { _, connected in
            if connected {
                Task {
                    await viewModel.identifyVehicle()
                    await viewModel.refreshDashboardData()
                }
            }
        }
    }
}

// MARK: - Components

struct HomeCard<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    var value: String? = nil
    let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.2))
                        .clipShape(Circle())

                    Spacer()

                    if let value = value {
                        Text(value)
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textSecondary)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 120)
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
        garage: Garage(),
        obdService: OBDService(bleManager: BLEManager()),
        displayType: .constant(.quarterScreen)
    )
}
