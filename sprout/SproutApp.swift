//
//  SproutApp.swift
//  sprout
//
//  Created by ze on 21/3/26.
//

import SwiftUI
import SwiftData

@main
struct SproutApp: App {
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private static func makeSharedModelContainer() -> ModelContainer {
        let schema = Schema([
            RecordItem.self,
            MemoryEntry.self,
            WeeklyLetter.self,
            BabyProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            clearPersistentStoreFiles()

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static func clearPersistentStoreFiles(fileManager: FileManager = .default) {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let storeURLs = [
            applicationSupportURL.appendingPathComponent("default.store"),
            applicationSupportURL.appendingPathComponent("default.store-wal"),
            applicationSupportURL.appendingPathComponent("default.store-shm"),
        ]

        for url in storeURLs where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                TestHostView()
            } else {
                ContentView()
            }
        }
        .modelContainer(Self.makeSharedModelContainer())
    }
}

private struct TestHostView: View {
    var body: some View {
        Color.clear
    }
}
