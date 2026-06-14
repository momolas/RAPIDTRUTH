import SwiftUI

struct ContentView: View {
    @State private var pandaDriver = PandaDriver()

    var body: some View {
        MainShellView(driver: pandaDriver)
            .onAppear {
                // Keep attached to its streams.
                // The streams are idle until a transport connection starts.
                pandaDriver.attach()
            }
            .environment(PandaTransport.shared)
    }
}

#Preview {
    ContentView()
        .environment(SettingsStore.shared)
        .environment(PandaTransport.shared)
        .environment(VehicleStore.shared)
        .environment(ProfileRegistry.shared)
}
