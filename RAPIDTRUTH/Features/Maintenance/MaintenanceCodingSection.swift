import SwiftUI
import SwiftVehicleProtocols

struct MaintenanceCodingSection: View {
    let interface: VehicleInterface
    let isConnected: Bool
    @Bindable var maintenanceManager: MaintenanceManager
    @Binding var isExpanded: Bool

    @State private var showingSSPPAlert = false
    @State private var ssppTargetState = false
    
    @State private var showingHeadlightsAlert = false
    @State private var headlightsTargetState = false
    
    @State private var showingReverseWiperAlert = false
    @State private var reverseWiperTargetState = false
    
    @State private var showingSeatbeltAlert = false
    @State private var seatbeltTargetState = false
    
    @State private var showingAirbagAlert = false
    @State private var airbagTargetState = false
    
    @State private var selectedKMIndex = 0
    let kmOptions = [10000, 15000, 20000, 30000]
    @State private var selectedMonthIndex = 0
    let monthOptions = [12, 24]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // SSPP
                VStack(alignment: .leading, spacing: 6) {
                    Text("Configuration SSPP (Valves)")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Activer") {
                            ssppTargetState = true
                            showingSSPPAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.green)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        
                        Button("Désactiver") {
                            ssppTargetState = false
                            showingSSPPAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.red)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }
                .alert("Modification Configuration SSPP", isPresented: $showingSSPPAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Confirmer", role: .destructive) {
                        Task { await maintenanceManager.setSSPPEnabled(interface: interface, enabled: ssppTargetState) }
                    }
                } message: {
                    Text(ssppTargetState ? "Confirmez-vous l'activation du système de surveillance de pression de pneus ?" : "Confirmez-vous la désactivation ? Tous les voyants de pneu manquant et alertes de crevaison s'éteindront définitivement.")
                }

                Divider().background(Color.white.opacity(0.05))

                // Feux Automatiques
                VStack(alignment: .leading, spacing: 6) {
                    Text("Allumage Automatique des Feux")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Activer") {
                            headlightsTargetState = true
                            showingHeadlightsAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.green)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        
                        Button("Désactiver") {
                            headlightsTargetState = false
                            showingHeadlightsAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.red)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }
                .alert("Configuration Feux Automatiques", isPresented: $showingHeadlightsAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Confirmer", role: .destructive) {
                        Task { await maintenanceManager.setAutoHeadlightsEnabled(interface: interface, enabled: headlightsTargetState) }
                    }
                } message: {
                    Text(headlightsTargetState ? "Confirmez-vous l'activation de l'allumage automatique des feux de croisement ?" : "Confirmez-vous sa désactivation ? Les feux ne s'allumeront plus automatiquement à la tombée de la nuit.")
                }

                Divider().background(Color.white.opacity(0.05))

                // Essuie-glace Arrière Auto
                VStack(alignment: .leading, spacing: 6) {
                    Text("Essuie-glace Arrière en Marche Arrière")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Activer") {
                            reverseWiperTargetState = true
                            showingReverseWiperAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.green)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        
                        Button("Désactiver") {
                            reverseWiperTargetState = false
                            showingReverseWiperAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.red)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }
                .alert("Configuration Essuyage Arrière", isPresented: $showingReverseWiperAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Confirmer", role: .destructive) {
                        Task { await maintenanceManager.setReverseWiperEnabled(interface: interface, enabled: reverseWiperTargetState) }
                    }
                } message: {
                    Text(reverseWiperTargetState ? "Confirmez-vous l'activation du balayage automatique arrière lors de la marche arrière ?" : "Confirmez-vous sa désactivation ?")
                }

                Divider().background(Color.white.opacity(0.05))

                // Bip Ceinture
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alerte Sonore Ceinture Non Bouclée")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Activer") {
                            seatbeltTargetState = true
                            showingSeatbeltAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.green)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        
                        Button("Désactiver") {
                            seatbeltTargetState = false
                            showingSeatbeltAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.red)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }
                .alert("Configuration Alerte Ceinture", isPresented: $showingSeatbeltAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Confirmer", role: .destructive) {
                        Task { await maintenanceManager.setSeatbeltBuzzerEnabled(interface: interface, enabled: seatbeltTargetState) }
                    }
                } message: {
                    Text(seatbeltTargetState ? "Confirmez-vous l'activation du bip sonore de ceinture non bouclée ?" : "Confirmez-vous la désactivation ? Le voyant visuel restera actif mais aucun son ne retentira.")
                }

                Divider().background(Color.white.opacity(0.05))

                // Ralenti
                VStack(alignment: .leading, spacing: 6) {
                    Text("Régulation du Ralenti dCi")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("+50 tr/min") {
                            Task { await maintenanceManager.adjustIdleSpeed(interface: interface, increase: true) }
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        
                        Button("-50 tr/min") {
                            Task { await maintenanceManager.adjustIdleSpeed(interface: interface, increase: false) }
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }

                Divider().background(Color.white.opacity(0.05))

                // Vidange Perso
                VStack(alignment: .leading, spacing: 6) {
                    Text("Périodicité Vidange Personnalisée")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("Distance", selection: $selectedKMIndex) {
                            ForEach(0..<kmOptions.count, id: \.self) { index in
                                Text("\(kmOptions[index]) km").tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maintenanceManager.isExecuting)
                        
                        Picker("Durée", selection: $selectedMonthIndex) {
                            ForEach(0..<monthOptions.count, id: \.self) { index in
                                Text("\(monthOptions[index]) mois").tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(maintenanceManager.isExecuting)
                        
                        Spacer()
                        
                        Button("Écrire") {
                            let targetKM = kmOptions[selectedKMIndex]
                            let targetMonths = monthOptions[selectedMonthIndex]
                            Task {
                                await maintenanceManager.setOilServicePeriodicity(interface: interface, intervalKM: targetKM, intervalMonths: targetMonths)
                            }
                        }
                        .font(.captionText)
                        .glassActionButton(prominent: true)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }

                Divider().background(Color.white.opacity(0.05))

                // Airbag
                VStack(alignment: .leading, spacing: 6) {
                    Text("Verrouillage de l'Airbag (Mode Atelier)")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Sécuriser (Verrouiller)") {
                            airbagTargetState = true
                            showingAirbagAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.red)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                        
                        Button("Réactiver (Déverrouiller)") {
                            airbagTargetState = false
                            showingAirbagAlert = true
                        }
                        .font(.captionText)
                        .glassActionButton()
                        .foregroundStyle(.green)
                        .disabled(!isConnected || maintenanceManager.isExecuting)
                    }
                }
                .alert("Modification État Airbag", isPresented: $showingAirbagAlert) {
                    Button("Annuler", role: .cancel) { }
                    Button("Confirmer", role: .destructive) {
                        Task { await maintenanceManager.setAirbagLocked(interface: interface, locked: airbagTargetState) }
                    }
                } message: {
                    Text(airbagTargetState ? "Voulez-vous verrouiller le calculateur ? Toutes les lignes de tir seront désactivées pour les travaux physiques d'atelier." : "Voulez-vous déverrouiller le calculateur ? Le système d'airbags sera réactivé et prêt à protéger en route.")
                }
            }
            .padding(.vertical, 8)
        } label: {
            Text("Télécodage & Personnalisation")
                .font(.valueLabel)
                .foregroundStyle(.white)
        }
    }
}
