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
    let garage: Garage
    let obdService: OBDService
    let diagnosticsViewModel: VehicleDiagnosticsViewModel

    init(garage: Garage) {
        let bleManager = BLEManager()
        let obdService = OBDService(bleManager: bleManager)
        self.homeViewModel = HomeViewModel(obdService: obdService, garage: garage)
        self.liveDataViewModel = LiveDataViewModel(obdService: obdService, garage: garage)
        self.obdService = obdService
        self.garage = garage
        self.diagnosticsViewModel = VehicleDiagnosticsViewModel(obdService: obdService, garage: garage)
    }

    var body: some View {
        AppTabView(
            homeViewModel: homeViewModel,
            diagnosticsViewModel: diagnosticsViewModel,
            garage: garage,
            obdService: obdService,
            liveDataViewModel: liveDataViewModel,
            displayType: $displayType
        )
        .background(LinearGradient.mainBackground.ignoresSafeArea())
		.preferredColorScheme(ColorScheme.dark) // Enforce dark mode for the "Modern Automotive" look
    }
}

#Preview {
    MainView(garage: Garage())
}
