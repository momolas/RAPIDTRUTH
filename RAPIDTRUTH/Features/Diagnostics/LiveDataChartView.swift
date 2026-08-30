import SwiftUI
import Charts
import SwiftVehicleProtocols

struct LiveDataChartView: View {
    let pids: [PidDef]
    let history: [String: [ChartDataPoint]]
    
    var body: some View {
        let activePidsWithHistory = pids.filter { pid in
            guard let points = history[pid.id], !points.isEmpty else { return false }
            return true
        }
        
        if activePidsWithHistory.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Graphiques Temps Réel")
                    .font(.captionText).bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(activePidsWithHistory) { pid in
                            let points = history[pid.id] ?? []
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(pid.displayName)
                                        .font(.captionText)
                                        .bold()
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    if let lastPoint = points.last {
                                        Text("\(lastPoint.value.formatted(.number.precision(.fractionLength(1)))) \(pid.unit)")
                                            .font(.monoTiny)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                
                                Chart {
                                    ForEach(points) { point in
                                        LineMark(
                                            x: .value("Temps", point.timestamp),
                                            y: .value("Valeur", point.value)
                                        )
                                        .foregroundStyle(Color.appAccent)
                                        .interpolationMethod(.monotone)
                                        
                                        AreaMark(
                                            x: .value("Temps", point.timestamp),
                                            y: .value("Valeur", point.value)
                                        )
                                        .foregroundStyle(Color.appAccent.opacity(0.1))
                                        .interpolationMethod(.monotone)
                                    }
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.gray)
                                            .font(.system(size: 8))
                                    }
                                }
                                .frame(width: 140, height: 60)
                            }
                            .padding(10)
                            .background(Color.appCardBackground)
                            .clipShape(.rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.appBackground)
        }
    }
}
