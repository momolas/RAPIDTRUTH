//
//  RAPIDTRUTHApp.swift
//  RAPIDTRUTH
//
//  Created by Mo on 06/04/2026.
//

import SwiftUI

@main
struct RAPIDTRUTHApp: App {
    @State private var importBanner: ImportBanner?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(SettingsStore.shared)
                .environment(ConnectionManager.shared)
                .environment(BLEManager.shared)
                .environment(WiFiManager.shared)
                .environment(PandaTransport.shared)
                .environment(VehicleStore.shared)
                .onOpenURL { url in
                    handleImport(url: url)
                }
                .overlay(alignment: .top) {
                    if let banner = importBanner {
                        bannerView(banner)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        }
    }

    private func handleImport(url: URL) {
        guard url.pathExtension.lowercased() == "json" else { return }
        do {
            let profile = try ProfileImporter.importProfile(from: url)
            ProfileRegistry.shared.reload()
            importBanner = .success("Imported profile: \(profile.displayName)")
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            importBanner = .failure("Import failed: \(msg)")
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.5))
            if importBanner != nil {
                withAnimation { importBanner = nil }
            }
        }
    }

    @ViewBuilder
    private func bannerView(_ banner: ImportBanner) -> some View {
        let (text, color): (String, Color) = {
            switch banner {
            case .success(let msg): return (msg, .green)
            case .failure(let msg): return (msg, .red)
            }
        }()
        Text(text)
            .font(.body) // Using .body since .bodyText is a custom style not defined here or maybe in Style.swift
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.9))
            .clipShape(.rect(cornerRadius: 10))
            .frame(maxWidth: .infinity)
    }
}

private enum ImportBanner: Equatable {
    case success(String)
    case failure(String)
}
