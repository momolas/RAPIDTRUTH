//
//  SmartOBD2App.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/3/23.
//

import SwiftUI
import OSLog
import SwiftData

extension Logger {
	/// Using your bundle identifier is a great way to ensure a unique identifier.
	private static var subsystem = Bundle.main.bundleIdentifier ?? "com.SmartOBD2"
	
	/// Logs the view cycles like a view that appeared.
	static let elmCom = Logger(subsystem: subsystem, category: "ELM327")
	
	/// All logs related to tracking and analytics.
	static let bleCom = Logger(subsystem: subsystem, category: "BLEComms")
}

@main
@MainActor
struct SmartOBD2App: App {
    let container: ModelContainer
    var garage: Garage

    init() {
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: VehicleModel.self, CodingMacro.self)
        } catch {
            Logger.bleCom.error("Failed to create persistent ModelContainer: \(error)")
            // Fallback to in-memory container
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: VehicleModel.self, CodingMacro.self, configurations: config)
            } catch {
                fatalError("Failed to create ModelContainer (persistent and in-memory): \(error)")
            }
        }
        self.container = modelContainer

        let context = ModelContext(modelContainer)
        self.garage = Garage(modelContext: context)
    }

	var body: some Scene {
		WindowGroup {
			MainView(garage: garage)
		}
        .modelContainer(container)
	}
}
