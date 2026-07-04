//
//  CloudsApp.swift
//  Clouds
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import SwiftUI
import SwiftData

@main
struct CloudsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CloudObservation.self
        ])
        // UI tests launch with this flag so each test run gets an
        // isolated, empty store instead of accumulating data in the
        // simulator's persistent one across runs.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-TESTING-RESET")
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HistoryView()
        }
        .modelContainer(sharedModelContainer)
    }
}
