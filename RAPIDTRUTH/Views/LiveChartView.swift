import SwiftUI
import Charts

struct LiveChartView: View {
    let pidID: String
    let displayName: String
    let unit: String
    
    init(pidID: String, displayName: String, unit: String) {
        self.pidID = pidID
        self.displayName = displayName
        self.unit = unit
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(LoggingSession.self) private var session
    
    private var chartSamples: [LoggingSession.HistoricSample] {
        session.history[pidID] ?? []
    }
    
    private var latestValue: Double? {
        chartSamples.last?.value
    }
    
    private var minSamplesValue: Double? {
        guard !chartSamples.isEmpty else { return nil }
        var minValue = Double.greatestFiniteMagnitude
        for sample in chartSamples {
            if sample.value < minValue {
                minValue = sample.value
            }
        }
        return minValue
    }
    
    private var maxSamplesValue: Double? {
        guard !chartSamples.isEmpty else { return nil }
        var maxValue = -Double.greatestFiniteMagnitude
        for sample in chartSamples {
            if sample.value > maxValue {
                maxValue = sample.value
            }
        }
        return maxValue
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Stat Card
                VStack(spacing: 4) {
                    Text(displayName)
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatValue(latestValue))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Color(red: 92 / 255, green: 196 / 255, blue: 1.0))
                        }
                    }
                }
                .padding(.top, 10)
                
                // Swift Chart Card
                VStack(alignment: .leading, spacing: 10) {
                    if chartSamples.isEmpty {
                        emptyStateView
                    } else {
                        Chart {
                            ForEach(chartSamples) { sample in
                                AreaMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Value", sample.value)
                                )
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [
                                            Color(red: 92 / 255, green: 196 / 255, blue: 1.0).opacity(0.3),
                                            Color(red: 92 / 255, green: 196 / 255, blue: 1.0).opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                
                                LineMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Value", sample.value)
                                )
                                .foregroundStyle(Color(red: 92 / 255, green: 196 / 255, blue: 1.0))
                                .lineStyle(.init(lineWidth: 3))
                                
                                PointMark(
                                    x: .value("Time", sample.timestamp),
                                    y: .value("Value", sample.value)
                                )
                                .foregroundStyle(.white)
                                .symbolSize(30)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine(stroke: .init(lineWidth: 1))
                                    .foregroundStyle(Color.white.opacity(0.05))
                                AxisValueLabel()
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine(stroke: .init(lineWidth: 1))
                                    .foregroundStyle(Color.white.opacity(0.05))
                                AxisValueLabel()
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(height: 250)
                    }
                }
                .appCard()
                .padding(.horizontal, 16)
                
                // Telemetry Details List
                List {
                    Section("Telemetry statistics") {
                        HStack {
                            Text("PID Address")
                            Spacer()
                            Text("0x\(pidID.uppercased())")
                                .font(.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Data count")
                            Spacer()
                            Text("\(chartSamples.count) samples")
                                .font(.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Min value")
                            Spacer()
                            Text(formatValue(minSamplesValue) + " " + unit)
                                .font(.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Max value")
                            Spacer()
                            Text(formatValue(maxSamplesValue) + " " + unit)
                                .font(.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                    .listRowSeparatorTint(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                
                Spacer()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Live trend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.appButton)
                        .foregroundStyle(Color(red: 92 / 255, green: 196 / 255, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var emptyStateView: some View {
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
    
    private func formatValue(_ v: Double?) -> String {
        guard let v else { return "—" }
        if v.rounded() == v && abs(v) < 1e9 { return String(Int(v)) }
        return v.formatted(.number.precision(.fractionLength(2)))
    }
}
