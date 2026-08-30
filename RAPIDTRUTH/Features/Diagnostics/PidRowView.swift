import SwiftUI
import SwiftVehicleProtocols

struct PidRowView: View {
    let pid: PidDef
    let isSelected: Bool
    let isSampling: Bool
    let isStriked: Bool
    let rate: SamplingRate
    let measuredHz: Double?
    let liveValue: Sampler.LiveValue?
    let onToggle: () -> Void
    let onRateChange: (SamplingRate) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox Button
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.appAccent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isSampling)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(pid.displayName)
                        .font(.valueLabel)
                        .foregroundStyle(isStriked ? .secondary : .primary)
                        .strikethrough(isStriked)
                    
                    Text(pid.ecu.uppercased())
                        .font(.monoTiny)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .foregroundStyle(.tertiary)
                        .clipShape(.rect(cornerRadius: 3))
                }
                
                HStack(spacing: 8) {
                    Text("Mode \(pid.mode) PID \(pid.pid)")
                        .font(.monoSmall)
                        .foregroundStyle(.secondary)
                    
                    // Sélecteur de cadence (Menu)
                    if !isSampling {
                        Menu {
                            ForEach(SamplingRate.allCases) { r in
                                Button {
                                    onRateChange(r)
                                } label: {
                                    Label(r.rawValue, systemImage: r.iconName)
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: rate.iconName)
                                    .font(.system(size: 9))
                                Text(rate.shortName)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rate == .fast ? Color.orange.opacity(0.2) : (rate == .normal ? Color.blue.opacity(0.2) : Color.green.opacity(0.2)))
                            .foregroundStyle(rate == .fast ? .orange : (rate == .normal ? .blue : .green))
                            .clipShape(.rect(cornerRadius: 4))
                        }
                    } else if let measuredHz {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            Text("\(measuredHz.formatted(.number.precision(.fractionLength(1)))) Hz")
                                .font(.monoTiny)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if isStriked {
                        Text("Silencieux")
                            .font(.captionTiny)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Value display
            if isSampling && isSelected {
                if let liveValue {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            if let val = liveValue.value {
                                Text(val.formatted(.number.precision(.fractionLength(1))))
                                    .font(.valueNumber)
                                    .bold()
                                    .foregroundStyle(Color.appAccent)
                            } else {
                                Text(liveValue.raw)
                                    .font(.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !liveValue.unit.isEmpty {
                                Text(liveValue.unit)
                                    .font(.captionTiny)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if isStriked {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
