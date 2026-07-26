import SwiftUI
import Charts

struct LiveDataView: View {
    let interface: VehicleInterface
    let profile: Profile
    
    @State private var viewModel = LiveDataViewModel()
    @State private var selectedPIDs: Set<String> = []
    
    // Filtering states
    @State private var searchText = ""
    @State private var selectedEcu: String? = nil
    @State private var showOnlySelected = false
    
    @Environment(PandaTransport.self) private var pandaTransport
    
    private var isConnected: Bool {
        if case .connected = pandaTransport.state { return true }
        return false
    }
    
    // Retrieve all unique ECUs from the profile
    private var availableEcus: [String] {
        Array(profile.ecus.keys).sorted()
    }
    
    // Get the list of PIDs matching our search text, ECU selection, and show-only-selected filter
    private var filteredPIDs: [PidDef] {
        profile.pids.filter { pid in
            // 1. Show only selected toggle
            if showOnlySelected && !selectedPIDs.contains(pid.id) {
                return false
            }
            
            // 2. ECU Filter
            if let selectedEcu, pid.ecu != selectedEcu {
                return false
            }
            
            // 3. Search text
            if !searchText.isEmpty {
                let matchesName = pid.displayName.localizedStandardContains(searchText)
                let matchesId = pid.id.localizedStandardContains(searchText)
                let matchesPid = pid.pid.localizedStandardContains(searchText)
                let matchesEcu = pid.ecu.localizedStandardContains(searchText)
                return matchesName || matchesId || matchesPid || matchesEcu
            }
            
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection warning banner if offline
            if !isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Outil non connecté. Connectez un adaptateur OBD.")
                        .font(.captionText)
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.appCardBackground)
            }
            
            // Search and global settings
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Rechercher un PID (nom, hex...)", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button("Effacer", systemImage: "xmark.circle.fill") {
                            searchText = ""
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .clipShape(.rect(cornerRadius: 8))
                
                // Horizontal ECU filter scroll view
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        EcuFilterButton(title: "Tous", isSelected: selectedEcu == nil) {
                            selectedEcu = nil
                        }
                        
                        ForEach(availableEcus, id: \.self) { ecu in
                            EcuFilterButton(title: ecu.uppercased(), isSelected: selectedEcu == ecu) {
                                selectedEcu = ecu
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.appBackground)
            
            // Selection actions and status counter
            HStack {
                Text("\(selectedPIDs.count) sélectionnés")
                    .font(.captionText)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Tout cocher", action: selectAllFiltered)
                        .font(.captionTiny)
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.appAccent)
                        .disabled(filteredPIDs.isEmpty || viewModel.isSampling)
                    
                    Button("Tout décocher", action: deselectAllFiltered)
                        .font(.captionTiny)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                        .disabled(filteredPIDs.isEmpty || viewModel.isSampling)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.02))
            
            if viewModel.isSampling {
                LiveDataChartView(pids: profile.pids, history: viewModel.chartHistory)
            }
            
            // Main list of PIDs
            List {
                ForEach(filteredPIDs) { pid in
                    let isPidSelected = selectedPIDs.contains(pid.id)
                    let liveValue = viewModel.liveValues[pid.id]
                    let isStriked = viewModel.disabledPIDs.contains(pid.id)
                    
                    PidRowView(
                        pid: pid,
                        isSelected: isPidSelected,
                        isSampling: viewModel.isSampling,
                        isStriked: isStriked,
                        liveValue: liveValue,
                        onToggle: {
                            toggleSelection(for: pid.id)
                        }
                    )
                    .listRowBackground(Color.appCardBackground)
                    .listRowSeparatorTint(Color.white.opacity(0.1))
                }
            }
            .listStyle(.plain)
            .background(Color.appBackground)
            
            // Bottom control area
            VStack(spacing: 12) {
                Toggle(isOn: $showOnlySelected) {
                    Text("Afficher uniquement la sélection")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                }
                .disabled(selectedPIDs.isEmpty && !showOnlySelected)
                
                if viewModel.isSampling {
                    Button("Arrêter l'échantillonnage", systemImage: "stop.fill") {
                        viewModel.stopSampling()
                    }
                    .font(.appButton)
                    .frame(maxWidth: .infinity)
                    .glassActionButton(prominent: true)
                    .foregroundStyle(.red)
                } else {
                    Button("Démarrer l'échantillonnage", systemImage: "play.fill") {
                        let samplingList = profile.pids.filter { selectedPIDs.contains($0.id) }
                        viewModel.startSampling(interface: interface, profile: profile, selectedPids: samplingList)
                    }
                    .font(.appButton)
                    .frame(maxWidth: .infinity)
                    .glassActionButton(prominent: true)
                    .disabled(selectedPIDs.isEmpty || !isConnected)
                }
                
                if viewModel.isSampling {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 4)
                        Text("Ticks reçus : \(viewModel.tickCount)")
                            .font(.captionText)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color.appCardBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Données Temps Réel")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.stopSampling()
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedPIDs.contains(id) {
            selectedPIDs.remove(id)
        } else {
            selectedPIDs.insert(id)
        }
    }
    
    private func selectAllFiltered() {
        for pid in filteredPIDs {
            selectedPIDs.insert(pid.id)
        }
    }
    
    private func deselectAllFiltered() {
        for pid in filteredPIDs {
            selectedPIDs.remove(pid.id)
        }
    }
}
