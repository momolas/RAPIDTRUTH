import SwiftUI

extension View {
    /// Style pagination buttons dynamically with native iOS 26+ glass style or standard bordered fallbacks.
    @ViewBuilder
    func paginationButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
