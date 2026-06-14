import SwiftUI

struct ConnectionView: View {
    @Environment(PandaTransport.self) private var pandaTransport
    @Environment(SettingsStore.self) private var settings
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(ProfileRegistry.self) private var profileRegistry
    
    let driver: VehicleInterface
    
    @State private var statusError: String?
    @State private var isVehicleConnected = false
    @State private var detectedVin: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ConnectionStatusBadge(
                    isConnected: isConnected,
                    isConnecting: isConnecting,
                    isIdleOrError: isIdleOrError,
                    isVehicleConnected: isVehicleConnected
                )
                Spacer()
                ConnectionActionButton(
                    isConnecting: isConnecting,
                    isIdleOrError: isIdleOrError,
                    onConnect: {
                        statusError = nil
                        Task { await connectPanda() }
                    },
                    onDisconnect: {
                        disconnectAdapter()
                    }
                )
            }
            
            if isConnected {
                Divider().background(Color.white.opacity(0.05))
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(isVehicleConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isVehicleConnected ? "Lien Véhicule Établi" : "En attente du véhicule...")
                            .font(.captionText).bold()
                            .foregroundStyle(.white)
                        
                        if let detectedVin {
                            Text("VIN : \(detectedVin)")
                                .font(.monoTiny)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Mettez le contact (+APC) pour démarrer l'analyse.")
                                .font(.captionTiny)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !isVehicleConnected {
                        Button("Actualiser", systemImage: "arrow.clockwise") {
                            statusError = nil
                            Task { await detectVehicle() }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.appAccent)
                    }
                }
                .padding(.top, 4)
            }
            
            if let statusError {
                Text(statusError)
                    .font(.statusText)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.08))
            }
        }
        .appCard()
    }
    
    // MARK: - State Helpers
    
    private var isConnected: Bool {
        pandaTransport.state == .connected
    }
    
    private var isConnecting: Bool {
        pandaTransport.state == .connecting
    }
    
    private var isIdleOrError: Bool {
        !isConnected && !isConnecting
    }

    private func connectPanda(ip: String? = nil) async {
        pandaTransport.connect(host: ip)
        var timeout = 0
        while isConnecting && timeout < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            timeout += 1
        }
        
        if isConnected {
            await detectVehicle()
        } else {
            if case .error(let message) = pandaTransport.state {
                statusError = "Connection error: \(message)"
            } else {
                statusError = "Connection timeout. Please ensure you are connected to the Panda's Wi-Fi network (SSID: panda-XXXXXX) and cellular data is disabled."
            }
            disconnectAdapter()
        }
    }
    
    private func disconnectAdapter() {
        if let panda = driver as? PandaDriver {
            panda.detach()
        }
        pandaTransport.disconnect()
        isVehicleConnected = false
        detectedVin = nil
    }

    private func detectVehicle() async {
        do {
            if let panda = driver as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            
            guard let vin = try await VINReader.read(interface: driver) else {
                throw NSError(domain: "ConnectionView", code: -2, userInfo: [NSLocalizedDescriptionKey: "VIN non détecté"])
            }
            
            detectedVin = vin
            isVehicleConnected = true
            
            // If known, set as active
            if let known = vehicleStore.vehicles.first(where: { $0.vin == vin }) {
                settings.activeVehicleSlug = known.slug
                return
            }
            
            // If unknown, decode and save
            let service = getActiveDecoderService(settings: settings)
            let decoded = try await service.decode(vin: vin)
            
            let yearInt = decoded.year ?? 0
            let slug = Vehicle.makeSlug(year: yearInt, make: decoded.make, model: decoded.model)
            
            // Fallback slug if empty
            let finalSlug = slug.isEmpty ? "unknown-vehicle-\(vin.prefix(6).lowercased())" : slug
            
            let suggestedProfile = profileRegistry.suggestedProfile(make: decoded.make, year: yearInt)
            
            let vehicle = Vehicle(
                slug: finalSlug,
                owner: settings.owner,
                displayName: Vehicle.makeDisplayName(year: yearInt, make: decoded.make, model: decoded.model, trim: decoded.trim),
                year: yearInt,
                make: decoded.make.isEmpty ? nil : decoded.make,
                model: decoded.model.isEmpty ? nil : decoded.model,
                trim: decoded.trim.isEmpty ? nil : decoded.trim,
                vin: vin,
                profileId: suggestedProfile.profileId,
                profileVersion: suggestedProfile.profileVersion,
                createdAtUTC: Date.now.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: TimeZone(secondsFromGMT: 0)!)),
                lastUsedUTC: nil,
                supportedStandardPIDs: [],
                supportedProfilePIDs: [],
                disabledPIDs: []
            )
            
            try vehicleStore.save(vehicle)
            settings.activeVehicleSlug = vehicle.slug
        } catch {
            isVehicleConnected = false
            detectedVin = nil
            statusError = "Véhicule non détecté. Assurez-vous que la voiture est sous contact (+APC)."
            NSLog("[ConnectionView] Auto-detect failed: \(error)")
        }
    }
}

struct ConnectionStatusBadge: View {
    @Environment(PandaTransport.self) private var pandaTransport
    
    let isConnected: Bool
    let isConnecting: Bool
    let isIdleOrError: Bool
    let isVehicleConnected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(badgeColor)
                .frame(width: 10, height: 10)
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

struct ConnectionActionButton: View {
    let isConnecting: Bool
    let isIdleOrError: Bool
    
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        if isIdleOrError {
            Button("Connect Panda", action: onConnect)
                .glassActionButton(prominent: true)
                .controlSize(.small)
        } else if isConnecting {
            Button("Cancel", action: onDisconnect)
                .glassActionButton(prominent: false)
                .controlSize(.small)
        } else {
            Button("Disconnect", action: onDisconnect)
                .glassActionButton(prominent: false)
                .controlSize(.small)
        }
    }
}

#Preview {
    ConnectionView(driver: PandaDriver())
        .environment(SettingsStore.shared)
        .environment(PandaTransport.shared)
        .environment(VehicleStore.shared)
        .environment(ProfileRegistry.shared)
}
