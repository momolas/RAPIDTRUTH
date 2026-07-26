import SwiftUI

struct PidRowView: View {
    let pid: PidDef
    let isSelected: Bool
    let isSampling: Bool
    let isStriked: Bool
    let liveValue: Sampler.LiveValue?
    let onToggle: () -> Void
    
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
                    Text("ECU \(pid.ecu) · Mode \(pid.mode) PID \(pid.pid)")
                        .font(.monoSmall)
                        .foregroundStyle(.secondary)
                    
                    if isStriked {
                        Text("Non répondue")
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
