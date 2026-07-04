import Foundation
import SwiftData

/// Builds the one ModelContainer both the app and the widget extension use,
/// backed by the App Group store so widget math always matches the app.
enum ModelContainerFactory {
    static let appGroupID = "group.com.alexhappydays.worth"

    /// One container per process. Widgets get a fresh read of the same
    /// on-disk store the app writes.
    static let shared: ModelContainer = {
        let config = ModelConfiguration(groupContainer: .identifier(appGroupID))
        migrateDefaultStoreIfNeeded(to: config.url)
        do {
            return try ModelContainer(
                for: Subscription.self, UsageLog.self, AppMeta.self,
                configurations: config)
        } catch {
            fatalError("Could not open shared model container: \(error)")
        }
    }()

    /// Phase 4 one-time migration: installs from before the App Group change
    /// kept data in the app's default store (Application Support). Copy the
    /// SQLite files into the group store's resolved location before first
    /// open. Guarded by a UserDefaults flag so it runs once per process
    /// sandbox; in the widget extension the old store never exists, so it
    /// no-ops there.
    private static func migrateDefaultStoreIfNeeded(to groupStoreURL: URL) {
        let migratedKey = "didMigrateStoreToAppGroup"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey) else { return }
        defer { defaults.set(true, forKey: migratedKey) }

        let fm = FileManager.default
        let oldStoreURL = URL.applicationSupportDirectory.appending(path: "default.store")
        guard fm.fileExists(atPath: oldStoreURL.path),
              !fm.fileExists(atPath: groupStoreURL.path) else { return }

        try? fm.createDirectory(
            at: groupStoreURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        // SQLite sidecar files must travel with the store.
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(filePath: oldStoreURL.path + suffix)
            let to = URL(filePath: groupStoreURL.path + suffix)
            if fm.fileExists(atPath: from.path), !fm.fileExists(atPath: to.path) {
                try? fm.copyItem(at: from, to: to)
            }
        }
    }
}
