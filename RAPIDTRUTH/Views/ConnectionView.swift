import SwiftUI

struct ConnectionView: View {
    @Environment(PandaTransport.self) private var pandaTransport
    @Environment(BLEManager.self) private var bleManager
    @Environment(SettingsStore.self) private var settings
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(ProfileRegistry.self) private var profileRegistry
    
    let driver: VehicleInterface
    @Binding var selectedDongle: DongleType
    
    @State private var statusError: String?
    @State private var showDevicePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Dongle", selection: $selectedDongle) {
                ForEach(DongleType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isConnecting || isConnected)
            
            HStack(alignment: .top) {
                ConnectionStatusBadge(
                    selectedDongle: selectedDongle,
                    isConnected: isConnected,
                    isConnecting: isConnecting,
                    isIdleOrError: isIdleOrError
                )
                Spacer()
                ConnectionActionButton(
                    selectedDongle: selectedDongle,
                    isConnecting: isConnecting,
                    isIdleOrError: isIdleOrError,
                    onConnect: {
                        statusError = nil
                        if selectedDongle == .panda {
                            Task { await connectPanda() }
                        } else {
                            showDevicePicker = true
                        }
                    },
                    onDisconnect: {
                        disconnectAdapter()
                    }
                )
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
        .sheet(isPresented: $showDevicePicker) {
            DevicePickerView(
                dongleType: selectedDongle,
                onPickBLE: { device in
                    Task {
                        do {
                            _ = try await bleManager.connect(device)
                            await finishElmConnection()
                        } catch {
                            statusError = error.localizedDescription
                        }
                    }
                },
                onPickWiFi: { ip in
                    Task {
                        await connectPanda(ip: ip)
                    }
                }
            )
        }
    }
    
    // MARK: - State Helpers
    
    private var isConnected: Bool {
        if selectedDongle == .panda {
            return pandaTransport.state == .connected
        } else {
            if case .connected = bleManager.connectionState { return true }
            return false
        }
    }
    
    private var isConnecting: Bool {
        if selectedDongle == .panda {
            return pandaTransport.state == .connecting
        } else {
            switch bleManager.connectionState {
            case .connecting, .discovering: return true
            default: return false
            }
        }
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
            if let panda = driver as? PandaDriver {
                try? await panda.setSafetyModel(.elm327)
                NSLog("[ConnectionView] Successfully connected to Panda, set safety model to ELM327 by default")
            }
            await detectVehicle()
        } else {
            if case .error(let message) = pandaTransport.state {
                statusError = "Connection error: \(message)"
            } else {
                statusError = "Connection timeout. Please ensure you are connected to the Panda's Wi-Fi network (SSID: comma-XXXXXXX) and cellular data is disabled if necessary."
            }
            disconnectAdapter()
        }
    }
    
    private func finishElmConnection() async {
        var timeout = 0
        while isConnecting && timeout < 100 {
            try? await Task.sleep(for: .milliseconds(100))
            timeout += 1
        }
        
        if isConnected {
            if let elm = driver as? ELM327 {
                do {
                    _ = try await elm.initSequence()
                } catch {
                    statusError = "ELM Init failed: \(error.localizedDescription)"
                    disconnectAdapter()
                    return
                }
            }
            await detectVehicle()
        } else {
            statusError = "Connection timeout or error"
            disconnectAdapter()
        }
    }
    
    private func disconnectAdapter() {
        if let panda = driver as? PandaDriver {
            panda.detach()
        } else if let elm = driver as? ELM327 {
            elm.detach()
        }
        
        if selectedDongle == .panda {
            pandaTransport.disconnect()
        } else {
            bleManager.disconnect()
        }
    }

    private func detectVehicle() async {
        guard let vin = try? await VINReader.read(interface: driver) else { return }
        
        // If known, set as active
        if let known = vehicleStore.vehicles.first(where: { $0.vin == vin }) {
            settings.activeVehicleSlug = known.slug
            return
        }
        
        // If unknown, decode and save
        do {
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
                createdAtUTC: Date().formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: TimeZone(secondsFromGMT: 0)!)),
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

struct ConnectionStatusBadge: View {
    @Environment(PandaTransport.self) private var pandaTransport
    @Environment(BLEManager.self) private var bleManager
    
    let selectedDongle: DongleType
    let isConnected: Bool
    let isConnecting: Bool
    let isIdleOrError: Bool

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
        if isIdleOrError { return "idle" }
        if isConnecting { return "connecting..." }
        return "connected"
    }

    private var stateSubtitle: String {
        if isIdleOrError {
            if selectedDongle == .panda, case .error(let e) = pandaTransport.state { return e }
            if selectedDongle == .elm327, case .error(let e) = bleManager.connectionState { return e }
            return "Tap Connect to start."
        }
        if isConnecting { return "Establishing connection..." }
        return "Connected via \(selectedDongle == .panda ? "Panda TCP" : "ELM327 BLE")"
    }

    private var badgeColor: Color {
        if isIdleOrError {
            let hasError: Bool
            if selectedDongle == .panda {
                hasError = pandaTransport.state != .idle
            } else {
                if case .error = bleManager.connectionState {
                    hasError = true
                } else {
                    hasError = false
                }
            }
            return hasError ? .red : .secondary
        }
        if isConnecting { return .blue }
        return .green
    }
}

struct ConnectionActionButton: View {
    let selectedDongle: DongleType
    let isConnecting: Bool
    let isIdleOrError: Bool
    
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        if isIdleOrError {
            Button("Connect \(selectedDongle == .panda ? "Panda" : "ELM327")", action: onConnect)
                .glassActionButton(prominent: true)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.small)
        } else if isConnecting {
            Button("Cancel", action: onDisconnect)
                .glassActionButton(prominent: false)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.small)
        } else {
            Button("Disconnect", action: onDisconnect)
                .glassActionButton(prominent: false)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.small)
        }
    }
}

#Preview {
    ConnectionView(driver: PandaDriver(), selectedDongle: .constant(.panda))
        .environment(PandaTransport.shared)
        .environment(BLEManager.shared)
}
