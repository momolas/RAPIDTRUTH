import SwiftUI

enum DongleType: String, CaseIterable, Identifiable {
    case panda = "White Panda (Wi-Fi)"
    case elm327 = "ELM327 (BLE)"
    var id: String { self.rawValue }
}

struct MainShellView: View {
    let driver: VehicleInterface
    @Binding var selectedDongle: DongleType
    
    private var profileRegistry = ProfileRegistry.shared
    private var session = LoggingSession.shared

    @State private var showConfiguration = false
    @State private var showMaintenance = false
    @State private var showFuzzer = false

    init(driver: VehicleInterface, selectedDongle: Binding<DongleType>) {
        self.driver = driver
        self._selectedDongle = selectedDongle
    }

    /// Always resolves to the Scenic 2 profile. If for some reason the bundle
    /// is missing it, we fall back to the first available profile so the UI
    /// never crashes.
    private var profile: Profile {
        profileRegistry.profile(id: "renault_scenic2_m9r722")
            ?? profileRegistry.profiles.first!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 0) {
                            Text("RAPID").foregroundStyle(.white)
                            Text("/TRUTH").foregroundStyle(Color(red: 92 / 255, green: 196 / 255, blue: 1.0))
                        }
                        .font(.appBrand)
                        
                        Spacer()
                    }

                    if let error = profileRegistry.loadError {
                        Text("Profile error: \(error)")
                            .font(.statusText)
                            .foregroundStyle(.red)
                    }

                    // 1 — Connexion
                    ConnectionView(driver: driver, selectedDongle: $selectedDongle)

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
                        
                        Button(action: {
                            showFuzzer = true
						}, label: {
                            HStack {
                                Image(systemName: "ladybug.fill")
                                Text("Fuzzer OBD (Avancé)")
                            }
                            .font(.appButton)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundStyle(.white)
							.clipShape(.rect(cornerRadius: 5))
                        })
                    }

                    // 5 — Données temps réel
                    LiveReadoutView()

                    // 6 — Sessions enregistrées
                    SessionsListView()
                }
                .padding(16)
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
    }
}
