import SwiftUI

enum DongleType: String, CaseIterable, Identifiable {
    case panda = "White Panda (Wi-Fi)"
    var id: String { self.rawValue }
}

struct MainShellView: View {
    let driver: VehicleInterface
    
    @Environment(SettingsStore.self) private var settings
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(ProfileRegistry.self) private var profileRegistry

    @State private var showConfiguration = false
    @State private var showMaintenance = false
    @State private var showFuzzer = false
    @State private var showUsedCarCheck = false

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
        return profileRegistry.profile(id: "renault_scenic2_m9r722")
            ?? profileRegistry.profiles.first!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AdaptiveGlassEffectContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 0) {
                            Text("RAPID").foregroundStyle(.white)
                            Text("/TRUTH").foregroundStyle(Color.appAccent)
                        }
                        .font(.appBrand)
                        
                        Spacer()
                    }

                    if let error = profileRegistry.loadError {
                        Text("Profile error: \(error)")
                            .font(.statusText)
                            .foregroundStyle(.red)
                    }

                    // Vehicle Profile & Discovery Card
                    VehicleCardView(driver: driver)

                    // 1 — Connexion
                    ConnectionView(driver: driver)

                    // 1.5 — Session Logging Controls
                    //LoggingControlsView(driver: driver)

                    // 2 — Diagnostic réseau (DTC tous calculateurs)
                    DiagnosticsView(interface: driver, profile: profile)

                    // 3 — Codage & Configuration & Service & Fuzzer
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: {
                                showConfiguration = true
							}, label: {
                                HStack {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                    Text("Codage & Configuration")
                                }
                                .font(.appButton)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.8))
                                .foregroundStyle(.white)
								.clipShape(.rect(cornerRadius: 5))
                            })

                            Button(action: {
                                showMaintenance = true
							}, label: {
                                HStack {
                                    Image(systemName: "wrench.fill")
                                    Text("Service")
                                }
                                .font(.appButton)
                                .padding()
                                .background(Color.orange.opacity(0.8))
                                .foregroundStyle(.white)
								.clipShape(.rect(cornerRadius: 5))
                            })
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                showFuzzer = true
							}, label: {
                                HStack {
                                    Image(systemName: "ladybug.fill")
                                    Text("Fuzzer OBD")
                                }
                                .font(.appButton)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundStyle(.white)
                                .clipShape(.rect(cornerRadius: 5))
                            })

                            Button(action: {
                                showUsedCarCheck = true
							}, label: {
                                HStack {
                                    Image(systemName: "shield.checkerboard")
                                    Text("Used Car Check")
                                }
                                .font(.appButton)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent.opacity(0.8))
                                .foregroundStyle(.white)
                                .clipShape(.rect(cornerRadius: 5))
                            })
                        }
                    }
                }
                .padding(16)
            }
        }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView(interface: driver)
        }
        .sheet(isPresented: $showMaintenance) {
            MaintenanceView(interface: driver)
        }
        .sheet(isPresented: $showFuzzer) {
            FuzzerView(interface: driver)
        }
        .sheet(isPresented: $showUsedCarCheck) {
            UsedCarCheckView(interface: driver)
        }
    }
}
