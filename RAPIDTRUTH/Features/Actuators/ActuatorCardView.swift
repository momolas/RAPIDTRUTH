import SwiftUI

struct ActuatorCardView: View {
    let actuator: ActuatorDef
    let isConnected: Bool
    let isExecutingThis: Bool
    let isAnyExecuting: Bool
    let onTrigger: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Icon badge
                Image(systemName: actuator.iconName)
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.appAccent.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(actuator.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if !actuator.subtitle.isEmpty {
                        Text(actuator.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // ECU Target Tag
                Text("ECU \(actuator.ecuHeader)")
                    .font(.monoTiny)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .foregroundStyle(.tertiary)
                    .clipShape(.rect(cornerRadius: 4))
            }

            // Duration & safety note
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("\(actuator.durationSeconds)s")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.secondary)

                Text(actuator.safetyNote)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }

            // Action Button
            Button(action: onTrigger) {
                HStack {
                    if isExecutingThis {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Test en cours...")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Déclencher le test")
                    }
                }
                .font(.caption).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isExecutingThis ? Color.orange : Color.appAccent)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 8))
            }
            .disabled(!isConnected || (isAnyExecuting && !isExecutingThis))
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }
}
