import SwiftUI

struct AppTabView: View {
    @State private var selectedTab: Int = 0

    // ViewModels need to be passed in
    let homeViewModel: HomeViewModel
    let diagnosticsViewModel: VehicleDiagnosticsViewModel
    let garage: Garage
    let obdService: OBDService
    let liveDataViewModel: LiveDataViewModel

    // Legacy bindings support if needed, otherwise we manage state here
    @Binding var displayType: BottomSheetType

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab 1: Home / Dashboard
            NavigationStack {
                HomeView(
                    viewModel: homeViewModel,
                    diagnosticsViewModel: diagnosticsViewModel,
                    garage: garage,
                    obdService: obdService,
                    displayType: $displayType
                )
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Tab 2: Live Data (DashBoardView)
            NavigationStack {
                DashBoardView(
                    liveDataViewModel: liveDataViewModel,
                    displayType: $displayType
                )
            }
            .tabItem {
                Label("Live Data", systemImage: "gauge.with.speedometer")
            }
            .tag(1)

            // Tab 3: Garage
            NavigationStack {
                GarageView(garage: garage)
            }
            .tabItem {
                Label("Garage", systemImage: "car.2.fill")
            }
            .tag(2)

            // Tab 4: Settings
            NavigationStack {
                SettingsView(bleManager: obdService.bleManager)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .tint(.accentPrimary) // Use our new design system color
        .onAppear {
            // Customize TabBar appearance for dark mode glassmorphism feel
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            appearance.backgroundColor = UIColor(Color.darkBackgroundEnd.opacity(0.5))

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
