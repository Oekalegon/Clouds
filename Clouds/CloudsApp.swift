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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
