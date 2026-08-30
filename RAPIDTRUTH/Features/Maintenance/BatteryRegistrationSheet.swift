import SwiftUI
import SwiftVehicleProtocols

struct BatteryRegistrationSheet: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTech: BatteryTechnology = .efb
    @State private var capacityAh: Int = 70
    @State private var showingConfirmation = false

    private let availableCapacities = [45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "battery.100.bolt")
                                .font(.title2)
                                .foregroundStyle(Color.appAccent)
                            Text("Enregistrement Nouvelle Batterie (BMS)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Text("Indiquez au calculateur de gestion d'énergie (BMS/UPC) le type et la capacité de la batterie neuve. Cette opération réinitialise la courbe de charge de l'alternateur intelligent et prévient l'usure prématurée.")
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(.rect(cornerRadius: 12))

                    // Status Messages
                    if let success = maintenanceManager.successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(success)
                                .font(.captionText)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 10))
                    } else if let error = maintenanceManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.captionText)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    // Technology Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Technologie de la batterie")
                            .font(.subheadline).bold()
                            .foregroundStyle(.white)

                        ForEach(BatteryTechnology.allCases) { tech in
                            Button {
                                selectedTech = tech
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tech.rawValue)
                                            .font(.bodyText)
                                            .foregroundStyle(.white)
                                        Text(techDescription(for: tech))
                                            .font(.captionTiny)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedTech == tech {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding()
                                .background(selectedTech == tech ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedTech == tech ? Color.appAccent : Color.clear, lineWidth: 1)
                                )
                                .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Capacity Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. Capacité nominale (Ampères-heures)")
                            .font(.subheadline).bold()
                            .foregroundStyle(.white)

                        HStack {
                            Text("\(capacityAh) Ah")
                                .font(.title).bold()
                                .foregroundStyle(Color.appAccent)
                            Spacer()
                            Picker("Capacité", selection: $capacityAh) {
                                ForEach(availableCapacities, id: \.self) { cap in
                                    Text("\(cap) Ah").tag(cap)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.appAccent)
                        }
                        .padding()
                        .background(Color.appCardBackground)
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    // Action Button
                    Button {
                        showingConfirmation = true
                    } label: {
                        HStack {
                            if maintenanceManager.isExecuting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                            }
                            Text("Enregistrer et Réinitialiser le BMS")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConnected && !maintenanceManager.isExecuting ? Color.appAccent : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .disabled(!isConnected || maintenanceManager.isExecuting)
                    .confirmationDialog("Confirmer l'enregistrement", isPresented: $showingConfirmation) {
                        Button("Valider l'enregistrement (\(selectedTech.rawValue) - \(capacityAh) Ah)") {
                            Task {
                                await maintenanceManager.registerNewBattery(
                                    interface: interface,
                                    technology: selectedTech,
                                    capacityAh: capacityAh
                                )
                            }
                        }
                        Button("Annuler", role: .cancel) {}
                    } message: {
                        Text("Moteur coupé impérativement, contact mis. Cette procédure enregistre la nouvelle batterie dans le calculateur.")
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Batterie & BMS")
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

    private func techDescription(for tech: BatteryTechnology) -> String {
        switch tech {
        case .standardLeadAcid:
            return "Pour véhicules sans Stop & Start ou équipés de batterie classique au plomb."
        case .efb:
            return "Pour véhicules avec Stop & Start d'entrée/milieu de gamme."
        case .agm:
            return "Pour véhicules avec Stop & Start avancé, récupération d'énergie au freinage."
        }
    }
}
