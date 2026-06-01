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
                .environment(PandaTransport.shared)
                .environment(BLEManager.shared)
                .environment(VehicleStore.shared)
                .environment(ProfileRegistry.shared)
                .environment(LoggingSession.shared)
                .onOpenURL { url in
                    handleImport(url: url)
                }
                .overlay(alignment: .top) {
                    if let banner = importBanner {
                        ImportBannerView(banner: banner)
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
}
