import SwiftUI

struct LogsView: View {
    @State private var logger = AppLogger.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText: String = ""
    
    var filteredEntries: [LogEntry] {
        logger.entries.filter { entry in
            let matchesLevel = selectedLevel == nil || entry.level == selectedLevel
            let matchesSearch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text("Logs Système")
                    .font(.appBrand)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action: { logger.clear() }) {
                    Label("Effacer", systemImage: "trash")
                        .font(.captionText)
                        .foregroundStyle(.red)
                }
                .glassActionButton()
                
                Button(action: { copyToClipboard() }) {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.captionText)
                        .foregroundStyle(.white)
                }
                .glassActionButton()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Search & Filter Bar
            VStack(spacing: 8) {
                TextField("Rechercher dans les logs...", text: $searchText)
                    .font(.bodyText)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: { selectedLevel = nil }) {
                            Text("Tous")
                                .font(.captionText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedLevel == nil ? Color.appAccent.opacity(0.3) : Color.white.opacity(0.05))
                                .clipShape(.capsule)
                                .overlay(
                                    Capsule()
                                        .stroke(selectedLevel == nil ? Color.appAccent : Color.clear, lineWidth: 1)
                                )
                        }
                        .foregroundStyle(.white)
                        
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Button(action: { selectedLevel = level }) {
                                Text(level.rawValue)
                                    .font(.captionText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedLevel == level ? color(for: level).opacity(0.3) : Color.white.opacity(0.05))
                                    .clipShape(.capsule)
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedLevel == level ? color(for: level) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
            
            // Logs List
            if filteredEntries.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Aucun log trouvé",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Les messages de diagnostic ou les trames échangées s'afficheront ici.")
                )
                .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(filteredEntries) { entry in
                                logRow(for: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(16)
                    }
                    .onAppear {
                        if let last = filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: filteredEntries.count) {
                        if let last = filteredEntries.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func logRow(for entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.rawValue)
                    .font(.monoTiny)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color(for: entry.level).opacity(0.2))
                    .foregroundStyle(color(for: entry.level))
                    .clipShape(.rect(cornerRadius: 4))
                
                Text(formatTime(entry.timestamp))
                    .font(.monoTiny)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            Text(entry.message)
                .font(entry.level == .command ? .monoSmall : .bodyText)
                .foregroundStyle(entry.level == .error ? .red : (entry.level == .command ? Color.cyan : .white))
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 6))
    }
    
    private func color(for level: LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .command: return .green
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func copyToClipboard() {
        let text = filteredEntries.map { entry in
            "[\(formatTime(entry.timestamp))] [\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
        UIPasteboard.general.string = text
    }
}

#Preview {
    NavigationStack {
        LogsView()
    }
}
