import SwiftUI

struct EPBAssistantView: View {
    let interface: VehicleInterface
    let manager: MaintenanceManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    
    struct EPBStep {
        let title: String
        let description: String
        let actionLabel: String?
        let isEPBAction: Bool
        let actionType: EPBActionType?
    }
    
    enum EPBActionType {
        case open
        case close
    }
    
    private let steps: [EPBStep] = [
        EPBStep(
            title: "Sécurité & Consignes",
            description: "1. Stationnez le véhicule sur un **sol parfaitement plat**.\n2. **Calez les roues avant** de manière sécurisée.\n3. Mettez le contact (+APC), mais **ne démarrez pas le moteur**.\n4. Desserrez manuellement le frein à main à l'aide de la palette habitacle.",
            actionLabel: "Desserre et sécurisé, suivant",
            isEPBAction: false,
            actionType: nil
        ),
        EPBStep(
            title: "Ouverture des Pistons",
            description: "Nous allons envoyer la commande d'ouverture des étriers motorisés arrière.\n\nLes moteurs électriques vont tourner en continu pour reculer complètement les pistons. Un bruit de moteur électrique doit être audible à l'arrière du véhicule.",
            actionLabel: "Reculer les pistons (Mode Atelier)",
            isEPBAction: true,
            actionType: .open
        ),
        EPBStep(
            title: "Remplacement des Organes",
            description: "Les pistons sont maintenant reculés. Vous pouvez en toute sécurité :\n\n1. Déposer les étriers arrière.\n2. Remplacer les plaquettes et/ou les disques de frein.\n3. Repousser manuellement le piston (il doit reculer sans effort mécanique car le moteur est en butée arrière).\n4. Remonter l'étrier avec les nouvelles plaquettes.\n\n⚠️ IMPORTANT : Ne coupez pas le contact (+APC) et ne débranchez pas l'interface OBD pendant l'intervention physique, afin de conserver la session de diagnostic active pour le calibrage final.",
            actionLabel: "Remplacement effectué, suivant",
            isEPBAction: false,
            actionType: nil
        ),
        EPBStep(
            title: "Serrage & Calibrage",
            description: "Les nouveaux freins étant en place, nous allons fermer et calibrer le système.\n\nLes moteurs électriques arrière vont serrer les nouvelles plaquettes pour enregistrer le point de contact et la nouvelle épaisseur.",
            actionLabel: "Fermer & Calibrer le frein arrière",
            isEPBAction: true,
            actionType: .close
        ),
        EPBStep(
            title: "Opération Terminée",
            description: "La procédure de calibrage est terminée.\n\n1. Actionnez la palette de frein de stationnement dans l'habitacle pour vérifier le serrage et le desserrage.\n2. Assurez-vous qu'aucun témoin d'anomalie de freinage ne reste allumé au tableau de bord.\n3. Retirez les cales de roues avant d'effectuer un essai routier.",
            actionLabel: "Quitter l'assistant",
            isEPBAction: false,
            actionType: nil
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Progress view
                VStack(spacing: 8) {
                    ProgressView(value: Double(currentStep), total: Double(steps.count - 1))
                        .tint(Color.appAccent)
                    
                    HStack {
                        Text("Étape \(currentStep + 1) sur \(steps.count)")
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int((Double(currentStep) / Double(steps.count - 1)) * 100))%")
                            .font(.monoSmall)
                            .foregroundStyle(Color.appAccent)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Active Step Content
                let step = steps[currentStep]
                VStack(alignment: .leading, spacing: 16) {
                    Text(step.title)
                        .font(.stepTitle)
                        .bold()
                        .foregroundStyle(.white)
                    
                    Text(step.description)
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
                .padding(.horizontal)
                
                // Feedback
                VStack {
                    if manager.isExecuting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Envoi de la commande FPA (Service 3101)...")
                                .font(.statusText)
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    } else if let error = manager.errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.statusText)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 8))
                    } else if let success = manager.successMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(success)
                                .font(.statusText)
                                .foregroundStyle(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
                .frame(height: 70)
                
                Spacer()
                
                // Bottom control actions
                VStack(spacing: 12) {
                    if let label = step.actionLabel {
                        Button(action: {
                            Task {
                                await handleAction(step: step)
                            }
                        }) {
                            Text(label)
                                .frame(maxWidth: .infinity)
                        }
                        .font(.appButton)
                        .glassActionButton(prominent: step.isEPBAction)
                        .disabled(manager.isExecuting)
                    }
                    
                    if currentStep > 0 && currentStep < steps.count - 1 {
                        Button("Retour à l'étape précédente") {
                            currentStep -= 1
                            manager.errorMessage = nil
                            manager.successMessage = nil
                        }
                        .font(.captionText)
                        .foregroundStyle(.secondary)
                        .disabled(manager.isExecuting)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Atelier Frein Électrique (FPA)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Quitter") {
                        dismiss()
                    }
                    .font(.captionText)
                    .foregroundStyle(.red)
                    .disabled(manager.isExecuting)
                }
            }
        }
    }
    
    private func handleAction(step: EPBStep) async {
        if step.isEPBAction, let type = step.actionType {
            switch type {
            case .open:
                await manager.enterEPBMaintenanceMode(interface: interface)
            case .close:
                await manager.exitEPBMaintenanceMode(interface: interface)
            }
            
            if manager.errorMessage == nil {
                try? await Task.sleep(for: .seconds(1.5))
                if currentStep < steps.count - 1 {
                    currentStep += 1
                    manager.successMessage = nil
                }
            }
        } else {
            manager.errorMessage = nil
            manager.successMessage = nil
            if currentStep < steps.count - 1 {
                currentStep += 1
            } else {
                dismiss()
            }
        }
    }
}
