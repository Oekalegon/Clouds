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

    private var sections: [(day: Date, observations: [CloudObservation])] {
        let grouped = Dictionary(grouping: observations) { CloudObservation.sectionKey(for: $0.date) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, observations: $0.value) }
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
                    IdentifyPlaceholderView()
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
                        ForEach(section.observations) { observation in
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
