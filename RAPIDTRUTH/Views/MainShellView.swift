import SwiftUI

/// Root view of RAPIDTRUTH — hardwired to the Renault Scenic 2 (M9R) profile.
/// No multi-vehicle management, no onboarding. The app opens directly on the
/// diagnostic dashboard.
struct MainShellView: View {
    let driver: PandaDriver
    private var profileRegistry = ProfileRegistry.shared
    private var session = LoggingSession.shared

    @State private var showConfiguration = false
    @State private var showMaintenance = false

    init(driver: PandaDriver) {
        self.driver = driver
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
                    ConnectionView(driver: driver)

                    // 2 — Diagnostic réseau (DTC tous calculateurs)
                    DiagnosticsView(interface: driver, profile: profile)

                    // 3 — Codage & Configuration
                    HStack(spacing: 12) {
                        Button(action: {
                            showConfiguration = true
                        }) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                Text("Codage & Configuration")
                            }
                            .font(.appButton)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.8))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            showMaintenance = true
                        }) {
                            HStack {
                                Image(systemName: "wrench.fill")
                                Text("Service")
                            }
                            .font(.appButton)
                            .padding()
                            .background(Color.orange.opacity(0.8))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
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
    }
}
