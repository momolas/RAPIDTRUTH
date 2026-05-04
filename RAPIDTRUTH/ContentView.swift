import SwiftUI

struct ContentView: View {
    let driver = PandaDriver()

    var body: some View {
        MainShellView(driver: driver)
            .onAppear {
                driver.attach()
            }
    }
}

#Preview {
    ContentView()
        .environment(SettingsStore.shared)
        .environment(PandaTransport.shared)
        .environment(VehicleStore.shared)
}
