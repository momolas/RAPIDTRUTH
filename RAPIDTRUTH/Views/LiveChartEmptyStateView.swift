import SwiftUI

struct LiveChartEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Waiting for data points…")
                .font(.valueLabel)
                .foregroundStyle(.primary)
            Text("Keep logging to gather rolling samples for this PID.")
                .font(.bodyText)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
        .padding()
    }
}
