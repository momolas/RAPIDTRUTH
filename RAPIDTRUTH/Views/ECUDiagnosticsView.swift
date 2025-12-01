//
//  ECUDiagnosticsView.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import SwiftUI

struct ECUDiagnosticsView: View {
    let definition: ECUDefinition
    let ecu: DatabaseECU? // Added context from DB
    let obdService: OBDService
    @State private var service: ECUDiagnosticService
    @State private var layout: ECULayout?
    @State private var selectedRequest: ECURequest?
    @State private var results: [String: String] = [:]
    @State private var isExecuting = false

    init(definition: ECUDefinition, ecu: DatabaseECU? = nil, obdService: OBDService) {
        self.definition = definition
        self.ecu = ecu
        self.obdService = obdService
        self._service = State(initialValue: ECUDiagnosticService(obdService: obdService))
    }

    var body: some View {
        List {
            Section(header: Text("ECU Information")) {
                Text("Name: \(definition.ecuname)")
                Text("Protocol: \(definition.obd.protocolName ?? ecu?.protocolName ?? "Unknown")")
                if let addr = ecu?.address {
                    Text("Address: \(addr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let layout = layout {
                ForEach(layout.categories.keys.sorted(), id: \.self) { categoryName in
                    Section(header: Text(categoryName)) {
                        ForEach(layout.categories[categoryName] ?? [], id: \.self) { screenName in
                            if let screen = layout.screens[screenName] {
                                NavigationLink(destination: ECUScreenView(
                                    screenName: screenName,
                                    screen: screen,
                                    definition: definition,
                                    ecu: ecu, // Pass down to screen
                                    service: service
                                )) {
                                    Text(screenName)
                                }
                            }
                        }
                    }
                }
            } else {
                // Fallback to manual list if no layout
                Section(header: Text("Manual Commands")) {
                    ForEach(definition.requests) { request in
                        if request.manualsend == true {
                            Button {
                                execute(request)
                            } label: {
                                HStack {
                                    Text(request.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .disabled(isExecuting)
                        }
                    }
                }

                if !results.isEmpty {
                    Section(header: Text("Results: \(selectedRequest?.name ?? "")")) {
                        ForEach(results.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(value)
                                    .font(.body)
                                    .bold()
                            }
                        }
                    }
                }
            }

            Section(header: Text("Devices / DTCs")) {
                ForEach(definition.devices) { dtc in
                    HStack {
                        Text("DTC \(dtc.dtc)")
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Text(dtc.name)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(definition.ecuname)
        .onAppear {
            loadLayout()
        }
    }

    private func loadLayout() {
        // Use logic to find layout file based on definition name
        // Ideally we check if a file definition.ecuname + ".layout" exists?
        // Or passed from outside.
        // For now, retaining the hardcoded fallback for parking_sensor if dynamic fails

        // This logic was hardcoded in previous file.
        if let url = Bundle.main.url(forResource: "parking_sensor.layout", withExtension: "json") {
            do {
                self.layout = try service.loadLayout(from: url)
            } catch {
                print("Failed to load layout: \(error)")
            }
        }
    }

    private func execute(_ request: ECURequest) {
        selectedRequest = request
        isExecuting = true
        results = [:]

        Task {
            do {
                // Pass the ECU context (address) to execution
                results = try await service.execute(request: request, definition: definition, ecu: ecu)
            } catch {
                results = ["Error": error.localizedDescription]
            }
            isExecuting = false
        }
    }
}
