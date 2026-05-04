import SwiftUI

struct ContentView: View {
    // Single ELM327 instance shared across the whole app.
    @State private var elm = ELM327()

    var body: some View {
        MainShellView(elm: elm)
    }
}

#Preview {
    ContentView()
}
