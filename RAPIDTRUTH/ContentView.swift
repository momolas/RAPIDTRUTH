import SwiftUI

struct ContentView: View {
    @SwiftUI.AppStorage("selectedDongleType") private var selectedDongle: DongleType = .panda
    
    @State private var pandaDriver = PandaDriver()
    @State private var elm327Driver = ELM327()
    
    var activeDriver: VehicleInterface {
        switch selectedDongle {
        case .panda: return pandaDriver
        case .elm327: return elm327Driver
        }
    }

    var body: some View {
        MainShellView(driver: activeDriver, selectedDongle: $selectedDongle)
            .onAppear {
                // Keep both attached to their respective streams.
                // The streams are idle until a transport connection starts.
                pandaDriver.attach()
                elm327Driver.attach()
            }
            .environment(PandaTransport.shared)
            .environment(BLEManager.shared)
    }
}

#Preview {
    ContentView()
        .environment(SettingsStore.shared)
        .environment(PandaTransport.shared)
        .environment(BLEManager.shared)
        .environment(VehicleStore.shared)
}
