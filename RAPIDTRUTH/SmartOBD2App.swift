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
struct SmartOBD2App: App {
    let container: ModelContainer
    var garage: Garage

    init() {
        do {
            container = try ModelContainer(for: VehicleModel.self)
            // Garage needs to interact with the context.
            // For simplicity in this migration, we initialize it here, but ideally Garage should access context via Actor or MainActor.
            let context = ModelContext(container)
            garage = Garage(modelContext: context)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

	var body: some Scene {
		WindowGroup {
			MainView(garage: garage)
		}
        .modelContainer(container)
	}
}
