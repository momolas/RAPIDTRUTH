import SwiftUI

struct AddVehicleView: View {
    let driver: VehicleInterface
    /// Optional callback fired right after a vehicle is successfully saved
    /// (and before the sheet dismisses itself). Onboarding uses this to
    /// know when its third step is complete.
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(ProfileRegistry.self) private var profileRegistry
    @Environment(VehicleStore.self) private var vehicleStore
    @Environment(PandaTransport.self) private var pandaTransport

    @State private var year: Int? = nil
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var trim: String = ""
    @State private var vin: String = ""
    @State private var profileID: String = "generic_obd2"
    @State private var error: String?

    @State private var status: AutoStatus = .idle
    @State private var lastDecodedVIN: String?
    @State private var decodeTask: Task<Void, Never>?

    enum AutoStatus: Equatable {
        case idle
        case readingVIN
        case vinReadFailed(String)
        case decoding
        case decoded
        case decodeFailed(String)
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("API de Décodage VIN") {
                    Picker("Service API", selection: $settings.vinDecoderAPI) {
                        Text("ApiPlaque (France)").tag("apiplaque")
                        Text("Auto.dev (Global)").tag("autodev")
                        Text("Aucun (Désactivé)").tag("none")
                    }
                    .pickerStyle(.menu)
                    
                    if settings.vinDecoderAPI == "apiplaque" {
                        SecureField("Token ApiPlaque", text: $settings.apiPlaqueToken)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                    } else if settings.vinDecoderAPI == "autodev" {
                        SecureField("Clé d'API Auto.dev", text: $settings.autoDevToken)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                    }
                }
                
                Section("Véhicule") {
                    TextField("Année", value: $year, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    TextField("Marque (ex: Renault)", text: $make)
                    TextField("Modèle (ex: Scenic)", text: $model)
                    TextField("Finition (optionnel)", text: $trim)
                    TextField("VIN (optionnel)", text: $vin)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .onChange(of: vin) { _, newValue in
                            handleVINChange(newValue)
                        }
                }
                if let statusText {
                    Section { Text(statusText).font(.statusText).foregroundStyle(statusColor) }
                }
                Section("Profil de diagnostic") {
                    Picker("Profil", selection: $profileID) {
                        ForEach(profileRegistry.profiles) { p in
                            Text(p.displayName).tag(p.profileId)
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Ajouter un véhicule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                }
            }
            .task {
                profileID = profileRegistry.suggestedProfile(make: nil, year: nil).profileId
                await runVINReadIfConnected()
            }
            .onDisappear {
                decodeTask?.cancel()
                decodeTask = nil
            }
        }
    }

    private var statusText: String? {
        switch status {
        case .idle: return nil
        case .readingVIN: return "Lecture du VIN depuis le véhicule…"
        case .vinReadFailed(let reason): return "Impossible de lire le VIN automatiquement : \(reason). Entrez-le manuellement si vous le souhaitez."
        case .decoding: return "Décodage via \(settings.vinDecoderAPI.uppercased())…"
        case .decoded: return "Décodé. Modifiez les champs si nécessaire."
        case .decodeFailed(let msg): return "Échec du décodage : \(msg). Remplissez les champs manuellement."
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle, .readingVIN, .decoding, .decoded: return .secondary
        case .vinReadFailed, .decodeFailed: return .orange
        }
    }

    private func handleVINChange(_ raw: String) {
        // Force uppercase without re-triggering the binding.
        let upper = raw.uppercased()
        if upper != raw { vin = upper; return }
        guard isValidVINFormat(upper), upper != lastDecodedVIN else { return }
        decodeTask?.cancel()
        decodeTask = Task {
            await runDecode(vin: upper)
        }
    }

    private func runVINReadIfConnected() async {
        guard case .connected = pandaTransport.state else {
            NSLog("[OBD2-VIN] auto-read skipped: not connected (state=\(String(describing: pandaTransport.state)))")
            return
        }
        // Don't clobber a VIN the user has already typed.
        guard vin.isEmpty else { return }
        NSLog("[OBD2-VIN] auto-read: starting")
        status = .readingVIN
        do {
            if let panda = driver as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
            if let read = try await VINReader.read(interface: driver) {
                NSLog("[OBD2-VIN] auto-read: got VIN \(read)")
                vin = read
                await runDecode(vin: read)
            } else {
                NSLog("[OBD2-VIN] auto-read: VINReader returned nil (no 4902 prefix in response)")
                status = .vinReadFailed("ECU didn't return a parseable VIN")
            }

        } catch {
            NSLog("[OBD2-VIN] auto-read: error \(error)")
            status = .vinReadFailed(error.localizedDescription)
        }
    }

    private func runDecode(vin candidate: String) async {
        status = .decoding
        do {
            let service = getActiveDecoderService(settings: settings)
            let decoded = try await service.decode(vin: candidate)
            lastDecodedVIN = candidate
            applyDecoded(decoded)
            status = .decoded
        } catch {
            status = .decodeFailed(error.localizedDescription)
        }
    }

    private func applyDecoded(_ decoded: VINDecoderResult) {
        if let y = decoded.year { year = y }
        if !decoded.make.isEmpty { make = decoded.make }
        if !decoded.model.isEmpty { model = decoded.model }
        if !decoded.trim.isEmpty { trim = decoded.trim }
        let suggested = profileRegistry.suggestedProfile(make: decoded.make, model: decoded.model, year: decoded.year)
        profileID = suggested.profileId
    }

    private func save() {
        let yearInt = year
        let slug = Vehicle.makeSlug(year: yearInt, make: make.isEmpty ? nil : make, model: model.isEmpty ? nil : model)
        guard !slug.isEmpty else {
            error = "Veuillez renseigner au moins l'année et la marque ou le modèle."
            return
        }
        guard let profile = profileRegistry.profile(id: profileID) else {
            error = "Veuillez sélectionner un profil."
            return
        }
        let vehicle = Vehicle(
            slug: slug,
            owner: settings.owner,
            displayName: Vehicle.makeDisplayName(year: yearInt, make: make, model: model, trim: trim),
            year: yearInt,
            make: make.isEmpty ? nil : make,
            model: model.isEmpty ? nil : model,
            trim: trim.isEmpty ? nil : trim,
            vin: vin.isEmpty ? nil : vin,
            profileId: profile.profileId,
            profileVersion: profile.profileVersion,
            createdAtUTC: Date.now.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: TimeZone(secondsFromGMT: 0)!)),
            lastUsedUTC: nil,
            supportedStandardPIDs: [],
            supportedProfilePIDs: [],
            disabledPIDs: []
        )
        do {
            try vehicleStore.save(vehicle)
            settings.activeVehicleSlug = vehicle.slug
            onSaved?()
            dismiss()
        } catch let err {
            error = err.localizedDescription
        }
    }
}
