import SwiftUI

struct DTCFreezeFrameSheet: View {
    let dtc: DTC
    let frame: FreezeFrameData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let df = dtc.dfCode {
                                Text(df)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.appAccent.opacity(0.2))
                                    .foregroundStyle(Color.appAccent)
                                    .clipShape(.rect(cornerRadius: 4))
                            }
                            Text(dtc.code)
                                .font(.title2).bold()
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text(dtc.ecu.uppercased())
                                .font(.caption).bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(.secondary)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                        
                        if let desc = dtc.description {
                            Text(desc)
                                .font(.bodyText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(.rect(cornerRadius: 12))

                    // Primary Context Grid
                    Text("Conditions d'apparition enregistrées")
                        .font(.cardTitle)
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        // Kilométrage
                        if let km = frame.timestampKm {
                            MetricCard(
                                title: "Kilométrage",
                                value: km.formatted(.number),
                                unit: "km",
                                icon: "road.lanes",
                                color: .cyan
                            )
                        }

                        // Régime Moteur
                        if let rpm = frame.rpm {
                            MetricCard(
                                title: "Régime Moteur",
                                value: rpm.formatted(.number),
                                unit: "tr/min",
                                icon: "gauge.with.needle.fill",
                                color: .orange
                            )
                        }

                        // Vitesse
                        if let speed = frame.vehicleSpeed {
                            MetricCard(
                                title: "Vitesse Véhicule",
                                value: speed.formatted(.number),
                                unit: "km/h",
                                icon: "speedometer",
                                color: .blue
                            )
                        }

                        // Température Eau
                        if let temp = frame.coolantTemp {
                            MetricCard(
                                title: "Température Eau",
                                value: "\(temp)",
                                unit: "°C",
                                icon: "thermometer.medium",
                                color: temp > 100 ? .red : .teal
                            )
                        }

                        // Charge Moteur
                        if let load = frame.engineLoad {
                            MetricCard(
                                title: "Charge Calculée",
                                value: load.formatted(.number.precision(.fractionLength(1))),
                                unit: "%",
                                icon: "chart.bar.xaxis",
                                color: .indigo
                            )
                        }

                        // Pression Admission
                        if let map = frame.intakePressureKPa {
                            MetricCard(
                                title: "Pression Admission",
                                value: "\(map)",
                                unit: "kPa",
                                icon: "barometer",
                                color: .purple
                            )
                        }

                        // Température Air
                        if let airTemp = frame.intakeAirTemp {
                            MetricCard(
                                title: "T° Air Admission",
                                value: "\(airTemp)",
                                unit: "°C",
                                icon: "wind",
                                color: .cyan
                            )
                        }

                        // Tension Batterie
                        if let volt = frame.batteryVoltage {
                            MetricCard(
                                title: "Tension Calculateur",
                                value: volt.formatted(.number.precision(.fractionLength(2))),
                                unit: "V",
                                icon: "bolt.fill",
                                color: volt < 12.0 ? .red : .green
                            )
                        }

                        // Position Papillon
                        if let throttle = frame.throttlePosition {
                            MetricCard(
                                title: "Position Papillon",
                                value: throttle.formatted(.number.precision(.fractionLength(1))),
                                unit: "%",
                                icon: "circle.dotted.circle",
                                color: .mint
                            )
                        }
                    }

                    // Extra attributes or NRC notes if any
                    if !frame.additionalAttributes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Informations complémentaires")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(Array(frame.additionalAttributes.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.bodyText)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(frame.additionalAttributes[key] ?? "")
                                        .font(.bodyText)
                                        .bold()
                                        .foregroundStyle(.white)
                                }
                                .padding(.vertical, 4)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                        .padding()
                        .background(Color.appCardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Contexte de Panne (Freeze Frame)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appCardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }
}
