//
//  HistoryView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CloudObservation.date, order: .reverse) private var observations: [CloudObservation]
    @State private var isPresentingIdentify = false

    private var sections: [(day: Date, items: [CloudObservation])] {
        CloudObservation.grouped(observations)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Clouds")
                .toolbar {
                    ToolbarItem {
                        Button("Identify", systemImage: "sparkles") {
                            isPresentingIdentify = true
                        }
                    }
                }
                .sheet(isPresented: $isPresentingIdentify) {
                    IdentifyView()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if observations.isEmpty {
            ContentUnavailableView(
                "No Observations Yet",
                systemImage: "cloud",
                description: Text("Tap Identify to record your first cloud observation.")
            )
        } else {
            List {
                ForEach(sections, id: \.day) { section in
                    Section {
                        ForEach(section.items) { observation in
                            ObservationRow(observation: observation)
                        }
                    } header: {
                        Text(section.day, format: .dateTime.day().month().year())
                    }
                }
            }
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: CloudObservation.self, inMemory: true)
}
