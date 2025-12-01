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
                ContentUnavailableView(AppStrings.ECUDatabase.empty, systemImage: "xmark.circle")
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
            }
        }
        .navigationTitle(AppStrings.ECUDatabase.title)
        .task {
            await loadDB()
        }
    }

    private func loadDB() async {
        guard let url = Bundle.main.url(forResource: "db", withExtension: "json") else {
            print("db.json not found")
            await MainActor.run { self.isLoading = false }
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let dict = try JSONDecoder().decode([String: DatabaseECU].self, from: data)
            let sortedECUs = dict.compactMap { key, value -> DatabaseECU? in
                guard AllowedECUs.isAllowed(value.ecuname) else { return nil }
                var ecu = value
                ecu.fileName = key
                return ecu
            }.sorted { $0.ecuname < $1.ecuname }

            await MainActor.run {
                self.ecus = sortedECUs
                self.isLoading = false
            }
        } catch {
            print("Error loading db.json: \(error)")
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
