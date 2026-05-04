import SwiftUI

struct ConnectionView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @Environment(WiFiManager.self) private var wifiManager
    @Environment(BLEManager.self) private var bleManager
    
    // Shared ELM327 owned by the parent (MainShellView). Must NOT be a
    // separate @State — two ELM327 instances would race for AsyncStream
    // chunks from ConnectionManager's inboundStream and silently swallow
    // each other's responses.
    let elm: ELM327
    @State private var showPicker = false
    @State private var statusError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                statusBadge
                Spacer()
                connectionButton
            }
            
            // Picker to choose between BLE and WiFi
            Picker("Connection Type", selection: Bindable(connectionManager).connectionType) {
                ForEach(ConnectionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            if let statusError {
                Text(statusError)
                    .font(.statusText)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 6))
            }

            DisclosureGroup("Adapter log (\(elm.log.count))") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(elm.log) { entry in
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
        .padding(16)
        .background(Color(red: 22 / 255, green: 24 / 255, blue: 29 / 255))
        .clipShape(.rect(cornerRadius: 12))
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
                    if connectionManager.demoMode {
                        Text("DEMO")
                            .font(.monoTiny)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }
                Text(stateSubtitle)
                    .font(.captionText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch connectionManager.state {
        case .idle, .error:
            Button("Connect") {
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
            Button("Cancel") {
                connectionManager.disconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .connected:
            Button("Disconnect") {
                elm.detach()
                connectionManager.disconnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var stateTitle: String {
        switch connectionManager.state {
        case .idle: return "idle"
        case .connecting(let n): return "connecting → \(n)"
        case .connected(let n): return "connected: \(n)"
        case .error: return "error"
        }
    }

    private var stateSubtitle: String {
        switch connectionManager.state {
        case .idle: return "Tap Connect to start."
        case .connecting(let n): return "Establishing \(n) connection..."
        case .connected(let n):
            if connectionManager.demoMode {
                return "Canned ECU responses — tap Disconnect to pair a real adapter."
            }
            return "Connected via \(n)"
        case .error(let msg): return msg
        }
    }

    private var badgeColor: Color {
        switch connectionManager.state {
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
            elm.attach()
            _ = try await elm.initSequence()
            await detectVehicle()
        } catch {
            statusError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
            elm.attach()
            do {
                _ = try await elm.initSequence()
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
        guard let vin = try? await VINReader.read(elm: elm) else { return }
        
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
