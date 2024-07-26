//
//  hksi_monitoring_iosApp.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 26/7/2024.
//

import SwiftUI
import SwiftData

@main
struct hksi_monitoring_iosApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
