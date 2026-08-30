import SwiftUI
import SwiftVehicleProtocols

struct ActuatorDashboardView: View {
    let interface: VehicleInterface
    let profile: Profile?
    
    @State private var manager = ActuatorManager()
    @State private var selectedCategory: ActuatorCategory? = nil
    @State private var searchText = ""
    @Environment(PandaTransport.self) private var pandaTransport

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }

    private var filteredActuators: [ActuatorDef] {
        ActuatorRegistry.standardActuators.filter { item in
            if let selectedCategory, item.category != selectedCategory {
                return false
            }
            if !searchText.isEmpty {
                let matchesName = item.name.localizedStandardContains(searchText)
                let matchesSubtitle = item.subtitle.localizedStandardContains(searchText)
                let matchesEcu = item.ecuHeader.localizedStandardContains(searchText)
                return matchesName || matchesSubtitle || matchesEcu
            }
            return true
        }
    }

    init(interface: VehicleInterface, profile: Profile? = nil) {
        self.interface = interface
        self.profile = profile
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Warning / Prerequisites Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.orange)
                        Text("Conditions de Sécurité pour les Tests d'Actionneurs")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Text("1. Moteur impérativement coupé, contact mis (position ON/M).\n2. Frein de stationnement serré, boîte au point mort (P / Neutre).\n3. Éloignez les mains et outils des pièces mobiles (ventilateur, courroies).")
                        .font(.captionText)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.12))
                .clipShape(.rect(cornerRadius: 12))

                // Active Test Banner / Status
                if manager.isExecuting, let active = manager.activeActuator {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.yellow)
                            Text("TEST EN COURS : \(active.name.uppercased())")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(manager.remainingSeconds)s")
                                .font(.title2).bold()
                                .foregroundStyle(Color.appAccent)
                        }

                        if let status = manager.statusMessage {
                            Text(status)
                                .font(.captionText)
                                .foregroundStyle(.secondary)
                        }

                        Button("Arrêter le test (Urgence)", role: .destructive) {
                            Task {
                                await manager.cancelTest(interface: interface)
                            }
                        }
                        .font(.caption).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appAccent, lineWidth: 1.5)
                    }
                    .clipShape(.rect(cornerRadius: 12))
                } else if let nrc = manager.lastNRCError {
                    // NRC Error Banner
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text("Refus Calculateur : \(nrc.title) (0x\(nrc.rawHexCode))")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Text(nrc.explanation)
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                        Text("💡 Conseil : \(nrc.actionAdvice)")
                            .font(.captionText)
                            .bold()
                            .foregroundStyle(Color.appAccent)
                    }
                    .padding()
                    .background(Color.red.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 12))
                } else if let success = manager.executionSuccess, success {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(manager.statusMessage ?? "Test terminé avec succès.")
                            .font(.captionText)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 12))
                }

                // Search & Filter
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Rechercher un actionneur (phares, GMV, combiné...)", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled(true)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 8))

                    // Categories Horizontal Scroll
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            CategoryFilterPill(
                                title: "Tous (\(ActuatorRegistry.standardActuators.count))",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }

                            ForEach(ActuatorCategory.allCases) { cat in
                                let count = ActuatorRegistry.standardActuators.filter { $0.category == cat }.count
                                CategoryFilterPill(
                                    title: "\(cat.rawValue) (\(count))",
                                    icon: cat.iconName,
                                    isSelected: selectedCategory == cat
                                ) {
                                    selectedCategory = cat
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                // Actuators Cards Grid
                LazyVStack(spacing: 12) {
                    ForEach(filteredActuators) { actuator in
                        let isExecutingThis = manager.activeActuator?.id == actuator.id && manager.isExecuting
                        ActuatorCardView(
                            actuator: actuator,
                            isConnected: isConnected,
                            isExecutingThis: isExecutingThis,
                            isAnyExecuting: manager.isExecuting
                        ) {
                            Task {
                                await manager.runActuatorTest(actuator: actuator, interface: interface)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Tests Actionneurs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CategoryFilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.captionTiny)
                    .bold()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.appAccent : Color.white.opacity(0.05))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
