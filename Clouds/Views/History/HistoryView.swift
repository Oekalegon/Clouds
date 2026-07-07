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
    @Query(sort: \SkyConditions.date, order: .reverse)
    private var skyConditions: [SkyConditions]
    /// Only observations without a sky condition appear as standalone
    /// entries; the others render inside their sky condition's section.
    @Query(filter: CloudObservation.standalonePredicate, sort: \CloudObservation.date, order: .reverse)
    private var standaloneObservations: [CloudObservation]
    @State private var isPresentingIdentify = false

    private var entries: [HistoryEntry] {
        HistoryEntry.chronological(
            skyConditions: skyConditions,
            standaloneObservations: standaloneObservations
        )
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
        if entries.isEmpty {
            ContentUnavailableView(
                "No Observations Yet",
                systemImage: "cloud",
                description: Text("Tap Identify to record your first cloud observation.")
            )
        } else {
            List {
                ForEach(entries) { entry in
                    switch entry {
                    case .skyConditions(let skyConditions):
                        skyConditionsSection(skyConditions)
                    case .observation(let observation):
                        standaloneSection(observation)
                    }
                }
            }
        }
    }

    private func skyConditionsSection(_ skyConditions: SkyConditions) -> some View {
        Section {
            ForEach(skyConditions.observations.sorted { $0.date < $1.date }) { observation in
                ObservationRow(observation: observation)
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(skyConditions.date, format: .dateTime.day().month().year().hour().minute())
                if let summaryLine = skyConditions.summaryLine {
                    Text(summaryLine)
                        .textCase(nil)
                }
            }
        }
    }

    private func standaloneSection(_ observation: CloudObservation) -> some View {
        Section {
            ObservationRow(observation: observation)
        } header: {
            Text(observation.date, format: .dateTime.day().month().year().hour().minute())
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: CloudObservation.self, inMemory: true)
}
