//
//  CodingView.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import SwiftUI
import SwiftData

struct CodingView: View {
    let obdService: OBDService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CodingMacro.name) private var macros: [CodingMacro]

    @State private var showingAddSheet = false

    var body: some View {
        ZStack {
            if macros.isEmpty {
                ContentUnavailableView(AppStrings.Coding.emptyTitle,
                                       systemImage: "terminal.fill",
                                       description: Text(AppStrings.Coding.emptyDescription))
            } else {
                List {
                    ForEach(macros) { macro in
                        MacroRow(macro: macro, obdService: obdService)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle(AppStrings.Coding.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    NavigationLink {
                        ECUSelectorView(obdService: obdService)
                    } label: {
                        Label("Base de données", systemImage: "server.rack")
                    }

                    Button(action: { showingAddSheet = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMacroView()
        }
        .background(LinearGradient.mainBackground.ignoresSafeArea())
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(macros[index])
            }
        }
    }
}

struct MacroRow: View {
    let macro: CodingMacro
    let obdService: OBDService
    @State private var isRunning = false
    @State private var statusIcon: String = "play.circle.fill"
    @State private var statusColor: Color = .blue

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(macro.name)
                        .font(.headline)
                    Text(macro.desc)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Button(action: runMacro) {
                    if isRunning {
                        ProgressView()
                    } else {
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                    }
                }
                .disabled(isRunning)
            }
        }
        .padding(.vertical, 8)
    }

    private func runMacro() {
        guard !isRunning else { return }
        isRunning = true
        statusIcon = "play.circle.fill"
        statusColor = .blue

        Task {
            var success = true
            for cmd in macro.commands {
                do {
                    _ = try await obdService.sendRawCommand(cmd)
                    // Small delay to prevent flooding
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    print("Macro error on command \(cmd): \(error)")
                    success = false
                    break
                }
            }

            await MainActor.run {
                isRunning = false
                if success {
                    statusIcon = "checkmark.circle.fill"
                    statusColor = .green
                } else {
                    statusIcon = "exclamationmark.circle.fill"
                    statusColor = .red
                }

                // Reset status after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    statusIcon = "play.circle.fill"
                    statusColor = .blue
                }
            }
        }
    }
}

struct AddMacroView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var commandsText = ""

    var isValid: Bool {
        !name.isEmpty && !commandsText.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(AppStrings.Coding.name)) {
                    TextField(AppStrings.Coding.name, text: $name)
                    TextField(AppStrings.Coding.description, text: $desc)
                }

                Section(header: Text(AppStrings.Coding.commands)) {
                    TextEditor(text: $commandsText)
                        .frame(height: 150)
                        .overlay(
                            VStack {
                                if commandsText.isEmpty {
                                    Text(AppStrings.Coding.placeholderCommands)
                                        .foregroundStyle(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                Spacer()
                            },
                            alignment: .topLeading
                        )
                }
            }
            .navigationTitle(AppStrings.Coding.newMacro)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.AddVehicle.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.AddVehicle.save) {
                        saveMacro()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveMacro() {
        let commands = commandsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let newMacro = CodingMacro(name: name, desc: desc, commands: commands)
        modelContext.insert(newMacro)
    }
}
