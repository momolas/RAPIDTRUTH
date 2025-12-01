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

    // List all available DB files
    private var availableDBs: [URL] {
        Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil)?.filter {
            $0.lastPathComponent.hasSuffix("_db.json")
        } ?? []
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
                ProgressView(AppStrings.ECUDatabase.loading)
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
                                            Text(ecu.protocol ?? "Unknown")
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
            if let defaultDB = availableDBs.first(where: { $0.lastPathComponent == "X84_db.json" }) ?? availableDBs.first {
                await loadDB(url: defaultDB)
            } else {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    private func loadDB(url: URL) async {
        await MainActor.run {
            self.isLoading = true
            self.selectedDB = url
        }

        do {
            let data = try Data(contentsOf: url)
            let dict = try JSONDecoder().decode([String: DatabaseECU].self, from: data)
            let sortedECUs = dict.compactMap { key, value -> DatabaseECU? in
                // We keep the AllowedECUs filter for now, but it might need to be relaxed
                // if we are loading a completely new DB.
                // Assuming allowed list is relevant for X84 mostly.
                // If we load X86, we might want to skip this check or update AllowedECUs.
                // For safety, let's allow all if filename contains "X86" or just warn.
                // Better approach: If AllowedECUs blocks everything, we show nothing.
                // Let's rely on the definition.

                // If DB is X84, we filter.
                if url.lastPathComponent.contains("X84") {
                     guard AllowedECUs.isAllowed(value.ecuname) else { return nil }
                }

                var ecu = value
                ecu.fileName = key
                return ecu
            }.sorted { $0.ecuname < $1.ecuname }

            await MainActor.run {
                self.ecus = sortedECUs
                self.isLoading = false
            }
        } catch {
            print("Error loading \(url.lastPathComponent): \(error)")
            await MainActor.run { self.isLoading = false }
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
                ECUDiagnosticsView(definition: definition, obdService: obdService)
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
        } else {
            print("File not found: \(filename)")
            self.error = NSError(domain: "App", code: 404, userInfo: nil)
        }
    }
}
