import SwiftUI

struct ConnectionView: View {
    @Environment(PandaTransport.self) private var pandaTransport
    let driver: PandaDriver
    
    @State private var statusError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                statusBadge
                Spacer()
                connectionButton
            }
            
            if let statusError {
                Text(statusError)
                    .font(.statusText)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .appCard()
    }

    private var statusBadge: some View {
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

    @ViewBuilder
    private var connectionButton: some View {
        switch pandaTransport.state {
        case .idle, .error:
            Button("Connect Panda") {
                statusError = nil
                Task { await connectPanda() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .connecting:
            Button("Cancel") { pandaTransport.disconnect() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .connected:
            Button("Disconnect") {
                driver.detach()
                pandaTransport.disconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var stateTitle: String {
        switch pandaTransport.state {
        case .idle: return "idle"
        case .connecting: return "connecting → UDP 1337"
        case .connected: return "connected: Panda CAN"
        case .error: return "error"
        }
    }

    private var stateSubtitle: String {
        switch pandaTransport.state {
        case .idle: return "Tap Connect Panda to start."
        case .connecting: return "Establishing Panda UDP connection..."
        case .connected: return "Connected via Panda Native Protocol"
        case .error(let msg): return msg
        }
    }

    private var badgeColor: Color {
        switch pandaTransport.state {
        case .idle: return .secondary
        case .connecting: return .blue
        case .connected: return .green
        case .error: return .red
        }
    }

    private func connectPanda() async {
        pandaTransport.connect()
        // Wait for state
        var timeout = 0
        while pandaTransport.state == .connecting && timeout < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            timeout += 1
        }
        
        if pandaTransport.state == .connected {
            driver.attach()
            await detectVehicle()
        } else if case .error(let msg) = pandaTransport.state {
            statusError = msg
        } else {
            statusError = "Connection timeout"
            pandaTransport.disconnect()
        }
    }

    private func detectVehicle() async {
        guard let vin = try? await VINReader.read(interface: driver) else { return }
        
        let settings = SettingsStore.shared
        let vehicleStore = VehicleStore.shared
        
        // If known, set as active
        if let known = vehicleStore.vehicles.first(where: { $0.vin == vin }) {
            settings.activeVehicleSlug = known.slug
            return
        }
        
        // If unknown, decode and save
        do {
            let service = getActiveDecoderService()
            let decoded = try await service.decode(vin: vin)
            
            let yearInt = decoded.year ?? 0
            let slug = Vehicle.makeSlug(year: yearInt, make: decoded.make, model: decoded.model)
            
            // Fallback slug if empty
            let finalSlug = slug.isEmpty ? "unknown-vehicle-\(vin.prefix(6).lowercased())" : slug
            
            let profileRegistry = ProfileRegistry.shared
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
                createdAtUTC: ISO8601DateFormatter.utcMs.string(from: Date()),
                lastUsedUTC: nil,
                supportedStandardPIDs: [],
                supportedProfilePIDs: [],
                disabledPIDs: []
            )
            
            try vehicleStore.save(vehicle)
            settings.activeVehicleSlug = vehicle.slug
        } catch {
            NSLog("[ConnectionView] Auto-detect failed to decode or save: \(error)")
        }
    }
}
