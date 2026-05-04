import SwiftUI

struct ConnectionView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(WiFiManager.self) private var wifiManager
    @Environment(PandaTransport.self) private var pandaTransport
    @Environment(BLEManager.self) private var bleManager
    
    @Bindable var adapterManager: AdapterManager
    @State private var showPicker = false
    @State private var statusError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                statusBadge
                Spacer()
                connectionButton
            }
            
            Picker("Adapter Protocol", selection: $adapterManager.adapterType) {
                ForEach(AdapterType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            if adapterManager.adapterType == .elm327 {
                Picker("Connection Type", selection: Bindable(connectionManager).connectionType) {
                    ForEach(ConnectionType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)
            }

            if let statusError {
                Text(statusError)
                    .font(.statusText)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 6))
            }

            if adapterManager.adapterType == .elm327 {
                DisclosureGroup("Adapter log (\(adapterManager.elm327.log.count))") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(adapterManager.elm327.log) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                Text(entry.direction.rawValue.uppercased())
                                    .font(.monoTiny)
                                    .foregroundStyle(color(for: entry.direction))
                                    .frame(width: 36, alignment: .leading)
                                Text(entry.text)
                                    .font(.monoSmall)
                                    .foregroundStyle(entry.direction == .err ? .red : .primary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
                .padding(8)
                .background(Color.black.opacity(0.4))
                .clipShape(.rect(cornerRadius: 6))
                }
                .font(.statusText)
                .foregroundStyle(.secondary)
            }
        }
        .appCard()
        .sheet(isPresented: $showPicker) {
            DevicePickerView { device in
                statusError = nil
                Task { await connectBLE(to: device) }
            }
        }
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
        if adapterManager.adapterType == .panda {
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
                    adapterManager.pandaDriver.detach()
                    pandaTransport.disconnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else {
            switch connectionManager.state {
            case .idle, .error:
                Button("Connect ELM") {
                    statusError = nil
                    if connectionManager.connectionType == .ble {
                        showPicker = true
                    } else {
                        Task { await connectWiFi() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            case .connecting:
                Button("Cancel") { connectionManager.disconnect() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            case .connected:
                Button("Disconnect") {
                    adapterManager.elm327.detach()
                    connectionManager.disconnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var stateTitle: String {
        if adapterManager.adapterType == .panda {
            switch pandaTransport.state {
            case .idle: return "idle"
            case .connecting: return "connecting → UDP 1337"
            case .connected: return "connected: Panda CAN"
            case .error: return "error"
            }
        } else {
            switch connectionManager.state {
            case .idle: return "idle"
            case .connecting(let n): return "connecting → \(n)"
            case .connected(let n): return "connected: \(n)"
            case .error: return "error"
            }
        }
    }

    private var stateSubtitle: String {
        if adapterManager.adapterType == .panda {
            switch pandaTransport.state {
            case .idle: return "Tap Connect Panda to start."
            case .connecting: return "Establishing Panda UDP connection..."
            case .connected: return "Connected via Panda Native Protocol"
            case .error(let msg): return msg
            }
        } else {
            switch connectionManager.state {
            case .idle: return "Tap Connect ELM to start."
            case .connecting(let n): return "Establishing \(n) connection..."
            case .connected(let n): return "Connected via \(n)"
            case .error(let msg): return msg
            }
        }
    }

    private var badgeColor: Color {
        let st = adapterManager.adapterType == .panda ?
            (pandaTransport.state == .connected ? GlobalConnectionState.connected("Panda") :
                (pandaTransport.state == .connecting ? .connecting("Panda") :
                    (pandaTransport.state == .idle ? .idle : .error("Panda"))))
            : connectionManager.state
            
        switch st {
        case .idle: return .secondary
        case .connecting: return .blue
        case .connected: return .green
        case .error: return .red
        }
    }

    private func color(for direction: ELM327.Direction) -> Color {
        switch direction {
        case .tx: return .blue
        case .rx: return .green
        case .info: return .secondary
        case .err: return .red
        }
    }

    private func connectBLE(to device: BLEManager.DiscoveredDevice) async {
        do {
            _ = try await bleManager.connect(device)
            adapterManager.elm327.attach()
            _ = try await adapterManager.elm327.initSequence()
            await detectVehicle()
        } catch {
            statusError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
            adapterManager.pandaDriver.attach()
            // Panda doesn't need an ATZ/initSequence like ELM327. We can just detect vehicle.
            await detectVehicle()
        } else if case .error(let msg) = pandaTransport.state {
            statusError = msg
        } else {
            statusError = "Connection timeout"
            pandaTransport.disconnect()
        }
    }

    private func connectWiFi() async {
        wifiManager.connect()
        // Wait for state to become connected or error
        var timeout = 0
        while wifiManager.state == .connecting && timeout < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            timeout += 1
        }
        
        if wifiManager.state == .connected {
            adapterManager.elm327.attach()
            do {
                _ = try await adapterManager.elm327.initSequence()
                await detectVehicle()
            } catch {
                statusError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        } else if case .error(let msg) = wifiManager.state {
            statusError = msg
        } else {
            statusError = "Connection timeout"
            wifiManager.disconnect()
        }
    }

    private func detectVehicle() async {
        guard let vin = try? await VINReader.read(interface: adapterManager.activeInterface) else { return }
        
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
