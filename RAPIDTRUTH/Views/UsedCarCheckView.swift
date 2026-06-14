import SwiftUI

struct UsedCarCheckView: View {
    let interface: VehicleInterface
    @State private var manager = UsedCarCheckManager()
    @Environment(PandaTransport.self) private var pandaTransport
    
    init(interface: VehicleInterface) {
        self.interface = interface
    }
    
    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Main Configuration & Action Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contrôle Anti-Fraude")
                        .font(.cardTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("Cette analyse interroge les calculateurs moteurs (injection), d'habitacle (UCH) et de tableau de bord (TdB) pour détecter toute manipulation d'odomètre ou de VIN.")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    
                    if !isConnected {
                        Label("Outil non connecté. Connectez un adaptateur OBD.", systemImage: "exclamationmark.triangle.fill")
                            .font(.captionText)
                            .foregroundStyle(.orange)
                    }
                    
                    Button(action: {
                        Task {
                            if let panda = interface as? PandaDriver {
                                try? await panda.setSafetyModel(.allOutput)
                            }
                            await manager.runAntiFraudAudit(interface: interface)
                        }
                    }) {
                        Label("Lancer l'Audit Anti-Fraude", systemImage: "shield.checkerboard")
                            .font(.appButton)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(manager.isAuditing || !isConnected)
                    .glassActionButton(prominent: true)
                }
                .appCard()
                
                if manager.isAuditing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.appAccent)
                        Text(manager.currentStep)
                            .font(.captionText)
                            .foregroundStyle(.gray)
                    }
                    .appCard()
                }
                
                if let report = manager.report {
                    // 1. RISK LEVEL BANNER
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: report.riskLevel == .critical ? "exclamationmark.shield.fill" : (report.riskLevel == .high ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"))
                                .font(.title)
                                .foregroundStyle(report.riskLevel == .critical ? .red : (report.riskLevel == .high ? .orange : .green))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                  Text("Évaluation du Risque")
                                    .font(.captionText)
                                    .foregroundStyle(.gray)
                                Text(report.riskLevel.rawValue)
                                    .font(.cardTitle)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Text(report.riskLevel == .critical ? 
                             "ATTENTION : Le kilométrage enregistré dans l'historique des pannes moteur est supérieur au kilométrage affiché au tableau de bord. Cela indique une manipulation frauduleuse de l'odomètre." : 
                             (report.riskLevel == .high ? 
                              "ATTENTION : Les numéros de châssis (VIN) ne concordent pas entre les calculateurs. Cela indique le remplacement non déclaré d'un boîtier électronique." : 
                              "Félicitations : Tous les numéros VIN concordent et aucun kilométrage anormal n'a été détecté dans l'historique d'injection."))
                            .font(.captionText)
                            .foregroundStyle(.gray)
                            .padding(.top, 4)
                    }
                    .appCard()
                    
                    // 2. ODOMETER AUDIT CARD
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Audit Kilométrique")
                            .font(.cardTitle)
                            .foregroundStyle(Color.appAccent)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tableau de Bord")
                                    .font(.captionText)
                                    .foregroundStyle(.gray)
                                Text("\(report.kmTDB.formatted()) km")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Historique Moteur Max")
                                    .font(.captionText)
                                    .foregroundStyle(.gray)
                                Text("\(report.maxKmHistoriquePanne.formatted()) km")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(report.isKmTampered ? .red : .green)
                            }
                        }
                        
                        if report.isKmTampered {
                            HStack {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .foregroundStyle(.red)
                                Text("Écart constaté : \((report.maxKmHistoriquePanne - report.kmTDB).formatted()) km supprimés !")
                                    .font(.captionText)
                                    .bold()
                                    .foregroundStyle(.red)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 6))
                        }
                    }
                    .appCard()
                    
                    // 3. VIN AUDIT CARD
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Audit Numéros Châssis (VIN)")
                            .font(.cardTitle)
                            .foregroundStyle(Color.appAccent)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Calculateur Moteur")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                    Text(report.vinMoteur)
                                        .font(.monoSmall)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tableau de Bord")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                    Text(report.vinTDB)
                                        .font(.monoSmall)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: report.vinMoteur == report.vinTDB ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(report.vinMoteur == report.vinTDB ? .green : .orange)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("UCH (Habitacle)")
                                        .font(.captionText)
                                        .foregroundStyle(.gray)
                                    Text(report.vinUCH)
                                        .font(.monoSmall)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: report.vinMoteur == report.vinUCH ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(report.vinMoteur == report.vinUCH ? .green : .orange)
                            }
                        }
                    }
                    .appCard()
                }
                
                if let error = manager.errorMessage {
                    Text(error)
                        .font(.statusText)
                        .foregroundStyle(.red)
                        .appCard()
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Used Car Check")
        .navigationBarTitleDisplayMode(.inline)
    }
}
