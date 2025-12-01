//
//  ECUSelectorView.swift
//  SMARTOBD2
//

import SwiftUI

struct ECUSelectorView: View {
    let obdService: OBDService
    @State private var ecus: [DatabaseECU] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedDB: URL?
    @State private var debugMessage: String = "" // For on-screen debugging

    // List all available DB files
    private var availableDBs: [URL] {
        var urls: [URL] = []

        // 1. Try to find explicit known DBs to ensure they are present even if scan fails
        // Check root
        if let x84 = Bundle.main.url(forResource: "X84_db", withExtension: "json") {
            urls.append(x84)
        }
        // Check Resources folder explicitly (if folder reference is used)
        else if let x84Res = Bundle.main.url(forResource: "X84_db", withExtension: "json", subdirectory: "Resources") {
            urls.append(x84Res)
        }

        // 2. Scan for others in root
        if let found = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            let others = found.filter {
                $0.lastPathComponent.hasSuffix("_db.json") &&
                $0.lastPathComponent != "X84_db.json"
            }
            urls.append(contentsOf: others)
        }

        // 3. Scan for others in Resources
        if let foundRes = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Resources") {
            let othersRes = foundRes.filter {
                $0.lastPathComponent.hasSuffix("_db.json") &&
                $0.lastPathComponent != "X84_db.json" &&
                !urls.contains($0) // Avoid duplicates
            }
            urls.append(contentsOf: othersRes)
        }

        return urls
    }

    var filteredECUs: [DatabaseECU] {
        if searchText.isEmpty {
            return ecus
        } else {
            return ecus.filter { ecu in
                ecu.ecuname.localizedCaseInsensitiveContains(searchText) ||
                ecu.group.localizedCaseInsensitiveContains(searchText) ||
                ecu.projects.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
    }

    var groupedECUs: [(key: String, value: [DatabaseECU])] {
        let grouped = Dictionary(grouping: filteredECUs, by: { $0.group })
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView(AppStrings.ECUDatabase.loading)
                    if !debugMessage.isEmpty {
                        Text(debugMessage).font(.caption).foregroundStyle(.red).padding()
                    }
                }
            } else if ecus.isEmpty {
                 VStack {
                    if availableDBs.count > 1 {
                        Menu {
                            ForEach(availableDBs, id: \.self) { url in
                                Button(url.lastPathComponent) {
                                    Task { await loadDB(url: url) }
                                }
                            }
                        } label: {
                            Label("Select Database", systemImage: "cylinder.split.1x2")
                        }
                        .padding()
                    }
                    ContentUnavailableView(AppStrings.ECUDatabase.empty, systemImage: "xmark.circle")
                    if !debugMessage.isEmpty {
                        Text("Debug: " + debugMessage).font(.caption).foregroundStyle(.red).padding()
                    }
                }
            } else {
                List {
                    ForEach(groupedECUs, id: \.key) { groupName, ecus in
                        Section(header: Text(groupName)) {
                            ForEach(ecus) { ecu in
                                NavigationLink {
                                    ECULoaderView(ecu: ecu, obdService: obdService)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(ecu.ecuname)
                                            .font(.headline)
                                        HStack {
                                            Text(ecu.protocolName ?? "Unknown")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: AppStrings.ECUDatabase.searchPrompt)
                .toolbar {
                    if availableDBs.count > 1 {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                ForEach(availableDBs, id: \.self) { url in
                                    Button {
                                        Task { await loadDB(url: url) }
                                    } label: {
                                        if selectedDB == url {
                                            Label(url.lastPathComponent, systemImage: "checkmark")
                                        } else {
                                            Text(url.lastPathComponent)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "cylinder.split.1x2")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(AppStrings.ECUDatabase.title)
        .task {
            // Load default or first available
            let dbs = availableDBs
            print("Available DBs: \(dbs)")
            await MainActor.run { self.debugMessage = "Found \(dbs.count) DBs" }

            if let defaultDB = dbs.first(where: { $0.lastPathComponent == "X84_db.json" }) ?? dbs.first {
                await loadDB(url: defaultDB)
            } else {
                print("No database found.")
                await MainActor.run {
                    self.isLoading = false
                    self.debugMessage += "\nNo DB found in bundle."
                }
            }
        }
    }

    private func loadDB(url: URL) async {
        await MainActor.run {
            self.isLoading = true
            self.selectedDB = url
            self.debugMessage = "Loading \(url.lastPathComponent)..."
        }

        do {
            let data = try Data(contentsOf: url)
            print("Data size: \(data.count)")

            // Debug first few bytes
            let str = String(data: data.prefix(100), encoding: .utf8) ?? "Invalid UTF8"
            print("Header: \(str)")

            let dict = try JSONDecoder().decode([String: DatabaseECU].self, from: data)
            let sortedECUs = dict.compactMap { key, value -> DatabaseECU? in
                var ecu = value
                ecu.fileName = key
                return ecu
            }.sorted { $0.ecuname < $1.ecuname }

            await MainActor.run {
                self.ecus = sortedECUs
                self.isLoading = false
                self.debugMessage = "Loaded \(sortedECUs.count) ECUs"
            }
        } catch {
            print("Error loading \(url.lastPathComponent): \(error)")
            await MainActor.run {
                self.isLoading = false
                self.debugMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

struct ECULoaderView: View {
    let ecu: DatabaseECU
    let obdService: OBDService
    @State private var definition: ECUDefinition?
    @State private var error: Error?
    @State private var loaded = false

    var body: some View {
        Group {
            if let definition = definition {
                ECUDiagnosticsView(definition: definition, ecu: ecu, obdService: obdService)
                    .navigationTitle(ecu.ecuname)
            } else if error != nil {
                ContentUnavailableView(AppStrings.ECUDatabase.errorTitle,
                                       systemImage: "exclamationmark.triangle",
                                       description: Text("\(AppStrings.ECUDatabase.definitionError) (\(ecu.fileName))"))
            } else {
                ProgressView(AppStrings.ECUDatabase.loadingDefinition)
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            loadDefinition()
        }
    }

    private func loadDefinition() {
        let filename = ecu.fileName
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let finalExt = ext.isEmpty ? "json" : ext

        // Try searching in Resources or Bundle root
        if let url = Bundle.main.url(forResource: name, withExtension: finalExt) {
            do {
                let data = try Data(contentsOf: url)
                self.definition = try JSONDecoder().decode(ECUDefinition.self, from: data)
            } catch {
                print("Decode error for \(filename): \(error)")
                self.error = error
            }
        }
        // Also check Resources subdirectory
        else if let url = Bundle.main.url(forResource: name, withExtension: finalExt, subdirectory: "Resources") {
            do {
                let data = try Data(contentsOf: url)
                self.definition = try JSONDecoder().decode(ECUDefinition.self, from: data)
            } catch {
                print("Decode error for \(filename): \(error)")
                self.error = error
            }
        }
        else {
            print("File not found: \(filename)")
            self.error = NSError(domain: "App", code: 404, userInfo: nil)
        }
    }
}
