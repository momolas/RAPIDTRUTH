import SwiftUI

struct LoggingControlsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProfileRegistry.self) private var profileRegistry
    @Environment(PandaTransport.self) private var panda
    @Environment(LoggingSession.self) private var session
    @Environment(BLEManager.self) private var bleManager
    @Environment(VehicleStore.self) private var vehicleStore
    let driver: VehicleInterface

    private let owner = "rapidtruth"
    private let vehicleSlug = "renault_scenic2_m9r722"

    init(driver: VehicleInterface) {
        self.driver = driver
    }

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Logging").font(.cardTitle)
                Spacer()
                statusLabel
            }

            HStack {
                Picker("Rate", selection: $settings.sampleRateHz) {
                    Text("0.5 Hz").tag(0.5)
                    Text("1 Hz").tag(1.0)
                    Text("2 Hz").tag(2.0)
                    Text("5 Hz").tag(5.0)
                }
                .pickerStyle(.menu)
                .disabled(isLogging)

                Spacer()

                if isLogging {
                    Button("Stop") {
                        session.stop()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Start logging") {
                        startLogging()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canStart)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Toggle("", isOn: $settings.rawCapture)
                    .disabled(isLogging)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text("Raw hex")
                    .font(.captionText)
                    .foregroundStyle(.secondary)
                Text("— writes raw response bytes instead of decoded values.")
                    .font(.statusText)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }

            if case .error(let msg) = session.state {
                Text(msg)
                    .font(.statusText)
                    .foregroundStyle(.red)
            }
            if case .preparing(let step) = session.state {
                Text(step)
                    .font(.statusText)
                    .foregroundStyle(.secondary)
            }
            if case .logging(let count, let id) = session.state {
                Text("rows: \(count) · id: \(id)")
                    .font(.monoSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(red: 22 / 255, green: 24 / 255, blue: 29 / 255))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var isLogging: Bool {
        if case .logging = session.state { return true } else { return false }
    }

    private var canStart: Bool {
        // Either Panda Wifi is connected or we are on BLE ELM327
        if case .connected = panda.state {
            return !isLogging
        }
        // Fallback check: if we are using BLE driver, confirm if it is connected
        let ble = bleManager.connectionState
        if case .connected = ble { return !isLogging }
        return !isLogging
    }

    private var statusLabel: some View {
        Group {
            switch session.state {
            case .idle:
                Text("Ready").font(.captionText).foregroundStyle(.secondary)
            case .preparing:
                Text("Preparing…").font(.captionText).foregroundStyle(.blue)
            case .logging:
                Text("Logging").font(.captionText).foregroundStyle(.green)
            case .error:
                Text("Error").font(.captionText).foregroundStyle(.red)
            }
        }
    }

    private func startLogging() {
        guard let slug = settings.activeVehicleSlug,
              let vehicle = vehicleStore.vehicles.first(where: { $0.slug == slug }),
              let profile = profileRegistry.profile(id: vehicle.profileId) else {
            // Fallback to Scenic 2 if no active vehicle is set
            guard let profile = profileRegistry.profile(id: vehicleSlug) else { return }
            let vehicle = Vehicle(
                slug: vehicleSlug,
                owner: owner,
                displayName: "Renault Scénic 2 M9R",
                year: 2007,
                make: "Renault",
                model: "Scénic 2",
                trim: "2.0 dCi",
                vin: nil,
                profileId: vehicleSlug,
                profileVersion: "1.0",
                createdAtUTC: "2026-01-01T00:00:00Z",
                lastUsedUTC: nil,
                supportedStandardPIDs: [],
                supportedProfilePIDs: [],
                disabledPIDs: []
            )
            Task {
                await session.start(
                    vehicle: vehicle,
                    profile: profile,
                    driver: driver,
                    vehicleStore: vehicleStore,
                    sampleRateHz: settings.sampleRateHz,
                    rawMode: settings.rawCapture
                )
            }
            return
        }
        
        Task {
            await session.start(
                vehicle: vehicle,
                profile: profile,
                driver: driver,
                vehicleStore: vehicleStore,
                sampleRateHz: settings.sampleRateHz,
                rawMode: settings.rawCapture
            )
        }
    }
}
