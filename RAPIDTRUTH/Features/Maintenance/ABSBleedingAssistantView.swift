import SwiftUI

struct ABSBleedingAssistantView: View {
    let interface: VehicleInterface
    let manager: MaintenanceManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    
    // Steps definition
    struct BleedStep {
        let title: String
        let description: String
        let actionLabel: String?
        let isPurgeAction: Bool
        let wheelName: String?
    }
    
    private let steps: [BleedStep] = [
        BleedStep(
            title: "Préparation",
            description: "1. Stationnez le véhicule sur un sol plat, serrez le frein à main.\n2. Remplissez le réservoir de liquide de frein à niveau maximum.\n3. Branchez votre purgeur sous pression (recommandé 1.5 bar) ou préparez un assistant pour pomper.\n4. **Ouvrez la vis de purge** de la roue **Arrière Droite** et placez un tuyau de récupération.",
            actionLabel: "Prêt, passer à l'étape suivante",
            isPurgeAction: false,
            wheelName: nil
        ),
        BleedStep(
            title: "Purge Roue Arrière Droite",
            description: "La purge électrique va démarrer. Le groupe hydraulique ABS va pulser le liquide de frein pendant quelques secondes pour chasser l'air.\n\nAssurez-vous que la vis de purge Arrière Droite est bien **ouverte**.",
            actionLabel: "Activer la pompe ABS (Arrière Droite)",
            isPurgeAction: true,
            wheelName: "Arrière Droite"
        ),
        BleedStep(
            title: "Roue Arrière Gauche",
            description: "1. **Fermez la vis de purge** de la roue Arrière Droite.\n2. **Ouvrez la vis de purge** de la roue **Arrière Gauche** et placez le tuyau de récupération.",
            actionLabel: "Prêt, passer à l'étape suivante",
            isPurgeAction: false,
            wheelName: nil
        ),
        BleedStep(
            title: "Purge Roue Arrière Gauche",
            description: "La purge électrique va démarrer sur le circuit arrière gauche.\n\nAssurez-vous que la vis de purge Arrière Gauche est bien **ouverte**.",
            actionLabel: "Activer la pompe ABS (Arrière Gauche)",
            isPurgeAction: true,
            wheelName: "Arrière Gauche"
        ),
        BleedStep(
            title: "Roue Avant Droite",
            description: "1. **Fermez la vis de purge** de la roue Arrière Gauche.\n2. **Ouvrez la vis de purge** de la roue **Avant Droite** et placez le tuyau de récupération.",
            actionLabel: "Prêt, passer à l'étape suivante",
            isPurgeAction: false,
            wheelName: nil
        ),
        BleedStep(
            title: "Purge Roue Avant Droite",
            description: "La purge électrique va démarrer sur le circuit avant droit.\n\nAssurez-vous que la vis de purge Avant Droite est bien **ouverte**.",
            actionLabel: "Activer la pompe ABS (Avant Droite)",
            isPurgeAction: true,
            wheelName: "Avant Droite"
        ),
        BleedStep(
            title: "Roue Avant Gauche",
            description: "1. **Fermez la vis de purge** de la roue Avant Droite.\n2. **Ouvrez la vis de purge** de la roue **Avant Gauche** et placez le tuyau de récupération.",
            actionLabel: "Prêt, passer à l'étape suivante",
            isPurgeAction: false,
            wheelName: nil
        ),
        BleedStep(
            title: "Purge Roue Avant Gauche",
            description: "La purge électrique va démarrer sur le circuit avant gauche.\n\nAssurez-vous que la vis de purge Avant Gauche est bien **ouverte**.",
            actionLabel: "Activer la pompe ABS (Avant Gauche)",
            isPurgeAction: true,
            wheelName: "Avant Gauche"
        ),
        BleedStep(
            title: "Finalisation",
            description: "1. **Fermez toutes les vis de purge**.\n2. Rétablissez le niveau de liquide de frein dans le réservoir.\n3. Pressez fermement la pédale de frein à plusieurs reprises pour vérifier sa dureté.\n4. Effectuez un essai routier prudent pour vous assurer du bon fonctionnement du freinage.",
            actionLabel: "Terminer la procédure",
            isPurgeAction: false,
            wheelName: nil
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
                
                // Diagnostic results feedback
                VStack {
                    if manager.isExecuting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Envoi de la commande ABS (Service 310104)...")
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
                        .glassActionButton(prominent: step.isPurgeAction)
                        .disabled(manager.isExecuting)
                    }
                    
                    if currentStep > 0 {
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
            .navigationTitle("Purge Électrique ABS")
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
    
    private func handleAction(step: BleedStep) async {
        if step.isPurgeAction, let wheel = step.wheelName {
            await manager.purgeABSWheel(interface: interface, wheelName: wheel)
            if manager.errorMessage == nil {
                // Automatically proceed to next step on successful dynamic action
                try? await Task.sleep(for: .seconds(1.5))
                if currentStep < steps.count - 1 {
                    currentStep += 1
                    manager.successMessage = nil
                }
            }
        } else {
            // Static instruction step, just proceed
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
