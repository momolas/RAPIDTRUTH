import SwiftUI

enum DiagnosticDestination: Hashable, Sendable {
    case diagnostics
    case liveData
    case configuration
    case maintenance
    case fuzzer
    case usedCarCheck
    case logs
}

struct MainShellView: View {
    let driver: VehicleInterface
    
    @Environment(SettingsStore.self) private var settings
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(ProfileRegistry.self) private var profileRegistry
    @Environment(PandaTransport.self) private var pandaTransport
    
    @State private var navigationPath = NavigationPath()

    init(driver: VehicleInterface) {
        self.driver = driver
    }

    /// Dynamically resolves the active profile from the selected active vehicle,
    /// falling back to the Scenic 2 profile if none is active or found.
    private var profile: Profile {
        if let slug = settings.activeVehicleSlug,
           let vehicle = vehicleStore.vehicles.first(where: { $0.slug == slug }),
           let prof = profileRegistry.profile(id: vehicle.profileId) {
            return prof
        }
        return profileRegistry.profile(id: "renault_scenic2_multi_ecu")
            ?? profileRegistry.profiles.first
            ?? Profile.fallback
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                AdaptiveGlassEffectContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
						Text("RAPIDTRUTH")
							.font(.appBrand)

                        if let error = profileRegistry.loadError {
                            Text("Profile error: \(error)")
                                .font(.statusText)
                                .foregroundStyle(.red)
                        }

                        // Vehicle Profile & Discovery Card
                        VehicleCardView(driver: driver)

                        // 1 — Connexion
                        ConnectionView(driver: driver)

                        // Menu showing modules when connected
                        if case .connected = pandaTransport.state {
                            Text("Modules de Diagnostic")
                                .font(.cardTitle)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            
                            NavigationLink(value: DiagnosticDestination.diagnostics) {
                                DiagnosticMenuCard(
                                    title: "Diagnostic Réseau (DTC)",
                                    subtitle: "Lecture et effacement des codes défauts",
                                    systemImage: "exclamationmark.shield.fill",
                                    color: .red
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(value: DiagnosticDestination.liveData) {
                                DiagnosticMenuCard(
                                    title: "Données Temps Réel",
                                    subtitle: "Lecture en direct des capteurs et sondes",
                                    systemImage: "chart.xyaxis.line",
                                    color: .blue
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(value: DiagnosticDestination.configuration) {
                                DiagnosticMenuCard(
                                    title: "Codage & Configuration",
                                    subtitle: "Personnalisation des options TdB, UCH et UPC",
                                    systemImage: "slider.horizontal.3",
                                    color: Color.appAccent
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(value: DiagnosticDestination.maintenance) {
                                DiagnosticMenuCard(
                                    title: "Fonctions de Service",
                                    subtitle: "Vidange, EPB, purge ABS et reprogrammation moteur",
                                    systemImage: "wrench.and.screwdriver.fill",
                                    color: .orange
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(value: DiagnosticDestination.fuzzer) {
                                DiagnosticMenuCard(
                                    title: "Fuzzer OBD & Corrélation",
                                    subtitle: "Balayage de LIDs et reverse engineering en temps réel",
                                    systemImage: "waveform.path.ecg",
                                    color: .purple
                                )
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(value: DiagnosticDestination.usedCarCheck) {
                                DiagnosticMenuCard(
                                    title: "Used Car Check",
                                    subtitle: "Audit odomètre anti-fraude et contrôle des VINs",
                                    systemImage: "shield.checkerboard",
                                    color: .green
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text("Outils & Debug")
                            .font(.cardTitle)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        
                        NavigationLink(value: DiagnosticDestination.logs) {
                            DiagnosticMenuCard(
                                title: "Logs de Communication",
                                subtitle: "Trames KWP2000 brutes TX/RX en temps réel",
                                systemImage: "doc.text.magnifyingglass",
                                color: .gray
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationDestination(for: DiagnosticDestination.self) { destination in
                switch destination {
                case .diagnostics:
                    DiagnosticsView(interface: driver, profile: profile)
                case .liveData:
                    LiveDataView(interface: driver, profile: profile)
                case .configuration:
                    ConfigurationView(interface: driver)
                case .maintenance:
                    MaintenanceView(interface: driver)
                case .fuzzer:
                    FuzzerView(interface: driver)
                case .usedCarCheck:
                    UsedCarCheckView(interface: driver)
                case .logs:
                    LogsView()
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

struct DiagnosticMenuCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.valueLabel)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.captionText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .appCard()
    }
}
