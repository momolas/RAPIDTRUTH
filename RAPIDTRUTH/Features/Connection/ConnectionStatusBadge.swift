import SwiftUI

struct ConnectionStatusBadge: View {
    @Environment(PandaTransport.self) private var pandaTransport
    
    let isConnected: Bool
    let isConnecting: Bool
    let isIdleOrError: Bool
    let isVehicleConnected: Bool

    @State private var isAnimating = false

    private var shouldPulse: Bool {
        isConnecting || (isConnected && !isVehicleConnected)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(badgeColor)
                .frame(width: 10, height: 10)
                .scaleEffect(shouldPulse && isAnimating ? 1.25 : 1.0)
                .opacity(shouldPulse && isAnimating ? 0.6 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stateTitle)
                        .font(.valueNumber)
                }
                Text(stateSubtitle)
                    .font(.captionText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stateTitle: String {
        if isIdleOrError { return "Déconnecté" }
        if isConnecting { return "Connexion..." }
        if isVehicleConnected { return "Véhicule Connecté" }
        return "Panda Connecté"
    }

    private var stateSubtitle: String {
        if isIdleOrError {
            if case .error(let e) = pandaTransport.state { return e }
            return "Sélectionnez Connecter pour démarrer."
        }
        if isConnecting { return "Établissement du lien..." }
        if isVehicleConnected { return "Lien OBD/CAN actif avec le calculateur" }
        return "Panda OK, contact (+APC) manquant"
    }

    private var badgeColor: Color {
        if isIdleOrError {
            let hasError = pandaTransport.state != .idle
            return hasError ? .red : .secondary
        }
        if isConnecting { return .blue }
        if isVehicleConnected { return .green }
        return .orange
    }
}
