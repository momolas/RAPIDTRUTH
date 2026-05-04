import SwiftUI

struct ContentView: View {
    @State private var adapterManager = AdapterManager.shared

    var body: some View {
        MainShellView(adapterManager: adapterManager)
            .onAppear {
                // Initialize the active adapter's stream reader
                if adapterManager.adapterType == .elm327 {
                    adapterManager.elm327.attach()
                } else {
                    adapterManager.pandaDriver.attach()
                }
            }
    }
}

#Preview {
    ContentView()
}
