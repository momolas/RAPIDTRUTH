import SwiftUI

extension Sampler.LiveValue: Identifiable {
    public var id: String { pidID }
}

struct LiveReadoutView: View {
    @Environment(LoggingSession.self) private var session
    
    @State private var selectedLivePID: Sampler.LiveValue?

    /// Display order matches the web app: Engine first, hybrid drivetrain
    /// next, battery, then transmission/emissions/diagnostics.
    private static let categoryOrder: [PidCategory] = [
        .engine, .hybrid, .battery, .transmission, .emissions, .diagnostics, .other,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live readout").font(.cardTitle)
                Spacer()
                Text("\(session.liveValues.count) PIDs")
                    .font(.monoSmall)
                    .foregroundStyle(.tertiary)
            }
            if session.liveValues.isEmpty {
                Text("Start logging to see live values.")
                    .font(.bodyText)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Self.categoryOrder, id: \.self) { category in
                    if let bucket = session.groupedLiveValues[category], !bucket.isEmpty {
                        LiveCategorySectionView(
                            category: category,
                            values: bucket,
                            selectedLivePID: $selectedLivePID
                        )
                    }
                }
            }
        }
        .appCard()
        .sheet(item: $selectedLivePID) { live in
            LiveChartView(
                pidID: live.pidID,
                displayName: live.displayName,
                unit: live.unit
            )
        }
    }
}

struct LiveCategorySectionView: View {
    let category: PidCategory
    let values: [Sampler.LiveValue]
    @Binding var selectedLivePID: Sampler.LiveValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(category.rawValue.capitalized)
                    .font(.captionText.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("(\(values.count))")
                    .font(.monoSmall)
                    .foregroundStyle(.tertiary)
            }
            let columns = [GridItem(.adaptive(minimum: 150), spacing: 6)]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(values) { live in
                    Button {
                        selectedLivePID = live
                    } label: {
                        LiveValueCellView(live: live)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct LiveValueCellView: View {
    let live: Sampler.LiveValue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(live.displayName)
                .font(.captionTiny)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatValue(live.value))
                    .font(.valueNumber)
                    .foregroundStyle(.primary)
                if !live.unit.isEmpty {
                    Text(live.unit)
                        .font(.captionTiny)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 6))
    }

    private func formatValue(_ v: Double?) -> String {
        guard let v else { return "—" }
        if v.rounded() == v && abs(v) < 1e9 { return String(Int(v)) }
        return v.formatted(.number.precision(.fractionLength(2)))
    }
}
