import SwiftUI

struct MaintenanceView: View {
    let interface: VehicleInterface
    @State private var maintenanceManager = MaintenanceManager()
    @State private var mapManager = ECUMapManager()
    @Environment(PandaTransport.self) private var pandaTransport
    
    @State private var showingABSWizard = false
    @State private var showingEPBWizard = false
    @State private var selectedBackupURL: URL? = nil

    @State private var isOilExpanded = true
    @State private var isBrakesExpanded = false
    @State private var isExhaustExpanded = false
    @State private var isCodingExpanded = false
    @State private var isActuatorsExpanded = false
    @State private var isFlashingExpanded = false

    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }

    init(interface: VehicleInterface) {
        self.interface = interface
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !isConnected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Outil non connecté. Connectez un adaptateur OBD.")
                            .font(.captionText)
                            .foregroundStyle(.gray)
                    }
                    .appCard()
                }

                if let error = maintenanceManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.statusText)
                        .padding(.horizontal, 16)
                }

                if let success = maintenanceManager.successMessage {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.statusText)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // 1. Vidange & Entretien
                    MaintenanceOilSection(
                        interface: interface,
                        isConnected: isConnected,
                        maintenanceManager: maintenanceManager,
                        isExpanded: $isOilExpanded
                    )

                    Divider().background(Color.white.opacity(0.1))

                    // 2. Freinage & Purge ABS / EPB
                    MaintenanceBrakesSection(
                        interface: interface,
                        isConnected: isConnected,
                        maintenanceManager: maintenanceManager,
                        isExpanded: $isBrakesExpanded,
                        showingEPBWizard: $showingEPBWizard,
                        showingABSWizard: $showingABSWizard
                    )

                    Divider().background(Color.white.opacity(0.1))

                    // 3. Échappement & FAP
                    MaintenanceExhaustSection(
                        interface: interface,
                        isConnected: isConnected,
                        maintenanceManager: maintenanceManager,
                        isExpanded: $isExhaustExpanded
                    )

                    Divider().background(Color.white.opacity(0.1))

                    // 4. Télécodage & Personnalisation
                    MaintenanceCodingSection(
                        interface: interface,
                        isConnected: isConnected,
                        maintenanceManager: maintenanceManager,
                        isExpanded: $isCodingExpanded
                    )

                    Divider().background(Color.white.opacity(0.1))

                    // 5. Test des Actionneurs
                    MaintenanceActuatorsSection(
                        interface: interface,
                        isConnected: isConnected,
                        maintenanceManager: maintenanceManager,
                        isExpanded: $isActuatorsExpanded
                    )

                    Divider().background(Color.white.opacity(0.1))

                    // 6. Reprogrammation & Cartographie
                    MaintenanceFlashingSection(
                        interface: interface,
                        isConnected: isConnected,
                        mapManager: mapManager,
                        isExpanded: $isFlashingExpanded,
                        selectedBackupURL: $selectedBackupURL
                    )
                }
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Fonctions de Service")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingABSWizard) {
            ABSBleedingAssistantView(interface: interface, manager: maintenanceManager)
        }
        .sheet(isPresented: $showingEPBWizard) {
            EPBAssistantView(interface: interface, manager: maintenanceManager)
        }
        .task {
            mapManager.refreshBackupList()
            selectedBackupURL = mapManager.backupFiles.first
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
                NSLog("[MaintenanceView] Switched Panda safety model to ALLOUTPUT for service operations")
            }
        }
        .onDisappear {
            if let panda = interface as? PandaDriver {
                Task {
                    try? await panda.setSafetyModel(.allOutput)
                    NSLog("[MaintenanceView] Kept Panda safety model as ALLOUTPUT")
                }
            }
        }
    }
}
