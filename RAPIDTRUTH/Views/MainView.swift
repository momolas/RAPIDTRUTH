//
//  TabView.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/5/23.
//

import SwiftUI
import CoreBluetooth

struct CarlyObd {
    static let elmServiceUUID = "FFE0"
    static let elmCharactericUUID = "FFE1"
}

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var displayType: BottomSheetType = .halfScreen

    let homeViewModel: HomeViewModel
    let liveDataViewModel: LiveDataViewModel
    // bottomSheetViewModel is no longer needed for navigation, but we might check if it had logic we need to keep.
    // Assuming CustomTabBarViewModel was purely for the UI of the tab bar.
    let garageViewModel: GarageViewModel
    let settingsViewModel: SettingsViewModel
    let carScreenViewModel: CarScreenViewModel
    let diagnosticsViewModel: VehicleDiagnosticsViewModel

    init(garage: Garage) {
        let bleManager = BLEManager()
        let obdService = OBDService(bleManager: bleManager)
        self.homeViewModel = HomeViewModel(obdService: obdService, garage: garage)
        self.liveDataViewModel = LiveDataViewModel(obdService: obdService, garage: garage)
        self.carScreenViewModel = CarScreenViewModel(obdService: obdService)
        self.settingsViewModel = SettingsViewModel(bleManager: bleManager)
        self.garageViewModel = GarageViewModel(garage: garage)
        self.diagnosticsViewModel = VehicleDiagnosticsViewModel(obdService: obdService, garage: garage)
    }

    var body: some View {
        AppTabView(
            homeViewModel: homeViewModel,
            diagnosticsViewModel: diagnosticsViewModel,
            garageViewModel: garageViewModel,
            settingsViewModel: settingsViewModel,
            carScreenViewModel: carScreenViewModel,
            liveDataViewModel: liveDataViewModel,
            displayType: $displayType
        )
        .background(LinearGradient.mainBackground.ignoresSafeArea())
        .preferredColorScheme(.dark) // Enforce dark mode for the "Modern Automotive" look
    }
}

#Preview {
    MainView(garage: Garage())
}
